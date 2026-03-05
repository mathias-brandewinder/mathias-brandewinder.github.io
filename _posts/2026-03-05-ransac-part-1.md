---
layout: post
title: "RANSAC: estimating a model using very noisy data (part 1)"
tags:
- F#
- Algorithms
- Probability
- Optimization
- Machine-Learning

---

Recently, as part of a project I am working on, I had to estimate a model to 
make some predictions. And, as is usually the case, the data available was not 
very good, with a lot of suspect data points, so called "outliers". Estimating 
the parameters of a model becomes tricky then, because a few data points that 
are very wrong can have an outsized impact on the parameters, and tilt the 
results of the estimation far off the correct values.  

This lead me to the [RANSAC][1] algorithm, which is designed to handle that 
exact problem. And, in my experience, re-implementing an algorithm from scratch 
is a great way to really understand how it works, so that's what I did: you can 
[find the current code here][2].  

In this post, I will motivate the problem first, demonstrating how outliers 
can wreck model estimation. In our next installment, we will go over RANSAC and 
see if it fares any better!  

Let's illustrate the problem on a simple example. Imagine that we have a model, 
where we observe a value `X` and a value `Y`, and that these 2 follow a simple 
relationship where  

`Y = 1 + 0.5 * X`

That is, they form a straight line. Now imagine that we have a dataset with a 
sample of observations for `X` and `Y`, with 2 caveats:  

- In half the cases, the observation is completely wrong, and there is no 
relationship between `X` and `Y`,  
- When the observation is correct, the observation is a bit off, and the 
recorded values are `Y = 1 + 0.5 * X + some noise`.  

Let's first create a model to represent that:  

``` fsharp
type Obs = { X: float }

type Parameters = {
    Constant: float
    Slope: float
    }

let predictor (parameters: Parameters) =
    fun (obs: Obs) ->
        parameters.Constant
        + parameters.Slope * obs.X

let trueParameters = {
    Constant = 1.0
    Slope = 0.5
    }
```

We have observations `Obs` and model `Parameters`. 
The "true" model has parameters `{ Constant = 1.0; Slope = 0.5 }`, which we can 
use to predict the value `Y` like so:  

``` fsharp
predictor trueParameters { X = 1.0 }
val it: float = 1.5
```

<!--more-->

We can now generate a synthetic sample of 100 examples, recording the value `X` and the 
value we observe for `Y`, the Label. We deliberately add noise to the dataset, 
so the Label we observe could be far off the correct value:  

``` fsharp
let rng = System.Random 0
let probaNoisy = 0.5
let sample =
    Array.init 100 (fun _ ->
        let obs = { X = rng.NextDouble () }
        let y =
            if rng.NextDouble () < probaNoisy
            then 1.0 + 0.5 * rng.NextDouble ()
            else 
                predictor trueParameters obs 
                + (0.2 * rng.NextDouble () - 0.1)
        {
            Observation = obs
            Label = y
        }
```

With a 50% probability, the `Y` value is generated randomly, without any 
relationship whatsoever to `X` (outlier). Otherwise, the `Y` value will be the 
"correct" value, plus some random noise, between plus and minus 0.1.

Let's visualize the dataset, using [Plotly.NET][3], together with the "true" 
model that we want to estimate from the data:  

``` fsharp
[
    Chart.Scatter (
        sample
        |> Array.map (fun ex -> ex.Observation.X, ex.Label),
        StyleParam.Mode.Markers
        )
    |> Chart.withTraceInfo "Sample"

    Chart.Line (
        [ 0.0; 1.0 ]
        |> List.map (fun x -> x, predictor trueParameters { X = x })
        )
    |> Chart.withTraceInfo "True Model"
]
|> Chart.combine
|> Chart.show
```

![Scatterplot of a noisy dataset, with the true model overlayed]({{ site.url }}/assets/2026-03-05/scatterplot.png)

This is what we'll be working with. The data is very noisy, and it is hard to 
visually detect the straight line that we used to generate the data behind all 
the noise. Our goal will be to see if [RANSAC][1] can actually pick it up!  

Before diving into RANSAC, first let's illustrate the issue I brought up 
earlier. What would happen if we tried to use standard linear regression here?  

To do so, we bring in `Math.NET`, and run a line fit, like so:  

``` fsharp
#r "nuget: MathNET.Numerics.FSharp"
open MathNet.Numerics

let lineFit (sample: (float * float) []) =
    let xs, ys =
        sample
        |> Array.unzip
    let struct (x, y) = Fit.line xs ys
    {
        Constant = x
        Slope = y
    }

let estimator (sample: Example<Obs, float> []) =
    sample
    |> Array.map (fun ex -> ex.Observation.X, ex.Label)
    |> lineFit

let naiveParameters =
    sample
    |> Array.map (fun ex -> ex.Observation.X, ex.Label)
    |> lineFit
```

This produces the following estimates for our model:  

``` fsharp
{ 
    Constant = 1.116521067
    Slope = 0.3092724541
}
```

This is... not very good:  

![Scatterplot of a noisy dataset, with the true model and naive regression overlayed]({{ site.url }}/assets/2026-03-05/naive-regression.png)

The line produced by the naive regression is pretty far off. This is not 
unexpected, standard regression is known to be sensitive to outliers, and we 
deliberately added a lot of bad data to our sample.  

In practical terms, what is happening here is that the regression cannot 
distinguish between good and bad data, and is trying to find a line where no 
observation is too far off. But we can see on the scatterplot that:  

- We have a lot of bad observations for `X < 0.5` with high `Y` values,  
- We have a lot of bad observations for `X > 0.5` with low `Y` values.  

To accomodate for these outliers, the regression has to reduce the slope of the 
line down, and instead of the correct value, `0.5`, we get `0.3`, which is 
pretty bad.  

And that's where we will leave things today. Now that we demonstrated on a 
simple example how linear regression can go wrong when used on a noisy dataset, 
in our next installment, we will see if RANSAC fares any better!


[1]: https://en.wikipedia.org/wiki/Random_sample_consensus
[2]: https://codeberg.org/mathias-brandewinder/ransac/src/commit/6f11b28ebdf8dc69252d512849dae64ae71fc0f7
[3]: https://plotly.net/
[4]: https://numerics.mathdotnet.com/