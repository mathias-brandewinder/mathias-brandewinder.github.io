---
layout: post
title: Micro optimizing F# code with a dash of imperative code
tags:
- F#
- Performance
---

In addition to re-designing my [Nelder-Mead solver][1] to improve usability, I have 
also recently dedicated some time looking into performance improvements. This 
is usually not my primary concern: I tend to focus first on readability and 
correctness first, and address performance issues later.  

However, in the case of a solver, performance matters. In my specific 
case, the solver works as a loop, iteratively updating a candidate solution 
until it is good enough. Anything that can speed up that loop will directly 
speed up the overall solver, so it is worth making sure the code is as 
efficient as can be.  

One particular code area I worked on is the solver termination rule. The 
changes I made resulted in a significant speedup (roughly 10x), at the expense 
of style: the final version does not look like idiomatic F# at all. In this 
post, I will go over these changes.  

<!--more-->

## Solver termination

First, let's talk about what the code does. Without going into too much detail, 
the Nelder-Mead solver tries to find an array of numbers that minimizes a 
function. It does so by keeping a collection of candidates (arrays of numbers), 
and iteratively manipulates that collection in a loop, attempting to reduce the 
value of the target function until it decides to stop searching further.  

One of the criteria for termination is whether all the candidates are 
sufficiently close to each other.  

Let's illustrate with an example: suppose we are searching for the values 
$x$ and $y$ that minimize $f(x,y)=x^2+y^2$. To do this, the solver will work 
with a collection of 3 arrays of 2 elements, for instance  

- Candidate 1: $C_1 = [ x_1 = 1.0, y_1 = 1.5 ]$
- Candidate 2: $C_2 = [ x_2 = 1.1, y_2 = 1.7 ]$
- Candidate 3: $C_3 = [ x_3 = 1.0, y_3 = 1.2 ]$

If we are searching for a solution within a given tolerance, say, we want the 
solution to be within 0.01 of the correct value, the candidates should be near 
each other. One way to express this is to say that we want $x_1, x_2, x_3$ to 
be within 0.01 of each other, and $y_1, y_2, y_3$ to be within 0.01 of each 
other.  

In this particular example, our $x$ values, $1.0, 1.1, 1.0$ are within $0.1$ of 
each other, but the $y$ values, $1.5, 1.7, 1.2$ are within $0.5$ of each other. 
If we wanted a tolerance of $0.1$ the candidates would not be close enough to 
stop, and we would continue searching.  

In other words, the termination rule I am looking at can be stated as:  

- if $max(x_1, x_2, x_3) - min(x_1, x_2, x_3) > tolerance$, continue search.  
- if $max(y_1, y_2, y_3) - min(y_1, y_2, y_3) > tolerance$, continue search.  

<!--more-->

## Initial version

My initial implementation was a direct, naive translation in F#:  

``` fsharp
module Original =

    let minMax f xs =
        let projection = xs |> Seq.map f
        let minimum = projection |> Seq.min
        let maximum = projection |> Seq.max
        (minimum, maximum)

    let terminate (tolerance: float) (candidates: float [][]) =
        let dim = candidates[0].Length
        seq { 0 .. dim - 1 }
        |> Seq.forall (fun i ->
            let min, max =
                candidates
                |> minMax (fun candidate -> candidate.[i])
            max - min < tolerance
            )
```

We take our `candidates`, an array of array of floats, and iterate by column, 
computing the minimum and maximum, checking if for every column we are 
within the bounds set by `tolerance`.  

Let's set up a benchmark, using `BenchmarkDotNet` to evaluate the `terminate` 
function of an array of 4 arrays of 3 random-generated values:  

``` fsharp
type Termination () =

    let rng = Random 0
    let sample =
        Array.init 4 (fun _ ->
            Array.init 3 (fun _ -> 100.0 * rng.NextDouble())
            )

    [<Benchmark(Baseline = true)>]
    member this.Original () =
        Original.terminate 0.0001 sample
```

```
| Method   | Mean     | Error   | StdDev  | Ratio |
|--------- |---------:|--------:|--------:|------:|
| Original | 433.6 ns | 4.32 ns | 4.04 ns |  1.00 |
```

This is our baseline - let's see if we can do better!  

## Take 1: replace sequences with arrays

My first thought was to replace sequences by arrays in the `minMax` function, 
because generally arrays are fast. This is a trivial change:  

``` fsharp
module Version1 =

    let minMax f xs =
        let projection = xs |> Array.map f
        let minimum = projection |> Array.min
        let maximum = projection |> Array.max
        (minimum, maximum)

    let terminate (tolerance: float) (candidates: float [][]) =
        // no change here
```

We can now compare the original to version 1:  

