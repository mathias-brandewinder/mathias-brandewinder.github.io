---
layout: post
title: Should I use dotnet SIMD Vectors?
tags:
- F#
- Algorithms
- Machine-Learning
use_math: true
---

Even though a lot of my work involves writing computation-heavy code, I have 
not been paying close attention to the `System.Numerics` namespace, mainly 
because I am lazy and working with plain old arrays of floats has been good 
enough for my purposes.  

This post is intended as a first dive into the question "should I care about 
[.NET SIMD-accelerated types][1]". More specifically, I am interested in 
understanding better [`Vector<T>`][2], and in where I should use it instead of 
basic arrays for vector operations, a staple of machine learning.  

Spoiler alert: some of my initial results surprised me, and I don't understand 
yet what drives the speed differences between certain examples. My intent here 
is to share what I found so far, which I found interesting enough to warrant 
further exploration later on.  

Anyways, let's dive in. As a starting point, I decided to start with a very 
common operation in Machine Learning, computing the [Euclidean distance][3] 
between 2 vectors.  

> You can find the whole code [here on GitHub][7].

<!--more-->

First, what is the Euclidean distance? Given 2 real-valued vectors $x$ and $y$, 
where:

$x = (x_1, x_2, .. x_n)$

and  

$y = (y_1, y_2, .. y_n)$

the distance between $x$ and $y$ is

$d(x, y) = \sqrt { (x_1 - y_1) ^ 2 + (x_2 - y_2) ^ 2 ... + (x_n - y_n) ^ 2}$

One way to write this in F#, using `float []` to represent vectors, is as 
follows:  

``` fsharp
let naive (v1: float[], v2: float[]) =
    (v1, v2)
    ||> Array.map2 (fun x y -> (x - y) ** 2)
    |> Array.sum
    |> sqrt
```

> For simplicity I assume here that `v1` and `v2` have the same length.  

So my goal here is two-fold: rewrite this using `Vector<float>`, and hopefully 
glean some insight on where this might be a good or a bad idea.  

## What are these Vectors?

The reason I am hoping to get some performance improvements is that, per the 
[documentation][2],  

> The Vector<T> structure provides support for hardware acceleration.

Let's try first to construct a vector:

``` fsharp
open System.Numerics

let vectorize (v: float []) =
    Vector<float>(v)

[| 0.0 .. 1.0 .. 10.0 |]
|> vectorize
```

This produces the following:

```
val it: Vector<float> = <0, 1, 2, 3> {Item = ?;}
```

That is most definitely not what the mathematician in me would expect! I got a 
vector all right, but it contains only 4 elements, instead of 11 in the 
original array. What is going on?  

Per the [documentation][2] again:

> The count of Vector<T> instances is fixed, but its upper limit is 
CPU-register dependent.

In other words, a `Vector<T>` is quite different from a `float []` or a 
mathematical vector. Its size is fixed, and depends on the type `T`:  

``` fsharp
> Vector<float>.Count;;
val it: int = 4

> Vector<single>.Count;;
val it: int = 8

> Vector<byte>.Count;;
val it: int = 32
```

Note also that a `Vector<float>` needs to be exactly 4 elements, if I 
understand things correctly. As an example, the following code crashes:  

``` fsharp
[| 0.0; 1.0; 2.0 |]
|> vectorize
```

All this has serious practical implications. If I want to write code that works 
with vectors of arbitrary size, like my naive F# distance function, I will have 
to break it down into chunks of 4 floats, write a function that operates on 
these chunks and still allow me to aggregate back to the correct overall 
result. And, of course, I want the overall speed to be faster, otherwise the 
entire exercise would be pointless.  

Let's consider the first question - can we use divide-in-fours and conquer to 
compute the distance? We can (with a caveat, more on that later), because:  

$((x_1 - y_1) ^ 2 + ... + (x_n - y_n) ^ 2) = ((x_1 - y_1) ^ 2 + (x_2 - y_2) ^ 2 + (x_3 - y_3) ^ 2 + (x_4 - y_4) ^ 2) + ... +$

In other words, we can compute a sum by computing the sum of groups of 4, and 
then sum these together. Note that, by contrast, the square root cannot be 
applied on groups of 4, because in general  

$\sqrt { (x + y) } \neq \sqrt { x } + \sqrt { y }$

In other words, we should be able to rewrite our distance function using 
vectors of size 4, but we need to be a little careful.  

Now to the second point - why would I expect any speedup here? The answer is 
[SIMD, or Single Instruction Multiple Data][4], what the documentation refers 
to as hardware acceleration. This is not my area of expertise, but my notice 
understanding is along these lines: SIMD enables applying the same operation to 
multiple data in one processor instruction. As a naive example, computing 
`1 + 2 + 3 + 4` would be performed as a single operation on a block of 4, 
instead of 3 operations (`1 + 2`, `+ 3`, `+ 4`).  

## Distance using Vector<T>

Without further due, let's try to rewrite the distance function, using 
`Vector<T>` instead of `float []`. My first attempt looked like this:  

``` fsharp
let take1 (v1: float[], v2: float[]) =
    let size = v1.Length
    let mutable total = 0.0
    for i in 0 .. (size - 1) / 4 do
        let s = 4 * i
        let v1 = Vector<float>(v1.[s .. s + 3])
        let v2 = Vector<float>(v2.[s .. s + 3])
        let diff = v1 - v2
        total <- total + Vector.Dot(diff, diff)
    sqrt total
```

