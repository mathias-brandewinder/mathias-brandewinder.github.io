---
layout: post
title: Version 0.2 of the Quipu Nelder-Mead solver
tags:
- F#
- Optimization
- Algorithms
use_math: true
---

Back in April '23, I needed a simple solver for function minimization, and 
published a [basic F# Nelder-Mead solver][1] implementation on [NuGet][2]. I 
won't go over the algorithm itself, if you are curious I wrote a post breaking 
down [how the Nelder-Mead algorithm works][3] a while back.  

In a nutshell, the algorithm takes a function, and finds the set of inputs that 
produces the smallest output for that function. The algorithm is not foolproof, 
but it is very useful, and has the benefit of being fairly simple.  

After dog-fooding my library for a bit, I found some rough spots, and decided 
it was time to make improvements. As a result, the API has changed a bit - 
hopefully for the better! In this post, I'll go over some of these changes.  

## Basic usage

Imagine that you are interested in the following function:  

$ f(x,y)=(x-10)^2+(y+5)^2 $

Specifically, you would want to know what values of $(x,y)$ produce the 
smallest value for $f$.  

This is how you would go about it with Quipu in an F# script:  

``` fsharp
#r "nuget: Quipu, 0.2.0"
open Quipu.NelderMead

let f (x, y) = (x - 10.0) ** 2.0 + (y + 5.0) ** 2.0
NelderMead.minimize f
|> NelderMead.solve
```

This produces the following output:

```
val it: Solution = Optimal (2.467079917e-07, [|9.999611886; -4.999690039|])
```

The solver has found an Optimal solution, for $x=9.999,y=-4.999$, which yields 
$f(x,y)=2.467 \times 10^{-7}$, very close to the correct answer, $f(10,-5)=0$.  

<!--more-->

## Improvements: search starting point

There were a few reasons I wanted to make some changes to the API.  

First, I wanted better control over the search starting point.  

In the basic usage example, the search will start with a [simplex][4] centered 
on 0, with vertices on a sphere of radius 1. The new version allows you to 
specify a starting point, which will generate a regular simplex on a sphere of 
arbitrary radius. Stated more simply, you can now specify in which region you 
want the search to begin. Pass it a starting point and a radius, and the search 
will begin with n vertices located on a sphere of the requested radius:  

``` fsharp
NelderMead.minimize f
|> NelderMead.startFrom (StartingPoint.fromValue ([1.0; 2.0], 0.1))
|> NelderMead.solve
```

This is useful in situations where you want to start in a specific region. You 
can specify where to start, and how wide or tight the original search simplex 
should be.  

This improves on version 0.1, where the search for a function of $n$ arguments 
was initiated using a set of $2n+1$ vertices, where $n+1$ are sufficient.  

Under the hood, this will call the following function:

``` fsharp
Simplex.create ([| 1.0; 2.0 |], 0.1)
```

... creating the following regular simplex, centered on $(1,2)$:  

```
val it: Simplex =
  Vectors
  (2,
   [|[|1.025881905; 1.903407417|]; [|0.9034074174; 2.025881905|];
     [|1.070710678; 2.070710678|]|])
    {dimension = 2;
     size = 3;}
```

## Improvements: termination

Version 0.1 stopped the search when all values of $f$ were within precision 
bounds. I decided to tighten the criterion, requiring that every argument 
should also be within the same bounds.  

The reason I made that change was that the original approach could result in 
an premature termination. In situations where the function being minimized is 
"flat" around the optimum, the search could stop early, with a wide simplex. 
Tightening the rules forces the simplex to contract around the minimum.  

As an example, in the basic usage, the tolerance is set to $0.001$. We can 
relax this:  

``` fsharp
NelderMead.minimize f
|> NelderMead.withConfiguration
    { Configuration.defaultValue with
        Termination = {
            Tolerance = 0.1
            MaximumIterations = None
        }
    }
|> NelderMead.solve
```

This produces the following result, where $(x,y)$ and $f$ are within $0.1$ of 
the correct value:  

```
Optimal (0.001308370319, [|10.03105359; -5.01854845|])
```

Tighten up the tolerance like so:  

``` fsharp
NelderMead.minimize f
|> NelderMead.withConfiguration
    { Configuration.defaultValue with
        Termination = {
            Tolerance = 0.000_001
            MaximumIterations = None
        }
    }
|> NelderMead.solve
```

... and the search produces much tighter results, within the new tolerance:  

```
Optimal (1.78601232e-13, [|10.00000009; -4.999999587|])
```

## Parting words

There are still a few improvements I want to make, but I believe the code is 
now in a much better state that previously! If you are interested in perusing 
the code, you can find it here:  

[<i class="fa-brands fa-github"></i> Code on GitHub][5]

I think my next steps will be focused on
- Improving the detection of abnormal situations,
- Improving the performance of the core algorithm.

Besides that, one thing I'd like to try out is adding constraints to the 
problem, something along the lines of $argmin_{x,y}(f(x,y))$, subject to a list of 
inequality constraints like $3 \times x - y^2 \geq 10$.  

I imagine that's something I should be able to do with penalty / barrier 
functions. However, I haven't had much experience with that approach, and I can 
also already see in my mind all sorts of complications arising!  

At any rate, this is where I will stop for today. Hope you found something of 
interest in this post, and perhaps you'll even have a use for this library!  

[1]: https://brandewinder.com/2023/04/15/quipu-basic-nelder-mead-solver/
[2]: https://www.nuget.org/packages/Quipu
[3]: https://brandewinder.com/2022/03/31/breaking-down-Nelder-Mead/
[4]: https://en.wikipedia.org/wiki/Simplex
[5]: https://github.com/mathias-brandewinder/Quipu/tree/e7f5294fc2aef26c5c4171d449edfe53e8f0e38b