``` fsharp
type Termination () =

    // no change here

    [<Benchmark(Baseline = true)>]
    member this.Original () =
        Original.terminate 0.0001 sample

    [<Benchmark>]
    member this.Version1 () =
        Version1.terminate 0.0001 sample
```

This produces the following benchmark result:  

```
| Method   | Mean     | Error   | StdDev  | Ratio | RatioSD |
|--------- |---------:|--------:|--------:|------:|--------:|
| Original | 450.2 ns | 7.46 ns | 6.98 ns |  1.00 |    0.02 |
| Version1 | 326.6 ns | 6.44 ns | 7.67 ns |  0.73 |    0.02 |
```

Not much to say here, except that this is not a negligible improvement, we 
shaved off 27%. I like sequences, but... arrays tend to be pretty fast!  

## Take 2: imperative code

Can we do better? Call it a hunch, but I wondered if iterating over rows 
instead of columns would pay off. Let's try that out:  

``` fsharp
module Version2 =

    let terminate (tolerance: float) (candidates: float [][]) =
        let dim = candidates[0].Length
        let mins = Array.create dim (System.Double.PositiveInfinity)
        let maxs = Array.create dim (System.Double.NegativeInfinity)
        for candidate in candidates do
            let args = candidate
            for i in 0 .. (dim - 1) do
                if args.[i] < mins.[i]
                then mins.[i] <- args.[i]
                if args.[i] > maxs.[i]
                then maxs.[i] <- args.[i]
        let deltas = (mins, maxs) ||> Array.map2 (fun min max -> max - min)
        deltas |> Array.forall (fun delta -> delta < tolerance)
```

We create 2 arrays to store the minimum and maximum values of each column, and 
iterate over the candidates, replacing the minimum and maximum values as we go. 
The style here is resolutely imperative, and relies on mutation. Does it work?  

```
| Method   | Mean      | Error    | StdDev   | Ratio |
|--------- |----------:|---------:|---------:|------:|
| Original | 430.77 ns | 1.117 ns | 0.933 ns |  1.00 |
| Version1 | 320.75 ns | 5.777 ns | 5.674 ns |  0.74 |
| Version2 |  50.55 ns | 0.595 ns | 0.556 ns |  0.12 |
```

It most definitely **does** work! We are now over 8x faster than the original.  

## Why is this faster

Now the interesting question here is, why is it so much faster?  

The short answer is, I am not sure. As I said earlier, I took that direction on 
a hunch, and performance is not something I can say I am particularly good at.  

That being said, my hunch was not completely random. With a lot of hand-waving, 
the thinking was that perhaps computing by columns would result in cache misses 
that could be avoided by processing data following the existing arrays.  

I could have stopped here - just take the win and move on. However, I was 
curious, and this also made me realize that I didn't even know how to go about 
approaching that type of issue in general. 

There are probably other ways to do this, but I ended up coming across a 
[post by Adam Sitnik][2], which, besides being a good read, showed how 
BenchmarkDotNet can display performance counters. As I am already using 
BenchmarkDotNet here, this made it easy to try out.  

After including a couple of performance counters in the benchmark, I got the 
following results:  

| Method   | Ratio | BranchInstructions/Op | TotalIssues/Op | CacheMisses/Op | BranchMispredictions/Op |
|--------- |------:|----------------------:|---------------:|---------------:|------------------------:|
| Original |  1.00 |                 1,489 |          5,022 |             10 |                       4 |
| Version1 |  0.71 |                 1,184 |          3,842 |              7 |                       3 |
| Version2 |  0.11 |                   149 |            616 |              1 |                       0 |

Again, I am a novice at performance optimization. However, even without fully 
understanding the details, it seems that my guess about cache misses is 
plausible: We see 10 times less cache misses in Version 2 compared to the 
Original, which is in line with the improvement ratio. That being said, the 
other counters exhibit similar improvements, too - and I know too little of the 
topic to interpret this. Regardless, my interpretation is that the code change 
in version 2 performs much better, because it is written in a manner that is 
more "friendly" to hardware optimizations.  

## Parting thoughts

While I suspected that re-orienting my iterations from columns to rows would 
make a difference, the scale of the improvement caught me by surprise. I did 
not fundamentally change the algorithm, and yet, it yielded an almost 10-fold 
speedup.  

That type of micro-optimization is not something I do often. A speedup like 
this is certainly nice, but from a different angle, we are talking execution 
times below milliseconds. This will matter only if the corresponding operation 
is executed very often, which happens to be the case in my algorithm.  

This was also a reminder that, while I have been writing plenty of half-decent 
code, happily ignoring what happens at the hardware level, it can pay off to 
understand better what is going on at that lower level! Perhaps it's time for 
me to learn a bit more about that.  

[1]: https://github.com/mathias-brandewinder/Quipu
[2]: https://adamsitnik.com/Hardware-Counters-Diagnoser/
