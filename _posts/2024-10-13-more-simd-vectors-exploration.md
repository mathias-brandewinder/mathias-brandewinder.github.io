---
layout: post
title: More SIMD vectors exploration
tags:
- F#
- Algorithms
- Machine-Learning
use_math: true
---

Since my earlier post [looking into SIMD vectors in .NET][1], I 
attempted a few more experiments, trying to understand better where 
they might be a good fit, and where they would not.  

The short version: at that point, my sense is that SIMD vectors can be very 
handy for some specific scenarios, but would require quite a bit of work to be 
usable in the way I was hoping to use them. This statement is by no means meant 
as a negative on SIMD; rather, it reflects my realization that a SIMD vector is 
quite different from a mathematical vector.  

All that follows should also be taken with a big grain of 
salt. SIMD is entirely new to me, and I might not be using it 
right. While on that topic, I also want to thank @xoofx for his 
[very helpful comments][2] - much appreciated!   

Anyways, with these caveats out of the way, let's dive into it.  

My premise approaching SIMD was along these lines: "I write a lot of code that 
involves vectors. Surely, the `Vector` class should be a good fit to speed up 
some of that code".  

To explore that idea, I attempted to write a few classic vector operations I 
often need, both in plain old F# and using SIMD vectors, trying to benchmark 
how much performance I would gain. In this post, I'll share some of the 
results, and what I learnt in the process.  

> You can find the whole code [here on GitHub][3].

<!--more-->

## Context: what am I trying to do here?

First, what do I mean by "code that involves vectors"? Most of my work involves  
numerical algorithms, be it machine learning, optimization, 
or simulation. These can often be represented in a general manner as operations 
on mathematical vectors, involving a few core operations that appear over and 
over again. Below are a few examples for illustration:  

- **distance**: computing the difference (or similarity) between 2 entities, 
represented as vectors of values / features,  
- **linear combination**: computing the average position of a collection of 
entities, represented as vectors of values / features,  
- **translation**: moving from a candidate solution to a better one,  
- **statistics**: computing aggregate values over a sample of observations, 
such as the average, standard deviation, or log likelihood.  

For instance, I have written code to compute the Euclidean distance multiple 
times in different projects, something along these lines (ignoring details such 
as what happens if `v1` and `v2` do not having matching lengths):  

``` fsharp
let distance (v1: float[], v2: float[]) =
    (v1, v2)
    ||> Array.map2 (fun x y -> (x - y) ** 2)
    |> Array.sum
    |> sqrt
```

We take 2 arrays of numbers, compute the difference between each of their 
elements, square it, sum it all together and return the square root. By using 
arrays, we get a very general function that it will work for any array length - 
we get the same re-usable operation regardless of the array length.  

From a mathematical standpoint, we are using arrays of floats here as a 
representation of a vector. The same operation, viewed from a mathematician 
standpoint, could be written along the lines of:  

$ (v_1, v_2) \rightarrow { \sqrt { (v_1 - v_2) \cdot (v_1 - v_2) } } $

My point here is that while the F# example above is fairly general, it is still 
a very manual implementation of 2 algebra operations:  

- the difference between 2 vectors, and 
- the dot-product of 2 vectors.  

These 2 operations are not immediately obvious in the code - it 
would be nice to write the distance as an operation on vectors, using these 
"core" vector operators (difference and dot-product) instead, something along 
these lines:  

``` fsharp
let distance (v1: float[], v2: float[]) =
    let V1 = vector v1
    let V2 = vector v2
    (V1 - V2) .* (V1 - V2)
    |> sqrt
```

This was what motivated me to look into the 
[SIMD-accelerated `Vector` class in .NET][4]. I was hoping for a way to both 
accelerate my code using SIMD, and write code directly using algebra operators.  

An important constraint here is that I want library code, code that I can plug 
into existing code to leverage vectors when appropriate. In that frame, I can't 
impose SIMD `Vector` on the consumer. I want to be able to seamlessly pass in 
arrays, and return arrays. The SIMD `Vector` part should be transparent to the 
consumer.  

## Fixed size Vectors

My first attempt into this was the exact example I showed before, a distance 
function. With an assist from [@xoofx][2], this is where I landed:  

``` fsharp
let distance (v1: float[], v2: float[]) =

    let s1 = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(v1))
    let s2 = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(v2))

    let mutable total = 0.0
    for i in 0 .. (s1.Length - 1) do
        let v1 = s1.[i]
        let v2 = s2.[i]
        let diff = v1 - v2
        total <- total + Vector.Dot(diff, diff)
    sqrt total
```

The good news first: this is vastly faster than the original version. For 
vectors of size 8, it takes ~2% of the time the naive F# implementation:

