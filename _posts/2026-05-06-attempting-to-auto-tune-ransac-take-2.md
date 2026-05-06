---
layout: post
title: "Attempting to auto-tune RANSAC, take 2"
tags:
- F#
- Algorithms
- Probability
- Optimization
- Machine-Learning

---

This post is a continuation of my exploration of the [RANSAC algorithm][1]. In 
my [previous post][2], I began investigating if I could auto-tune some of the 
input parameters. The first attempt was not a success, but gave me an idea, 
which will be today's post.  

As a quick recap, RANSAC is a method to estimate a model in the presence of 
noisy data (so-called outliers). The method requires 2 input parameters:  

- `t`, "A threshold value to determine data points that are fit well by the 
model (inlier)",  
- `d`, "The number of close data points (inliers) required to assert that the 
model fits well to the data".

Rather than having to specify myself these 2 arguments, I would like the model 
to figure out good values by itself. In my initial attempt I tried to directly 
estimate the proportion of inliers in the dataset. This time, I will try a 
different angle: what if I started from pessimistic estimates, assuming many 
outliers and very high noise, and progressively tightened up the estimates?  

<!--more-->

## Thought process

My train of thought here is along these lines. Suppose We have a dataset where 
some proportion of the data follows a model (the inliers), while some 
observations do not (the outliers). We could start by making a pessimistic 
assumption, guessing that `p`, the proportion of outliers, is large, say, 50%. 
In other words, we assume that many of the observations are "bad". We can also 
start with a pessimistic estimate of the prediction error, by measuring it 
using a random model assuming 50% of outliers.  

If we estimate a model using RANSAC under these assumptions, then one of two 
situations can occur:  

- We picked a sample containing only inliers and the estimate should be good,  
- We picked a sample polluted by outliers and the estimated model should be terrible.  

Now if more observations than expected are a decent fit, we could assume that 
our initial assumptions were too pessimistic, and make adjustments:  

- Decrease our guess for `p`, the proportion of outliers,  
- Decrease our guess for `t`, the error threshold describing how close clean 
observations should be from their true value.  

So, with a lot of hand-waving, we could follow the same general approach as in 
standard RANSAC, but progressively tighten up the values of `p` and `t` when we 
observe better results than expected.  

As I started following that train of thoughts, I realized there was an issue.  

Let's illustrate the issue on a hypothetical case. Imagine that we were unlucky 
and picked really bad outliers initially. We have an awful model to start with, 
and our estimate for prediction errors is very high. We then estimate a 
second model, and, because our initial model was awful, we have a very large 
margin on errors, so many more observations than expected are a decent fit. 
For the sake of illustration, let's say 90% of observations are better than 
anticipated. We could then tighten up `p` to 10%, recompute the expected 
prediction error accordingly, and keep going.  

This would be problematic. The 90% observations that are a good fit are not 
necessarily inliers, because we used a "pessimistic" value for the expected 
error threshold `t`. If `t` is too large, too many observations will be 
classified as inliers. So if we update `p` to 10%, we will be stuck with an 
overly optimistic estiate for the next iterations, even though the true value 
might be lower than that.  

Stated differently: there is a relationship between `p` and `t`. If I decrease 
`t`, the expected predicted error margin, I also mechanically reduce the number 
of inliers I could find.  

So what can we do? One approach would be to do a gradual update. If, for a 
given error level, we assumed 50% inliers but found 90% of observations that 
fit within the error, what we can say is that:  

- We have probably more than 50% inliers,  
- We have probably a lower error threshold `t` than we assumed.  

So rather than a big adjustment, we could make a small adjustment, taking a 
small step in the right direction. As an example, we could move by 20% towards 
the evaluated value, like so:  

`updated p = 0.8 * current p + 0.2 * evaluated p`  

Which, in our case, would lead to:  

`updated p = 0.8 * 50% + 0.2 * 10% = 42%`

That is, instead of dropping instantly to `p outliers = 10%`, we make a small 
move to `p outliers = 42%`.  

## Validating the thought process

This was a lot of hand-waving and assumptions! Let's see if the idea has legs, 
by trying out a quick-and-dirty implementation.  

We will start with the same setup as in the previous post, with a synthetic 
dataset like so:  

