---
layout: post
title: Maximum Likelihood estimation with Quipu, part 1
tags:
- F#
- Algorithms
- Probability
- Optimization
- Maximum-Likelihood
---

Back in 2022, I wrote a post around using 
[Maximum Likelihood Estimation with DiffSharp][1] to analyze the reliability of 
a production system. Around the same time, I also started developing - and 
blogging about - [Quipu, my F# implementation of the Nelder-Mead algorithm][2].  

The two topics are related. Using gradient descent with DiffSharp worked fine, 
but wasn't ideal. For my purposes, it was too slow, and the gradient approach 
was a little overly complex. This led me to investigate if perhaps a 
simpler maximization technique like Nelder-Mead would do the job, which in turn 
led me to writing Quipu.  

Fast forward to today: while Quipu is still in pre-release, its core is fairly 
solid now, so I figured I would revisit the problem, and demonstrate how you 
could go about using Quipu on a Maximum Likelihood Estimation (or MLE in short) 
problem.  

In this post, we will begin with a simple problem first, to set the stage. In 
the next installment, we will dive into a more complex case, tp illustrates why 
MLE can be such a powerful technique.  

## The setup

Imagine that you have a dataset, recording when a piece of equipment 
experienced failures. You are interested perhaps in simulating that piece of 
equipment, and therefore want to model the time elapsed between failures. As a 
starting point, you plot the data as a histogram, and observe something like 
this:  

![histogram of observations]({{ site.url }}/assets/2025-05-28/observations.png)

It looks like observations fall in between 0 and 8, with a peak around 3.  

What we would like to do is estimate a distribution that fits the data. Given 
the shape we are observing, a [LogNormal distribution][3] is a plausible 
candidate. It takes only positive values, which we would expect for durations, 
and its density climbs to a peak, and then decreases slowly, which is what we 
observe here.  

<!--more-->

Let's create an F# script to illustrate the process, and get the dependencies 
out of way, loading first the libraries I will be using throughout this post.

``` fsharp
#r "nuget: MathNet.Numerics, 5.0.0"
#r "nuget: MathNet.Numerics.FSharp, 5.0.0"
#r "nuget: Plotly.NET, 5.0.0"
#r "nuget: Quipu, 0.5.2"
```

First, observing data that looks like a `LogNormal` isn't really a surprise, as 
I simulated the sample data using a `LogNormal` and `Math.NET`, using random 
parameter values of `mu = 1.3` and `sigma = 0.3`:  

``` fsharp
open MathNet.Numerics.Random
open MathNet.Numerics.Distributions

let mu, sigma = 1.3, 0.3
let rng = MersenneTwister 42
let duration = LogNormal(mu, sigma, rng)

let sample =
    duration.Samples()
    |> Seq.take 100
    |> Array.ofSeq
```

The histogram above was generated using `Plotly.NET`:

``` fsharp
open Plotly.NET

sample
|> Chart.Histogram
|> Chart.withXAxisStyle "Time between failures"
|> Chart.withYAxisStyle "# Observations"
|> Chart.show
```

The "true" distribution of that `LogNormal` can be plotted using its density 
(the function that represents the relative likelihood of observing each value), 
which is helpfully available in `Math.NET`:  

``` fsharp
[ 0.0 .. 0.1 .. 10.0 ]
|> List.map (fun t -> t, duration.Density(t))
|> Chart.Line
|> Chart.show
```

![density of the LogNormal distribution]({{ site.url }}/assets/2025-05-28/true-density.png)

## The problem

We happen to know the true distribution behind our sample, a `LogNormal` with 
parameters `(1.3, 0.3)`, because we are the ones who generated that sample in 
the first place. However, in real life, we wouldn't know these parameters. The 
problem we are interested in is to figure out what these parameters are, by 
using just our sample observations.  

Maximum Likelihood Estimation approaches that problem this way: assuming a 
specific distribution / shape, what is the set of parameters for that 
distribution that is the most likely to have produced the sample we observe?  

In our case, if we think a `LogNormal` is a plausible candidate, 
what we are looking for is values for the 2 parameters of a `LogNormal`, `mu` 
and `sigma`, that maximize the likelihood of observing our sample.  

Without going into the details of why the formula below works (see 
[this link][4] and [this one][5] for more), we can measure how likely it is 
that a particular probability model generated data by measuring its 
Log Likelihood, the sum over the sample of the log of the likelihood of each 
observation.  

This is a mouthful, but it isn't that complicated. Let's illustrate in code. 
In our example, what this means is that we can measure the likelihood that a 
`LogNormal` with parameters `mu` and `sigma` produced our sample using the 
following function:  

``` fsharp
let logLikelihood sample (mu, sigma) =
    let distribution = LogNormal(mu, sigma)
    let density = distribution.Density
    sample
    |> Array.sumBy (fun t ->
        t
        |> density
        |> log
        )
```

As an example, using the actual parameters `(1.3, 0.3)` that we used to generate 
our sample, we get:

``` fsharp
(1.3, 0.3) |> logLikelihood sample
> -151.8225702
```

If we try this with a different set of parameters, say `(1.0, 1.0)`, we get  

``` fsharp
(1.0, 1.0) |> logLikelihood sample
> -233.0546586
```

The log-likelihood using the "wrong" parameters `(1.0, 1.0)` is `-233`, much 
lower than the value we get using the "correct" parameters `(1.3, 0.3`, `-151`.

The idea here is to search across the possible parameters, and try to find the 
pair that maximizes the log-likelihood.  

## Solution with Quipu

Finding the parameters that minimize or maximize a function is exactly the type 
of problems `Quipu` is intended to handle. `Quipu` takes an `objective` 
function (the function we are trying to maximize), a starting value for the 
parameters, and searches by probing different directions and following the 
promising ones.  

Conceptually, it should be as simple as this:  

``` fsharp
open Quipu

logLikelihood sample
|> NelderMead.objective
|> NelderMead.maximize
```

However, this doesn't quite work:

``` fsharp
val it: SolverResult =
  Abnormal
    [|[|0.2588190451; -0.9659258263|]; [|-0.9659258263; 0.2588190451|];
      [|0.7071067812; 0.7071067812|]|]
```

What is going on here?  

The solver signals that it could not complete its search, and encountered an 
`Abnormal` situation, probing around value `(0.25, -0.96)`, `(-0.96, 0.25)` and 
`(0.70, 0.70)`. This makes sense, if you know that the parameter `sigma` of a 
`LogNormal` is expected to be positive:  

``` fsharp
LogNormal(1.0, -1.0)
> System.ArgumentException: Invalid parametrization for the distribution.
```

The first of the 3 values the solver is probing, `(0.25, -0.96)`, causes an 
exception. What can we do?  

An easy way to solve this is to add a guard in the log likelihood function, 
like so:  

``` fsharp
let logLikelihood sample (mu, sigma) =
    if sigma < 0.0
    then - infinity
    else
        let distribution = LogNormal(mu, sigma)
        let density = distribution.Density
        sample
        |> Array.sumBy (fun t ->
            t
            |> density
            |> log
            )
```

If the parameter `sigma` is less than 0, instead of instantiating a `LogNormal` 
and causing an exception, we simply return a log-likelihood of `- infinity`. 
As we are trying to maximize that function, any direction evaluating to 
`- infinity` will be rejected.  

Let's try again:  

``` fsharp
#time "on"
logLikelihood sample
|> NelderMead.objective
|> NelderMead.maximize
```

``` fsharp
Real: 00:00:00.002, CPU: 00:00:00.010, GC gen0: 0, gen1: 0, gen2: 0
val it: SolverResult =
  Successful
    { Status = Optimal
      Candidate = { Arguments = [|1.31780528; 0.2951006595|]
                    Value = -151.6237793 }
      Simplex =
       [|[|1.317242263; 0.2953732612|]; [|1.31723014; 0.2948290322|];
         [|1.31780528; 0.2951006595|]|] }
```

The solver proposes an optimal solution of `(1.31, 0.29)`, which is pretty 
close to the value we used to generate that sample, `(1.3, 0.3)`.  

How close? Let's compare the real and estimated densities:  

![density of the real and estimated distributions]({{ site.url }}/assets/2025-05-28/real-vs-estimated.png)

## Parting thoughts

When I originally set to write Quipu, my goal was to have a library to solve 
minimization / maximization problems that was reasonably fast and easy to use. 
Hopefully this example illustrates the point!  

One thing I don't like at the moment is how issues are surfaced to the user. 
The only information I had to figure out why the solver wasn't happy was that 
it encountered an `Abnormal` situation, with the input that caused the problem. 
This is about as uninformative as it gets, basically "something went wrong, 
figure it out". I'll revisit that part of the solver, to see if I can surface 
more detailed diagnosis, in this case something like "the objective function 
threw this exception".  

Otherwise, readers familiar with statistics might be thinking "this example is 
a bit pointless, because the parameters of a LogNormal can be estimated easily 
by transforming the sample back to a Normal distribution and computing some 
averages" - and they would be right. Using MLE in that particular example is a 
bit of overkill. However, in my next post, I will keep that same example, but 
got into some more interesting examples, illustrating the flexibility of 
Maximum Likelihood Estimation, and why I like it so much!  

[1]: https://brandewinder.com/2022/08/28/mle-of-weibull-process/
[2]: https://github.com/mathias-brandewinder/Quipu
[3]: https://en.wikipedia.org/wiki/Log-normal_distribution
[4]: https://en.wikipedia.org/wiki/Likelihood_function#Log-likelihood
[5]: https://brandewinder.com/2022/08/21/first-look-at-the-new-diffsharp/