```
| Method           | Mean       | Error     | StdDev    | Ratio | RatioSD |
|----------------- |-----------:|----------:|----------:|------:|--------:|
| classic          | 212.753 ns | 3.3103 ns | 2.9345 ns |  1.00 |    0.02 |
| simdV3           |   3.343 ns | 0.0967 ns | 0.0950 ns |  0.02 |    0.00 |
```

With vectors of size 4,000, we get even better results, running under 1% of the 
original version:  

```
| Method           | Mean         | Error       | StdDev      | Ratio | RatioSD |
|----------------- |-------------:|------------:|------------:|------:|--------:|
| classic          | 115,976.9 ns | 2,315.62 ns | 2,166.03 ns | 1.000 |    0.03 |
| simdV3           |     967.4 ns |    13.64 ns |    11.39 ns | 0.008 |    0.00 |
```

Needless to say, at that point, my interest was piqued - who wouldn't want a 
98% speed improvement in their code?  

However, some issues are already showing up. First, a `Vector<float>` is quite 
different from a mathematical vector: it has a fixed size, which is 
architecture dependent.  

On my machine, a `Vector<float>` has a size of 4. This has 2 implications:  

First, I need to re-write vector operations into an equivalent operation breaking it 
down by blocks of 4 small vectors of values, which I need to aggregate back up. 
This requires making sure the operation is associative. As an example, in the 
distance function, I kept the square root calculation "outside", because 
$ \sqrt { x + y } \neq \sqrt { x } + \sqrt { y } $. 

Even if the operation is associative mathematically, it might not be from a 
numeric computation standpoint, because of rounding errors. As an example, 
addition is associative: $ a + (b + c) = (a + b) + c $. However, depending on 
how you perform addition on floats, you might get different results, as we can 
show with a simple example:

``` fsharp
open System

let rng = Random 0

let data = Array.init 16 (fun _ -> rng.NextDouble())

// directly summing all the numbers together:
let sum = data |> Array.sum
// summing the numbers by groups of 4,
// then summing the groups together:
let sumByBlocks =
    data
    |> Array.chunkBySize 4
    |> Array.map (fun chunk -> chunk |> Array.sum)
    |> Array.sum

printfn $"Equal: {sum = sumByBlocks} ({sum}, {sumByBlocks})"
```

```
Equal: False (9.108039789417779, 9.108039789417777)
```

Granted, this is a small difference, at the 15th decimal. However, it only took 
16 values and creating groups of 4 to find a discrepancy, which is exactly 
what using SIMD vectors would do. In other words, even for simple operations 
like addition or multiplication, we cannot guarantee that a SIMD version of the 
operation would produce the same result as the array version. Whether this 
matters depends on context - but at the same time, errors do accumulate.  

Second, the SIMD version of distance above is incomplete. It will work great, 
as long as the size of the 2 arrays are perfect multiples of 4. If not, it will 
crash, because the tail end of the array does not form a perfect block of 4 
values, which is needed to construct a `Vector<float>`.  

We can address this issue, by making sure that we only process complete blocks 
of size 4 using SIMD vectors, and handle the remaining tail end as a regular 
array. As an example, for arrays of size 10, we would do something like this: 

```
input array: [ 0; 1; 2; 3; 4; 5; 6; 7; 8; 9 ]
2 SIMD vectors using SIMD code: [ 0; 1; 2; 3 ], [ 4; 5; 6; 7 ]
1 remainder array using naive code: [ 8; 9 ]
aggregate the results
```

This is perfectly feasible, but the resulting distance function is starting to 
look a bit messy:  

``` fsharp
let full (v1: float[], v2: float[]) =

    let remainingBlocks = v1.Length % Vector<float>.Count
    let fullBlocks =
        (v1.Length - remainingBlocks) / Vector<float>.Count

    let s1 = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(v1))
    let s2 = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(v2))

    let mutable total = 0.0
    for i in 0 .. (fullBlocks - 1) do
        let v1 = s1.[i]
        let v2 = s2.[i]
        let diff = v1 - v2
        total <- total + Vector.Dot(diff, diff)

    if remainingBlocks > 0
    then
        for i in (v1.Length - remainingBlocks) .. (v1.Length - 1) do
            total <- total + (pown (v1.[i] - v2.[i]) 2)

    sqrt total
```

Good news: the performance is still excellent. Bad news: the code has gotten 
more complex, and performs the same operation using 2 different approaches, 
completely obscuring the underlying algebra. It is arguably worth it, given the 
speedup, but it is far from my original hope of code that looks like algebra.  

## Going beyond distance calculations

In spite of these minor issues, at that point I was still quite interested in exploring 
further. While I like code to look pretty, for that type of speedup, I will 
happily accept compromises!  

However, as I attempted to explore other functions I use regularly, I wasn't 
quite as successful as with my first example, and even ran into some issues I 
do not fully understand.  

