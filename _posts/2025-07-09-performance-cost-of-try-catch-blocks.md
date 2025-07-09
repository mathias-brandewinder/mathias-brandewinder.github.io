---
layout: post
title: Is there a cost to try catch blocks?
tags:
- F#
- Performance
---

I spent some time revisiting my solver library [Quipu][1] recently, looking in 
particular at improving the user experience when the algorithm encounters 
abnormal situations, that is, when the objective function could throw an 
exception. This in turn got me wondering about the performance cost of using 
`try ... catch` blocks, when the code does not throw any exception.  

Based on a quick internet search, the general wisdom seems to be that the cost 
is minimal. However, Quipu runs as a loop, evaluating the same function over 
and over again, so I was interested in quantifying how minimal that impact 
actually is.  

For clarity, I am not interested in the case where an exception is thrown. 
Handling an exception **IS** expensive. What I am after here is the cost of 
just adding a `try ... catch` block around a well-behaved function.  

So let's check that out!  

<!--more-->

## Benchmarking

We will start from the existing benchmark we have in the repository, using the 
[Beale function][2], a classic test function for optimization problems:  

``` fsharp
[<Benchmark(Description="Beale function")>]
member this.BealeFunction () =
    beale
    |> NelderMead.objective
    |> NelderMead.withConfiguration solverConfiguration
    |> NelderMead.startFrom (Start.around [ 4.5; 4.5 ])
    |> NelderMead.solve
```

The details of the Beale function are not particularly important here. We use 
it because it should cause the solver to do a bit of work, and because it 
cannot throw:  

``` fsharp
let beale (x, y) =
    pown (1.5 - x + (x * y)) 2
    +
    pown (2.25 - x + (x * pown y 2)) 2
    +
    pown (2.625 - x + x * pown y 3) 2
```

`NelderMead.objective` will transform that function into something the solver 
can work with, a "vectorized" function `float [] -> float`, like so:  

``` fsharp
type Vectorize () =
    static member from (f: (float * float) -> float) =
        { new IVectorFunction with
            member this.Dimension = 2
            member this.Value x = f (x.[0], x.[1])
        }
```

To evaluate the impact of a `try ... catch` block, we create an alternate 
method, `NelderMead.safeObjective`, which creates a "safe" vectorized function:  

``` fsharp
type Vectorize () =
    static member safeFrom (f: (float * float) -> float) =
        { new IVectorFunction with
            member this.Dimension = 2
            member this.Value x =
                try f (x.[0], x.[1])
                with | _ -> nan
        }
```

... and add a benchmark:  

``` fsharp
[<Benchmark(Description="Beale function, safe")>]
member this.BealeFunction_safe () =

    beale
    |> NelderMead.safeObjective
    |> NelderMead.withConfiguration solverConfiguration
    |> NelderMead.startFrom (Start.around [ 4.5; 4.5 ])
    |> NelderMead.solve
```

So what's the verdict? After seeing the result of the first benchmark, I 
decided to run it a couple of times:  

```
|----------------------- |---------:|---------:|---------:|---------:|
| 'Beale function'       | 18.44 us | 0.150 us | 0.442 us | 18.32 us |
| 'Beale function, safe' | 18.53 us | 0.101 us | 0.298 us | 18.44 us |

| Method                 | Mean     | Error    | StdDev   | Median   |
|----------------------- |---------:|---------:|---------:|---------:|
| 'Beale function'       | 18.32 us | 0.069 us | 0.202 us | 18.31 us |
| 'Beale function, safe' | 18.34 us | 0.207 us | 0.611 us | 18.16 us |

| Method                 | Mean     | Error    | StdDev   |
|----------------------- |---------:|---------:|---------:|
| 'Beale function'       | 18.26 us | 0.121 us | 0.357 us |
| 'Beale function, safe' | 18.75 us | 0.103 us | 0.303 us |

| Method                 | Mean     | Error    | StdDev   |
|----------------------- |---------:|---------:|---------:|
| 'Beale function'       | 18.12 us | 0.054 us | 0.160 us |
| 'Beale function, safe' | 18.69 us | 0.049 us | 0.143 us |

| Method                 | Mean     | Error    | StdDev   |
|----------------------- |---------:|---------:|---------:|
| 'Beale function'       | 18.14 us | 0.039 us | 0.115 us |
| 'Beale function, safe' | 18.45 us | 0.062 us | 0.184 us |

```

