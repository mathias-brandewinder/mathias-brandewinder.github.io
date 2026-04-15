---
layout: post
title: "Attempting to auto-tune RANSAC"
tags:
- F#
- Algorithms
- Probability
- Optimization
- Machine-Learning

---

In my [previous posts][1], I looked into the [RANSAC algorithm][2]. One thing I 
wondered about is, could the algorithm usage be made simpler by automatically 
tuning some of its input parameters? That is, rather than requiring the user to 
enter parameters, can we derive reasonable values for these parameters from the 
data? In this post, I will go over my first attempt. This was not a success, 
in that it did not produce immediately useful results, but it gave me a better 
understanding of the algorithm, and the process was interesting, so that's what 
this post will focus on.  

In the algorithm as described in [Wikipedia][2], 2 parameters stand out in 
particular:  

- `t`, "A threshold value to determine data points that are fit well by the 
model (inlier)",  
- `d`, "The number of close data points (inliners) required to assert that the 
model fits well to the data".

My thinking here was that, given a particular model, I should be able to derive 
these numbers from the data itself. `t`, the threshold value, is about how 
far predictions are from the correct value, something we can measure. `d` is 
about how many predictions should be close to their actual values overall. It 
is related to a different measure, the proportion of outliers. If I had, say, 
20% of outliers in my sample, I would expect roughly 80% of my model 
predictions to be close to the correct value.  

RANSAC assumes that you, the user, will input these values. What I wondered  
about is, if all I had was a model and a dataset, how I would go about 
evaluating the value of `d`. Or, stated differently, could I estimate 
`p(outliers)`, the proportion of outliers in a dataset?  

<!--more-->

## Thought process

Let's try, starting with clarifying some assumptions:  

- We are trying to fit some model to the data, predicting a label from 
observations,  
- Some observations are outliers, that is, they don't follow the model. Their 
label is way off what the model predicts, for whatever reason.  
- We assume that there is a proportion `p` of outliers, which we don't know.  

We can estimate a model using a very small random subset of the data. If we do 
so, 3 situations can occur:  

- Case 1: we were lucky and picked only "good observations". In that case, the 
model predictions should be generally good, except for the outliers. We should 
have a proportion `(1 - p)` of small errors, and `p` of much larger errors.  
- Case 2: we were unlucky and picked only outliers. In that case, the estimated 
model is terrible, and we should get mostly large errors, with perhaps a few 
small ones out of sheer luck.  
- Case 3, the most likely situation: we were unlucky and picked a mix of 
outliers and inliners. Practically, the result should be similar to Case 2. The 
model should be pretty bad, because even 1 outlier in a small sample should 
have a large impact on estimation quality, so most of the prediction errors 
should be large.  

Now if I knew `p`, I could compute the probability that a random sample of `n` 
observations is in Case 1, 2 or 3. Case 1 occurs if I pick inliners `n` times. 
Picking an inliner has a probability `(1 - p)` of occurring, so Case 1 has a 
probability of `(1 - p) ^ n`. Similarly Case 2 has a probability of `p ^ n`, 
and Case 3 is whatever is left.  

Let's illustrate on a concrete example, with `p = 0.2` (20% outliers) and 
`n = 3`. In that case, the probability of Case 1 is `0.8 * 0.8 * 0.8 = 0.512`: 
we picked a "good sample", with no outlier, and the estimated model should be 
good. Conversely, with a probability of `1.0 - 0.512 = 0.488`, we picked 1 or 
more outliers (Case 2 or 3), and the model we estimated should be a bad fit.  

So far, so good. What can I do with that?  

I could pick, say, 100 random samples of 3 data points (`n = 3`), and estimate 
100 different model parameters. What I would expect then is that for about 51 
of these samples I would have a good model (Case 1), and for 49 the estimated 
model would be contaminated by 1 or more outliers (Case 2 or 3). So, for about 
51 samples, I would expect roughly 80% of the errors to be low, and 20% to be 
high (the outliers), whereas for the 49 "bad" samples I would expect mostly 
high errors.  

## Validating the thought process

Let's try that out, on the same example we used in [our previous posts][3]. We 
generated a sample of 100 data points where:  

- 50% of the data followed a straight line, with some noise added (+/- 0.1),  
- 50% of the data was outliers (random noise).  

``` fsharp
let rng = System.Random 0
let probaNoisy = 0.5
let sample =
    Array.init 100 (fun _ ->
        let obs = { X = rng.NextDouble () }
        let y =
            if rng.NextDouble () < probaNoisy
            then 
                // outlier, random between 1.0 and 1.5
                1.0 + 0.5 * rng.NextDouble ()
            else
                // perfect model prediction
                predictor trueParameters obs
                // ... with added uniform noise, +/- 0.1
                + (0.2 * rng.NextDouble () - 0.1)
        {
            Observation = obs
            Label = y
        }
        )
```

We are interested in observing the prediction errors for different models. 
Because we are lazy, we will just tweak a bit the original code, like so:  