``` fsharp
let trueParameters = {
    Constant = 1.0
    Slope = 0.5
    }

let rng = System.Random 0
let probaNoisy = 0.25
let sample =
    Array.init 100 (fun _ ->
        let obs = { X = rng.NextDouble () }
        let y =
            if rng.NextDouble () < probaNoisy
            then 1.0 + 0.5 * rng.NextDouble ()
            else predictor trueParameters obs + (0.02 * rng.NextDouble () - 0.01)
        {
            Observation = obs
            Label = y
        }
        )
```

We generate 100 observations, where 75% follow a straight line 
`Y = 1 + 0.5 * X`, with a bit of noise added (`+/- 0.01`), and 25% are pure 
noise, without any relationship with the model.  

> Both the noise level and the proportion of outliers have been reduced a bit 
from previous posts, to make the dataset less hard to work with.  

Instead of using fixed, user-supplied parameters, our algorithm will need to 
adjust `p` and `t`, so let's create a data structure to track that:  

``` fsharp
type State = {
    ErrorThreshold: float
    OutliersProportion: float
    }
```

We will initialize the `State` assuming 50% of outliers. This could easily be 
parameterized, but we are just trying to evaluate if the idea works at all, so 
let's be lazy, and reuse whatever we can from the existing code:  

``` fsharp
let init
    (config: Configuration)
    (estimateParameters: Example<'Obs, float> [] -> 'Param)
    (predictor: 'Param -> 'Obs -> float)
    (data: Example<'Obs, float> [])
    =
    // sample n random observations from data
    let maybeInliers =
        Array.init config.MinimumTrainingSampleSize (fun _ ->
            let index = config.RNG.Next data.Length
            data[index]
            )
    let maybeModel =
        maybeInliers
        |> estimateParameters
    let errors =
        data
        |> Array.map (fun ex ->
            (predictor maybeModel ex.Observation - ex.Label)
            |> abs
            )
    let errorThreshold = errors.Percentile(50)
    maybeModel,
    {
        ErrorThreshold = errorThreshold
        OutliersProportion = 0.50
    }
```

We select a few random observations, estimate a model, and evaluate the median 
of the prediction error across the entire dataset, under the assumption that if 
50% of observations are inliers, then at best 50% of the errors will be within 
`t`.  

Now that we have a starting point, we want to follow the same general procedure 
as "regular RANSAC", with one modification: when more observations than 
expected are within the current `ErrorThreshold`, we will make a small update 
to `State`, using an `adjustmentRate` parameter describing how aggressively we 
want to perform adjustments:  

``` fsharp
let findCandidate
    (state: State)
    (config: Configuration)
    (adjustmentRate: float)
    (estimateParameters: Example<'Obs, float> [] -> 'Param)
    (predictor: 'Param -> 'Obs -> float)
    (data: Example<'Obs, float> [])
    =
    // sample n random observations from data
    let maybeInliers =
        Array.init config.MinimumTrainingSampleSize (fun _ ->
            let index = config.RNG.Next data.Length
            data[index]
            )
    // estimate a model using that sample
    let maybeModel =
        maybeInliers
        |> estimateParameters
    // which observations are predicted within the current error?
    let confirmedInliers =
        data
        |> Array.filter (fun example ->
            let prediction = predictor maybeModel example.Observation
            abs (example.Label - prediction) <= state.ErrorThreshold
            )
    let proportionInliers =
        float confirmedInliers.Length / float data.Length
    let proportionOutliers = 1.0 - proportionInliers

    // if too few predictions are within error, this is a bad model
    // and we discard it
    if proportionOutliers > state.OutliersProportion
    then None
    else
        let betterModel =
            confirmedInliers
            |> estimateParameters
        let betterPredictor = predictor betterModel
        let adjustedOutliersProportion =
            (1.0 - adjustmentRate) * state.OutliersProportion
            +
            adjustmentRate * proportionOutliers
        // if we have 70% of inliers,
        // the error on inliers should be ~ 70 percentile
        // of overall error
        let updatedError =
            data
            |> Array.map (fun ex ->
                abs (betterPredictor ex.Observation - ex.Label)
                )
            |> fun errors ->
                errors.Quantile (1.0 - adjustedOutliersProportion)
        if updatedError > state.ErrorThreshold
        then None
        else
            // we update the state, but only partially
            (
                betterModel,
                {
                    ErrorThreshold = 
                        (1.0 - adjustmentRate) * state.ErrorThreshold
                        + adjustmentRate * updatedError
                    OutliersProportion = adjustedOutliersProportion
                }
            )
            |> Some
```