> Note: in addition to the previously mentioned issue around not checking if 
`v1` or `v2` have the same size, this code will also crash if the size of `v1` 
or `v2` is not a clean multiple of 4. Good enough for now, this is not intended 
for production :)  

I break the arrays in chunks of 4, create vectors, compute their difference, 
and use what is called the [vector dot product][5] to compute the sum of the 
squared differences. Note how I kept `sqrt` outside, as the final operation.  

Does this work? According to [`BenchmarkDotNet`][6], it does:  

```
| Method           | Mean       | Error     | StdDev    | Ratio | RatioSD |
|----------------- |-----------:|----------:|----------:|------:|--------:|
| classic          | 218.557 ns | 4.1251 ns | 6.1742 ns |  1.00 |    0.04 |
| simdV1           |  66.053 ns | 1.1213 ns | 0.9364 ns |  0.30 |    0.01 |
```

In spite of the overhead of splitting the work in chunks of 4 and 
re-aggregating the results, the speedup is notable - almost 4x faster. I tried 
it out on arrays of various sizes, from 4 to 100,000, and the results were 
roughly consistent.  

A speedup by up to a factor of 4 is what I was expecting, given that we are 
operating on blocks of 4. This is pretty good, a x3.3 speedup is nothing to 
sneeze at. In particular if an operation is repeated often enough in an 
algorithm it might be worth rewriting it this way. On the other hand, this 
clearly has a cost attached - the modified version is significantly more 
complex than the original, and would still require additional work to handle 
cleanly arrays of arbitrary sizes.  

## A faster version

On a hunch, I wondered if using a `Span` could help, to avoid creating so many 
arrays in this function. There was also a bit of a hint in one of the 
constructors, `Vector(values: ReadOnlySpan<float>)`. This line of thought led 
to `take2`:

``` fsharp
let take2 (v1: float[], v2: float[]) =
    let size = v1.Length
    let s1 = ReadOnlySpan(v1)
    let s2 = ReadOnlySpan(v2)
    let mutable total = 0.0
    for i in 0 .. (size - 1) / 4 do
        let s = 4 * i
        let v1 = Vector<float>(s1.Slice(s, 4))
        let v2 = Vector<float>(s2.Slice(s, 4))
        let diff = v1 - v2
        total <- total + Vector.Dot(diff, diff)
    sqrt total
```

I was hoping for some marginal improvement - the result was unexpected:  

```
| Method           | Mean       | Error     | StdDev    | Ratio | RatioSD |
|----------------- |-----------:|----------:|----------:|------:|--------:|
| classic          | 218.557 ns | 4.1251 ns | 6.1742 ns |  1.00 |    0.04 |
| simdV1           |  66.053 ns | 1.1213 ns | 0.9364 ns |  0.30 |    0.01 |
| simdV2           |   4.211 ns | 0.0865 ns | 0.0675 ns |  0.02 |    0.00 |
```

I was **not** expecting a x52 speedup!

To be perfectly honest, I don't understand why this is so much faster. I can 
see how using `Vector.Dot` as a single operation would be better than many 
products and sums, but this is a very large speedup. It looks too good to be 
true, and got me wondering if perhaps there was something wrong with the way I 
setup my benchmarks, but after some checks, I can't see anything amiss there.  

Assuming my measurements are correct, that level of improvement piqued my 
interest. Again, there was a cost in writing that function using SIMD, but in 
the right spots in an algorithm, this can be worth the effort.  

This success got me excited, and I tried it on a couple of different operations 
I commonly perform. The results were not as good, and at times even way worse 
than the naive implementation. I don't see yet the patterns that influence what 
will or will not work, so... more investigations is needed!  

## Are the naive and SIMD versions equivalent?

A small point I wanted to bring up is that the SIMD version is not 100% 
equivalent to the original function. Using the same inputs, the calculated 
distances are very close, but not identical.  

My guess (to be confirmed) is that by performing operations on groups of 4, and 
then aggregating, rounding can be subtly different.  

Depending on the circumstances, this may or may not be acceptable. In the 
context of machine learning, I will typically compute a distance to know if 2 
things are closer or further apart. I will happily take a x52 speedup, at the 
cost of a little precision lost. I imagine someone whose responsibility is to 
run financial models may care greatly about a small change far down the 
decimals, because it could have meaningful effects.  

Anyways, that's what I got for today! The tl;dr version is:  

- While requiring some effort to use, the SIMD accelerated Vector<T> does seem 
to potentially bring bigger performance improvements than what I was expecting, 
- Where big improvements can be expected is not clear to me at all so far, and 
I will need to dig further, 
- Either I got very lucky and picked up a case that works very well by accident, 
or there is an error in my benchmark.

Hope you found something interesting in this post.
If you are interested in the code, you can find it on [GitHub][7]. Cheers!

[1]: https://learn.microsoft.com/en-us/dotnet/standard/simd
[2]: https://learn.microsoft.com/en-us/dotnet/api/system.numerics.vector-1
[3]: https://en.wikipedia.org/wiki/Euclidean_distance
[4]: https://en.wikipedia.org/wiki/Single_instruction,_multiple_data
[5]: https://en.wikipedia.org/wiki/Dot_product
[6]: https://benchmarkdotnet.org/
[7]: https://github.com/mathias-brandewinder/SIMD-exploration/tree/1601c3a9a6059fe63d99a1b3a487dd7a4c564a9d