``` fsharp
let config: Configuration = {
    RNG = System.Random 0
    MinimumTrainingSampleSize = 2
    MinimumInlinersRequired = 70 // un-necessary here
    }

let evaluate
    (config: Configuration)
    (estimateParameters: Example<'Obs, 'Lbl> [] -> 'Param)
    (predictor: 'Param -> 'Obs -> 'Lbl)
    (data: Example<'Obs, 'Lbl> [])
    =
    // sample n random observations from data
    let maybeInliners =
        Array.init config.MinimumTrainingSampleSize (fun _ ->
            let index = config.RNG.Next data.Length
            data[index]
            )
    let maybeModel =
        maybeInliners
        |> estimateParameters
    data
    |> Array.map (fun ex ->
        predictor maybeModel ex.Observation - ex.Label
        |> abs
        )
```

We select 2 random examples from the data, estimate a model, and 
compute the error across the entire dataset.  

All that's left to do then is estimate 100 different models, each using a 
different random sample of 2 observations, and plot the errors. We will use the 
median error as a measurement of the overall error (the value such that half 
the errors are greater, and half are smaller), and sort the models by 
increasing median error:  

``` fsharp
open MathNet.Numerics.Statistics

// estimate 100 models and their error
let eval =
    Array.init 100 (fun _ ->
        sample
        |> evaluate config estimator predictor
        |> fun errors -> errors.Percentile(50)
        )
    |> Array.sort

eval
|> Array.mapi (fun i x -> i, x)
|> Chart.Line
|> Chart.show
```

The result is... not what I was hoping for:  

![Median prediction errors across 100 models, sorted in increasing order]({{ site.url }}/assets/2026-04-08/errors-100-models.png)

What I was expecting was:  

- For the first quarter ("clean" datasets), very low errors,  
- Followed by a steep increase of errors once we hit "contaminated" datasets.  

Instead, what we see is a gradual increase in errors for about 75% of the 
models, followed by a very steep increase for the last quarter. Stated 
differently, we don't see a clear boundary between the clean models and the 
ones that are contaminated with outliers.  

## Is this a failure?

This is clearly not what I expected. I expected a clear cliff after the first 
25 models, there is no such cliff. So yes, this is a failure.  

This took me aback. After the usual cycle of denial, anger, bargaining and 
depression, I reached acceptance, and started thinking again. Why is it not 
working? After all, the thought process was fairly reasonable. Where is the 
flaw, and can we fix this?  

After some thinking, my hypothesis was that there was simply too much noise in 
the data to cleanly distinguish between Case 1 and Case 2. The dataset is 
noisy in 2 different ways:  

- First, half the observations are outliers,  
- Then, the noise around inliners is fairly large. We add + or - 0.1 noise to 
"clean" observations, but the outliers are uniformly distributed between 1 and 
1.5. In other words, outliers are in a + / - 0.25 band around 1.25, which is 
not all that different from the noise level around "clean" observations.  

To confirm that this could be the source of the issue, I re-created the 
dataset, with a much smaller error band of + / - 0.01 around clean 
observations, like so:  

``` fsharp
    if rng.NextDouble () < probaNoisy
    then 
        // outlier generation unchanged
    else
        // perfect model prediction
        predictor trueParameters obs
        // ... with added uniform noise, +/- 0.01
        + (0.02 * rng.NextDouble () - 0.01)
```

I also had a hunch that the scale of the chart was potentially hiding 
meaningful differences, because the scale of large errors completely dwarfs the 
scale of the smaller errors, so I switched to a log scale, which produces the 
following chart:  

![Log of median prediction errors across 100 models, sorted in increasing order]({{ site.url }}/assets/2026-04-08/log-errors-100-models.png)

Lo and behold, this is much better! We see a very clear rise around the 
31st observation, roughly where we would expect it, somewhat close to 25.  

> Note: for the sake of completeness, I also tried to transform the original 
chart using a log scale. It still doesn't show anything meaningful happening 
around the 25th observation. In other words, the failure is confirmed.  

So where does this leave us? First, it was satisfying to see that my original 
idea was not entirely wrong. Then, it gave me a better understanding of the 
potential impact of errors. For RANSAC to work well, the outliers should be 
obvious outliers. The sample I used initially was particularly bad, because it 
contained many, many outliers, which weren't all that far off from clean 
observations.  

Is this useful? Maybe. Visually, I can pick up that around the 31st observation 
the errors degrade rapidly. From that I can deduce that 31% of the samples were 
probably purely "clean" observations, that is, Case 1. I can then infer that we 
probably have around 38% of outliers (`(1 - p) * (1 - p) ~ 0.39`, i.e. 
`p ~ 0.38`). It is not the best approximation, but it is not too bad either!  

The issue, though, is that while this approach gives us a visual method to 
calibrate RANSAC, it does not lend itself well to full automation. I replaced 
the original problem (finding a decent value for `d`) by another problem, which 
is not trivial: detecting a cliff in a curve, assuming there is one.  

I'll leave it at that for now. I have another direction I want to try out, but 
it needs to simmer for a bit first. In the meantime, I hope you found something 
of interest in this post!  

[1]: https://brandewinder.com/2026/03/05/ransac-part-1/
[2]: https://en.wikipedia.org/wiki/Random_sample_consensus
[3]: https://brandewinder.com/2026/03/18/ransac-part-2/
