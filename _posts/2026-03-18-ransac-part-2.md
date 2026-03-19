---
layout: post
title: "RANSAC: estimating a model using very noisy data (part 2)"
tags:
- F#
- Algorithms
- Probability
- Optimization
- Machine-Learning

---

In our [previous installment][1], we set up the stage for our exploration of 
the [RANSAC algorithm][2], illustrating how traditional linear regression could 
perform quite badly on a dataset with many suspect observations. In a nutshell, 
the estimation penalizes large prediction errors more heavily, and as a result, 
it can over compensate for a few very large errors (so called "outliers"), with 
a poor model overall.  

This issue is particularly prevalent with "standard" linear regression, because 
it evaluates goodness of fit using the square of the prediction errors, which 
mechanically penalizes heavily larger errors. However, it applies beyond that 
specific case. Most estimation techniques proceed by minimizing some 
measurement of prediction error, and, as large errors are worse than small 
ones, will usually penalize large errors more heavily, introducing the same 
issue of sensitivity to outliers.  

The RANSAC algorithm attempts to address that issue, using a few simple ideas 
together. In pseudo-code, slightly modified from the [Wikipedia version][3], 
the key part of the algorithm goes like this:  

```
- Take a small random subset of the data available, hoping it contains mostly 
"clean" observations, so-called inliners,
- Estimate a prediction model on that small sample,
- Use that prediction model on the entire data. If the error on an observation 
is too large, discard it as an outlier, otherwise keep the observation as a 
potential inliner,
- If the overall number of inliners is too small (i.e. we have too many 
outliers), this model is a bad fit, discard it,
- Otherwise estimate a model on the inliners, and return the result.
```

<!--more-->

In other words, this routine attempts to find a suitable candidate. The overall 
algorithm simply wraps that procedure in a search loop, producing many candidates 
and returning the best candidate found.  

## Why would it work?

The key idea in the algorithm is to use a small subset of the data available to 
estimate a candidate model. This is somewhat counter-intuitive: in general, 
more data is considered better. However, we are considering a situation where 
many observations are so unreliable that they could heavily distort our 
estimation. In that case, what we want is to eliminate such bad apples from the 
sample we use to estimate. By drawing multiple small samples from all the data 
available, we increase the chances to randomly draw a sample that comprises 
only "clean" observations.  

Let's illustrate this on a small example. Suppose we have a sample of 100 
observations, and we happen to know that half of these observations are "bad". 
If we pick 4 random observations, we have a 6.25% chance of obtaining 4 
"clean" observations, that is, there is a 93.75% probabiliy that our sample 
contains at least a bad outlier. However, if we draw 10 random samples of 4 
observations, we have now only a 52.4% chance that all of these samples are 
contaminated, that is, there is now a 47.5% chance that one sample at least is 
free of outliers. Draw 20 random samples instead of 10, and that probability 
climbs to 72.5%. Draw 100, and we have a 99.8% probability that at least one of 
the samples is completely free of outliers.  

With a small sample, we can estimate a model quickly. However, how do we decide 
if that model is any good? We simply use that model to predict the rest of our 
observations, and check how many of the predictions are bad. If many 
predictions are bad, our small sample probably contained an outlier (a likely 
situation), and we have a bad model. Try again, and draw another sample!  

Note that because because we draw small samples, a single outlier will likely 
result in a terrible prediction model, so this approach will also be effective 
at discarding bad samples, too.  

If the model is not too bad, we simply eliminate all the observations which 
had poor predictions as outliers, and re-estimate a model, using all the data 
available, minus the observations that were flagged as probable outliers.  

## F# Implementation

Implementing RANSAC in F# was pretty direct. The algorithm is very generic, so 
I went with a very generic implementation. Our key building blocks are:  

- We have Observations, of some generic type `'Obs`,
- We are trying to predict Labels, of some generic type `'Lbl`.
- We have a dataset of Examples, a collection of Observations with their actual 
recorded Label:  

``` fsharp
type Example<'Obs, 'Lbl> = {
    Observation: 'Obs
    Label: 'Lbl
    }
```

- We want a Predictor, a function that can predict the Label of an Observation. 
In other words, a Predictor is a function that, given an `'Obs`, returns a 
predicted `'Lbl`: `'Obs -> 'Lbl`.

- To instantiate such a Predictor, we need parameters, of some generic type 
`'Param`. So estimating a model means using a sample of Examples to get good 
Parameters, which we can then use to instantiate a Predictor.  

With that out of the way, let's look at a possible F# 
[implementation of RANSAC][4]. The `findCandidate` function looks like so, a 
fairly direct translation of the pseudo-code:  

``` fsharp
let findCandidate
    (config: Configuration)
    (estimateParameters: Example<'Obs, 'Lbl> [] -> 'Param)
    (predictor: 'Param -> 'Obs -> 'Lbl)
    (isInliner: (Example<'Obs, 'Lbl> * 'Lbl) -> bool)
    (loss: ('Obs -> 'Lbl) -> Example<'Obs, 'Lbl> [] -> float)
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
    let confirmedInliners =
        data
        |> Array.filter (fun example ->
            let prediction = predictor maybeModel example.Observation
            isInliner (example, prediction)
            )
    if confirmedInliners.Length <= config.MinimumInlinersRequired
    then None
    else
        let betterModel =
            confirmedInliners
            |> estimateParameters
        let betterPredictor = predictor betterModel
        (
            betterModel,
            loss betterPredictor confirmedInliners
        )
        |> Some
```

We discussed most of the arguments already, the only 2 that need a comment are 
`isInliner` and `loss`.  

The purpose of `isInliner` is to detect if an Example 
is an inliner, which requires comparing its true Label (the correct answer) 
with its predicted Label.  