> Note: the following examples all ignore the problem of vectors that are not 
clean multiples of `Vector<float>.Count`. My goal here was to get a sense for 
how much performance I might gain at best by using SIMD.  

The first case was performing a translation, taking a step from a vector 
towards another vector. My starting point, the naive F# version, looks like 
this:  

``` fsharp
let naive (origin: float[], target: float[], coeff: float) =
    let dim = origin.Length
    Array.init dim (fun col ->
        origin.[col] + coeff * (target.[col] - origin.[col])
        )
```

The motivation for this one was my Nelder-Mead solver, Quipu, which relies 
heavily on that operations. The idea here is to take a starting point, 
`origin`, and take a step of a certain size, `coeff`, towards a `target`, to 
evaluate if moving in that direction gives us a better objective 
function value.  

I attempted multiple SIMD versions, the best one I got was this one:  

``` fsharp
let take1 (origin: float[], target: float[], coeff: float) =

    let origins = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(origin))
    let targets = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(target))

    let result = Array.zeroCreate<float> origin.Length
    let blockSize = Vector<float>.Count

    let multiplier = 1.0 - coeff
    for i in 0 .. (origins.Length - 1) do
        let o = origins.[i]
        let t = targets.[i]
        let movedTo = Vector.Multiply(multiplier, o) -  t
        movedTo.CopyTo(result, i * blockSize)
    result
```

```
| Method  | Mean      | Error    | StdDev   | Ratio | RatioSD |
|-------- |----------:|---------:|---------:|------:|--------:|
| classic |  85.90 ns | 0.430 ns | 0.359 ns |  1.00 |    0.01 |
| simdV1  |  43.66 ns | 0.914 ns | 1.783 ns |  0.51 |    0.02 |
```

Still a decent improvement over the naive version, but nothing close to the 
massive speedup we saw on the distance calculation. My intuition is that there 
are 2 relevant differences here:  

- The SIMD operations are less efficient than in the distance case, where the 
dot product does a lot in a single operation.  
- More importantly, besides the individual operations on elements, we now also 
have to copy back the results in the array we are returning.  

> As a side note, I would be super interested to hear if there is a better way 
to copy back data to an array than what I did!  

A 50% improvement in speed is nothing to sneeze at. However, this hints at 
different gains to be expected, depending on whether the operation returns a 
vector or a scalar, a value aggregated / folded over the input vector.  

Another operation I looked into was computing the average of an array of values. 
The code is very similar to what we landed on for the distance:  

``` fsharp
let naive (v: float[]) =
    v
    |> Array.average

let average (v: float[]) =

    let vectors = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan v)
    let mutable total = 0.0
    for i in 0 .. (vectors.Length - 1) do
        let v = vectors.[i]
        total <- total + Vector.Sum(v)
    total / float v.Length
```

The performance is exactly what we would expect from SIMD:

```
| Method  | Mean      | Error     | StdDev    | Ratio |
|-------- |----------:|----------:|----------:|------:|
| classic | 28.843 us | 0.3332 us | 0.3117 us |  1.00 |
| simd    |  7.207 us | 0.0267 us | 0.0223 us |  0.25 |
```

This is an aggregate over the data, which involves computing a sum. Instead of 
adding elements one by one, we sum them 4 by 4, and as a result the computation 
takes only 25% of the original.  

However, just as I thought I had a decent understanding of what to expect from 
aggregates, I tried to implement another operation I use a lot, the 
Log-Likelihood. It is largely similar to the distance and average, in that it 
computes an aggregate over the entire array, and so I was expecting a comparable 
performance improvement:  

``` fsharp
let naive (v: float[]) =
    v
    |> Array.sumBy (fun x -> log x)
    |> fun total -> - total

let take1 (v: float[]) =

    let s = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(v))

    let mutable total = 0.0
    for i in 0 .. (s.Length - 1) do
        let v = s.[i]
        total <- total - Vector.Sum(Vector.Log(v))
    total
```

As it turns out, my expectations were totally wrong:  

```
| Method  | Mean      | Error     | StdDev    | Ratio | RatioSD |
|-------- |----------:|----------:|----------:|------:|--------:|
| classic |  2.280 us | 0.0443 us | 0.0510 us |  1.00 |    0.03 |
| simdV1  | 25.672 us | 0.4196 us | 0.3720 us | 11.27 |    0.29 |
```

The SIMD version is 11 times slower than the naive version!?

I do not understand what is going on here. The likely culprit is 
`Vector.Log`. In order to use it, I had to upgrade to the dotnet 9 preview, 
because dotnet 8.0 did not offer it. 
Perhaps the implementation in preview is not quite there yet, or perhaps the 
instruction is not supported on my CPU. Beyond the performance issue, what I 
don't like is that I have no idea where to start to understand the root cause, 
or what tools could be helpful here.  