The `try ... catch` block version does run slower on average, but not by much. 
In the best case, we have a 0.1% degradation, in the worst, a 3.1% degradation, 
for an average performance degradation of 1.6%. So, a fairly minimal impact 
indeed.  

As a side-note, for completeness, given that the results were pretty close, I 
modified the default Benchmark configuration, and increased both the number of 
invocations and iterations:  

``` fsharp
let config =
    DefaultConfig.Instance
        .AddJob(
            Job.Default
                .WithInvocationCount(100_000)
                .WithIterationCount(100)
                )

BenchmarkRunner.Run<Benchmarks>(config)
|> ignore
```

## Parting thoughts

So where does this leave me? Besides pure curiosity, I ended up looking into 
this question because I have been bitten a few times by objective functions 
that could throw. This is uncommon for vanilla functions using only standard 
operators on floats. Typically, invalid inputs will result in a `NaN`, and 
Quipu handles that out of the box.  

However, this can happen if your objective function relies on an external 
library. In my case, I hit that issue a couple of times using Quipu for 
Maximum Likelihood Estimation, like in [this example][3]. The objective 
function uses the Math.NET implementation of the LogNormal distribution, and 
the constructor `LogNormal(mu, sigma)` throws for negative values of `sigma`.  

The proper way to handle that issue is by making sure the objective function 
cannot throw, and returns `NaN` for inputs were the function is not 
properly defined, like so:  

``` fsharp
let logLikelihood (mu, sigma) =
    if sigma < 0.0
    then nan
    else
        let distribution = LogNormal(mu, sigma)
        // do something with distribution
```

This is not particularly complicated, but it requires some understanding of how 
Quipu handles partial functions. As an alternative, I was considering adding a 
"safe mode" helper function, wrapping the objective function in a 
`try ... catch` block, along these lines:  

``` fsharp
type NelderMead private (problem: Problem) =
    static member safe (problem: Problem) =
        { problem with
            Objective =
                problem.Objective
                |> Vectorize.safe
        }

type Vectorize () =
    static member safe (vectorFunction: IVectorFunction) =
        { new IVectorFunction with
            member this.Dimension = vectorFunction.Dimension
            member this.Value (vector: float []) =
                try vectorFunction.Value vector
                with
                | _ -> nan
        }
```

With that option, you could run the solver in "safe" mode, bypassing any 
exception:  

``` fsharp
beale
|> NelderMead.objective
|> NelderMead.safe
|> ...
```

However, the more I think about it, the less I like this idea. Either  

- the objective function is safe in the first place, in which case you would 
get a tiny performance penalty for no benefit, or  
- the objective is not safe, in which case you would possibly get a massive 
performance hit, without any information surfaced about the exceptions that 
occurred.  

The only benefit I could see is for quick-and-dirty exploration. But even in 
that case, I think it's better to signal whatever exception might have 
occurred, and let the user guard the objective function accordingly. In other 
words, this `safe` function seems like a bad idea, potentially letting users do 
things they should not, without any meaningful feedback to avoid the problem - 
and I will be removing that code from the library!  

[1]: https://github.com/mathias-brandewinder/Quipu
[2]: https://en.wikipedia.org/wiki/Test_functions_for_optimization#Test_functions_for_single-objective_optimization
[3]: https://brandewinder.com/2025/06/11/maximum-likelihood-with-quipu-part-2/