That's a bit of a wall of code, and it's not particularly pretty. But again, we 
are in proof of concept mode, this is fine. Not much to say otherwise, this is 
just implementing the steps described above. Now for the real question - does 
it even remotely work? Let's see:  

``` fsharp
let initialState =
    sample
    |> init config estimator predictor 

let autoSearch (parameters, state) =
    (parameters, state)
    |> Seq.unfold (fun (p, s) ->
        match findCandidate s config 0.1 estimator predictor sample with
        | None -> Some ((p, s), (p, s))
        | Some (p', s') -> Some ((p', s'), (p', s'))
        )

autoSearch initialState
|> Seq.take 100
|> Seq.toArray
```

We use an adjustment rate of 0.1, and run 100 iterations:  

``` fsharp
[|
    ({ Constant = 1.006125602
       Slope = 0.4800994928 },
     { ErrorThreshold = 0.2383214144
       OutliersProportion = 0.452 });
    ({ Constant = 1.006114377
      Slope = 0.4855896171 }, 
     { ErrorThreshold = 0.2153375312
       OutliersProportion = 0.4098 });
    // omitted for brevity
    ({ Constant = 1.000455587
      Slope = 0.5003379682 },
     { ErrorThreshold = 0.03643983755
       OutliersProportion = 0.1402098022 });
    ({ Constant = 1.000455587
       Slope = 0.5003379682 },
     { ErrorThreshold = 0.03643983755
       OutliersProportion = 0.1402098022 })
|]
```

We end up with pretty good estimates for the constant (`1.000`) and slope 
(`0.500`). The estimates for `t` and `p` are not as good (`0.03` where we would 
like `0.01`, and `0.14` where we would like `0.25`) but these are not awful 
either.  

We should not get too carried away about how good the constant and 
slope estimates are, because the algorithm appears to have picked decent values 
from the get go. Then again, a cursory test with different seed values for the 
random number generator yielded more or less the same results, so this might be 
working after all.  

We can visualize the behavior of the algorithm, displaying these 4 values over 
time:  

![Convergence of the 4 values - constant, slope, t and p - over time]({{ site.url }}/assets/2026-05-06/convergence.png)

The parameters we are trying to estimate, `Constant` and `Slope`, fluctuate quite a 
bit in the beginning, but stabilize afterwards, around values that are pretty 
close to the correct ones. `Error Threshold` and `Outliers Proportion`, by design, 
can only decrease. That decrease is rapid over the first 100 iterations, and 
then slows down and more or less flattens out, slightly over-estimating the 
proportion of outliers and under-estimating the error.  

## Parting thoughts

I think that's how far I am going to go in this exploration of auto-tuning 
RANSAC. While this is clearly not "finished", my interest in RANSAC was 
initially motivated by a specific project, where I ended up using a totally 
different approach, so... time to move on to other questions that are more 
interesting to me right this moment :)

That being said, the gradual update approach presented here seems to have legs. 
Overall, it behaves as we hoped it would, yielding decent parameter estimates, 
and stabilizing as we go. However, I am not entirely convinced it is done. The 
update mechanism we used is pretty crude, and I have a nagging feeling that 
things could not work out as well in other situations. In particular, the fact 
that both state parameters can only go one direction is a source of concern: if 
at any time we end up over estimating the proportion of inliers, or under 
estimating the error threshold, there is no coming back - we will be stuck with 
bad values forever going forward. Somewhat relatedly, I am not totally 
satisfied with the estimation and update of the error threshold, and would look 
deeper into that if I were to spend more time on this.  

Another thought is around testing. In the end, all I did is validating on one 
particular dataset, which provides at best anecdotal evidence that the approach 
might work. If I were to look more into this, I would probably generate a 
battery of synthetic datasets, with various levels of noise and outliers, and 
compare the algorithm results across multiple datasets, to spot potential 
systematic biases for instance.  

Anyways, this was a fun exercise! I am glad I spent the time to dig into this 
algorithm, which is yet another example of how injecting a bit of randomness in 
an algorithm can work surprisingly well.  

[1]: https://brandewinder.com/2026/03/05/ransac-part-1/
[2]: https://brandewinder.com/2026/04/08/attempting-to-auto-tune-ransac/