The final function I attempted was a linear combination over a collection of 
arrays. A good example of where you might use it would be computing the middle 
position of a collection of points (their barycenter). If you had `n` such 
points, represented by vectors $V_1, V_2, ... V_n$
their average position would be $ \frac {1} {n} \times (V_1 + V_2 + ... V_n) $. 

More generally, a linear combination of `n` vectors would be something like 
$ c_1 \times V_1 + c_2 \times V_2 + ... c_n \times V_n $, where $c_i$ is a 
scalar and $V_i$ is a vector.

The naive F# version would look something like this, iterating by columns:  

``` fsharp
let naive (vectors: (float * float[]) []) =
    let dim = (vectors.[0] |> snd).Length
    Array.init dim (fun col ->
        vectors
        |> Seq.sumBy (fun (coeff, v) -> coeff * v.[col])
        )
```

However, I could not manage to get something similar working using SIMD 
vectors. This is likely due to my lack of familiarity with `Span`s, but I got 
stuck on trying to create a collection I could work with in a similar fashion. 
Any hints on how to get that working would be super welcome!  

## So what? Parting words.

So where does this leave me?  

First, I was lucky picking up the distance calculation as a starting 
point. This showed me that SIMD has the potential for very large calculation 
speedups. Had I started with another example, with less impressive results, I 
would probably not have spent that much time digging :)  

My main take at the moment is that `Vector<float>` is quite different from what 
I expected a vector to be. Specifically, its fixed-size nature makes it 
tricky to compose efficiently. We can write specialized functions to perform 
one task efficiently, but what I would like to be able to do is work with 
composable primitives. As an example, consider this earlier example, translation:  

``` fsharp
let take1 (origin: float[], target: float[], coeff: float) =

    let origins = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(origin))
    let targets = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(target))

    let result = Array.zeroCreate<float> origin.Length
    let blockSize = Vector<float>.Count

    let multiplier = 1.0 - coeff
    for i in 0 .. (origins.Length - 1) do
        let o = origins.[i]
        let t = targets.[i]
        let movedTo = Vector.Multiply(multiplier, o) -  t
        movedTo.CopyTo(result, i * blockSize)
    result
```

Fundamentally, what we are doing here is $(1-coeff) \times origin - target$. This 
requires 2 operations: scalar x vector, and vector substraction. We could 
achieve that writing code along these lines:  

``` fsharp
let sub (v1: float [], v2: float []) =

    let result = Array.zeroCreate<float> v1.Length
    let blockSize = Vector<float>.Count

    let s1 = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(v1))
    let s2 = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(v2))

    for i in 0 .. (s1.Length - 1) do
        let diff = s1.[i] - s2.[i]
        diff.CopyTo(result, i * blockSize)
    result

let mult (scalar: float, v: float []) =

    let result = Array.zeroCreate<float> v.Length
    let blockSize = Vector<float>.Count

    let s = MemoryMarshal.Cast<float, Vector<float>>(ReadOnlySpan(v))

    for i in 0 .. (s.Length - 1) do
        let multiplied = scalar * s.[i]
        multiplied.CopyTo(result, i * blockSize)
    result

let take4  (origin: float[], target: float[], coeff: float) =

    sub (mult (1.0 - coeff, origin), target)
```

This works, but the performance, unsurprisingly, is not good, a bit worse than 
the naive F# version:  

```
| Method  | Mean      | Error    | StdDev   | Ratio | RatioSD |
|-------- |----------:|---------:|---------:|------:|--------:|
| classic |  78.55 ns | 1.613 ns | 1.920 ns |  1.00 |    0.03 |
| simdV1  |  43.34 ns | 0.921 ns | 1.164 ns |  0.55 |    0.02 |
| simdV4  |  84.86 ns | 1.202 ns | 1.065 ns |  1.08 |    0.03 |
```

The problem here is that each time we perform an operation (`sub`, `mult`), we 
incur a cost, converting from arrays to SIMD vectors and back. What we would 
need here is a mechanism to keep chaining together SIMD Vector operations when 
appropriate, without getting in-and-out of the SIMD world in-between.  

I suspect this can be achieved, and I might give that a try in a future 
post. In the meanwhile, I will stop here for today, and use SIMD only for 
hand-written specialized operations!

You can find the [code for this post here on GitHub][3].

[1]: https://brandewinder.com/2024/09/01/should-i-use-simd-vectors/
[2]: https://mastodon.social/@xoofx/113066600743080384
[3]: https://github.com/mathias-brandewinder/SIMD-exploration/tree/5a4450d52f66c1dddfe8c72426bd2000669c9846
[4]: https://learn.microsoft.com/en-us/dotnet/api/system.numerics.vector