> Technically, we could have just passed the 2 Labels, 
but by passing the entire Example, we enable more complex predicates.  

The `Inliners` module in `Ransac.fs` contains one simple way of deciding 
if an Example is an inliner. The `within` function checks if the actual and 
predicted labels are within a certain distance of each other, so for instance 
`Inliners.within 0.5` will flag an example as an inliner if the correct label 
is within 0.5 of the value the model predicts.  

The purpose of `loss` is to compare the quality of 2 models on the same data. 
`loss` is usually some form of distance, measuring goodness of fit. A `loss` of 
0 indicates a perfect fit, and a larger loss indicates a model where 
predictions are further away from the target values.  

Our `loss` signature has 3 elements: `('Obs -> 'Lbl)`, the Predictor we 
evaluate, `Example<'Obs, 'Lbl> []`, the dataset we use for comparison, and 
`float`, the goodness of fit measurement.  

The `Loss` module in the same `Ransac.fs` file has 2 examples of classic loss 
functions, `Loss.mae`, the MAE (mean average error) and `Loss.rmse`, the RMSE 
(root mean square error).  

And that's pretty much it for the implementation! The `Ransac.fit` function 
simply wraps the `findCandidate` function, and generates a sequence of the best 
candidates it found so far.  

## Does it work? An example

To illustrate RANSAC in action, we will take the same example we introduced in 
[our previous post][1], where we generated a dataset of observations that fit 
a straight line `Y = 1 + 0.5 * X`, with some noise added, and included 50% of 
observations that were pure noise, or outliers. We saw that, unsurprisingly, 
estimating the model using a standard linear regression was not working very 
well, and produced parameters of `{ Constant = 1.12; Slope = 0.31 }`, instead 
of the correct values, `{ Constant = 1.0; Slope = 0.5 }`. Let's see if RANSAC 
does any better.  

You can find the full example in the script [linear-simple.fsx][5].  

We setup the RANSAC algorithm:  

``` fsharp
let config: Configuration = {
    RNG = System.Random 0
    MinimumTrainingSampleSize = 5
    MinimumInlinersRequired = 70
    }

let search =
    sample
    |> Ransac.fit
        config
        estimator
        predictor
        (Inliners.within 0.1)
        Loss.mae
```

From our 100 examples, we will use samples of only 5 datapoints to estimate 
models (`MinimumTrainingSampleSize = 5`), and require that at least 70 
predictions are inliners to select a model, which we define as "the predicted 
value must be within 0.1 from the correct value". And we are done!  

> Note: we could, and perhaps should, use less than 5 observations. Also, using 
a threshold of 70 decent values when we know 50% of the values are outliers is 
probably too aggressive.  

`search` produces an infinite sequence of models, with improving loss, which 
we can then look at. For instance we could start searching until we get actual 
candidates (`Seq.choose`), then take at least 20, and return the last one, 
which will by definition be the best one found so far:  

``` fsharp
let best =
    search
    |> Seq.choose id
    |> Seq.take 20
    |> Seq.last
```

This produces the following parameters, very close to the correct values:  

``` fsharp
{ Constant = 1.007498869; Slope = 0.5012996577 }
```

Visually, the RANSAC model clearly does a much better job than linear 
regression here:  

![Scatterplot of a noisy dataset, with the true model, naive regression and ransac regression overlayed]({{ site.url }}/assets/2026-03-18/ransac-regression.png)

## Parting thoughts

That's where I will leave things today! I am not entirely satisfied with the 
organization of the `Ransac.fit` signature, and will probably revisit the code 
in the future. That being said, my intent wasn't to produce a production 
quality library (yet!), I mainly wanted to understand how the algorithm works, 
and have something usable for my own purposes.  

I find the algorithm quite interesting. My initial instinct was to increase the 
`MinimumTrainingSampleSize` to improve model estimation, because that is what 
you do in general in machine learning - if you want better results, use more 
data. This is clearly not the case here: the idea is to get a sample as small 
as possible, to increase the chances of having no outliers, and therefore get a 
model good enough to determine which points are outliers. Using a sample that 
was as small as possible was initially counter-intuitive to me, but makes 
perfect sense in hindsight.   

The algorithm also made me mull over the notion of outliers. In essence, RANSAC 
is about eliminating observations we deem implausible. This is something I am 
uncomfortable with in general. Discarding observations that are further than an 
arbitrary threshold is a blunt instrument, truncating the tails of 
the error around data. I noticed that one area of application of RANSAC is 
image recognition, where the notion of "too far to be right" makes sense. This 
is a reasonable use case, but I am not entirely clear on when RANSAC is, and 
isn't, an appropriate approach. I have also been wondering if a maximum 
likelihood approach could work, with a setup along the lines of including a 
probability that each observation is an outlier.  

Finally, I have been wondering if one could devise an approach to auto-tune the 
RANSAC parameters. One input that is definitely needed "what is the smallest 
sample usable to estimate a model". Beyond that, the algorithm hinges on the 
proportion of outliers in the data, and what distance is too large for a 
prediction to be an inliner. I suspect these could be estimated, and I might 
try that out next!  

[1]: https://brandewinder.com/2026/03/05/ransac-part-1/
[2]: https://en.wikipedia.org/wiki/Random_sample_consensus
[3]: https://en.wikipedia.org/wiki/Random_sample_consensus#Pseudocode
[4]: https://codeberg.org/mathias-brandewinder/ransac/src/commit/fa81504f4266097ba786cc53b08ff77970749ccd/src/Ransac/Ransac.fs
[5]: https://codeberg.org/mathias-brandewinder/ransac/src/commit/fa81504f4266097ba786cc53b08ff77970749ccd/docs/linear-simple.fsx