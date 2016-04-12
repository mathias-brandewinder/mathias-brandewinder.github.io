---
layout: post
title: Kaggle Home Depot competition notes&#58; model validation
tags:
- F#
- Machine-Learning
- Validation
- Kaggle
- Home-Depot
---

In my last post, I discussed how the features of a machine learning model could be represented as simple functions, extracting a value from an observation. This allowed us to specify a model as a simple list of features/function, defining what information we want to extract from an observation. Today, I want to go back to where we left off, and talk about model validation. Now that we have a simple way to specify models, how can we go about deciding whether they are any good?

<!--more-->

One aspect I find interesting - and slightly disturbing - about machine learning is its focus on effectiveness. My time among economists was mostly spent studying models that were supposed to help understand how things work. In the end, a good machine learning model is one that makes good predictions; why a specific model works is typically not the primary question.

In that frame, the question 'is model A better than model B' becomes 'does A make better predictions than B'. To answer that question, we need two ingredients:

* a way to measure whether a prediction is good or bad,
* a sample of observations with known correct answers (examples), to compare the model's prediction against a ground truth.

## Good prediction, bad prediction

Let's go back for a second to the Kaggle competition. The core model we ended up with last time looked like this:

``` fsharp
type Observation = {
    SearchTerms: string
    ProductTitle: string 
    }

type Relevance = float

type Predictor = Observation -> Relevance
type Example = Relevance * Observation
```

In this case, `Relevance` is expected to be a float between 1.0 and 3.0. A good prediction is one that is correct: if we had a perfect model, whenever we give it an `Example`, the predicted `Relevance` computed off the `Observation` part should equal the 'true' answer. How far off the prediction is from the expected value is then a measure of how bad things are. As an example, we could use the following measure for prediction errors, the square of the difference between the actual and predicted values:

``` fsharp
let error (actual:Relevance,predicted:Relevance) = 
    pown (actual - predicted) 2
```

A perfect score results in a 0.0, and the further apart the prediction is from the correct value, the larger the number.

That's not the whole story, however. A single good or bad prediction is not a great indicator for whether a model 'works'; We want to test a model on many examples, to get a sense for how good it performs overall. We need to aggregate together individual errors into one single meaningful metric, which will allow us to compare models. For instance, we could compute the average of the error across many observations. If we then take the square root of that value, the result can be seen as an average distance between predictions and target values, and has a name, the [RMSE](https://www.kaggle.com/wiki/RootMeanSquaredError), for Root Mean Square Error:

``` fsharp
let RMSE sample =
    sample
    |> Seq.averageBy error
    |> sqrt
```

Picking up a good metric is actually much more subtle than it might seem. In essence, what we are doing is reducing errors across many observations into a single number, and some information is bound to be lost in the process. In the case of our Kaggle competition, the metric is decided for you, which removes that problem from the equation: whether the RMSE is a good metric or not is irrelevant, our job is to be good at it :) If a model has a better RMSE, it is better for our purposes, and evaluating a `Predictor` simply becomes:

``` fsharp
let evaluate 
    (sample:Example seq) 
        (predictor:Predictor) =
    sample
    |> Seq.map (fun (actual,obs) -> actual, predictor obs)
    |> RMSE
```

## Good model, bad model

Now that we have a way to compare two predictors against each other, let's try this out. The simplest things we could do here is take a `Predictor`, and evaluate it across the entire available training set. As an example, let's try out a trivial predictor, which predicts a `Relevance` of 2.0 for every `Observation`:

``` fsharp
#I "../packages"
#r @"FSharp.Data/lib/net40/FSharp.Data.dll"

open FSharp.Data

type Training = CsvProvider<"""../data/train.csv""">
let training = 
    Training.GetSample().Rows
    |> Seq.map (fun row ->
        row.Relevance |> float,
        { 
            SearchTerms = row.Search_term
            ProductTitle = row.Product_title
        })
    |> Seq.toArray

let trivial : Predictor = 
    fun obs -> 2.0

evaluate training trivial
```

The result, `0.6563378382`, is not particularly important. What's interesting here is that we have an approach to compare two models. Is the predictor `let anotherPredictor : Predictor = fun obs -> 2.5` any better? We can just run this through the `evaluate` function, and confirm whether or not this hypothesis holds:

``` fsharp
evaluate training anotherPredictor
```

... which produces an evaluation of `0.5469420142` - that model appears to be better. Things can go terribly wrong with this approach, though. Consider for a minute the following model:

``` fsharp
type Learner = Example seq -> Predictor

let pairsLearner : Learner =
    fun sample ->
        let knowledge = 
            sample 
            |> Seq.map (fun (relevance,obs) -> 
                (obs.SearchTerms,obs.ProductTitle), relevance)
            |> Map.ofSeq
        let predictor : Predictor =
            fun obs ->
                let pair = (obs.SearchTerms,obs.ProductTitle)
                match knowledge.TryFind pair with
                | None -> 2.0
                | Some(x) -> x
        predictor
```

What we do here is learn every known search terms + product title pair, and create a predictor that simply looks it up, returns the "correct" result if it knows it, and predicts a `2.0` otherwise. What will happen if we evaluate that `Predictor` on the training set? The performance will be excellent, because the model will be predicting data it has already seen. How would that predictor fare on new data? It shouldn't do much better than the `trivial` predictor we created before: it will mostly predict `2.0`, because it will encounter mostly new search term / product title combinations.

> Note: the Kaggle dataset contains duplicate search terms / product titles, corresponding to different raters; as a result, the evaluation on the training data will not be perfect, because human raters do not always agree.

The problem here is that our model doesn't generalize: it learns very well the information from the training set, but doesn't extract information that is applicable beyond that specific data set. The true value of a `Predictor` is in how good it is at producing good predictions on data it has not seen before in its learning phase; or, to use a quote often attributed to Niels Bohr,

> Prediction is very difficult, especially if it's about the future.

This creates a bit of a conundrum. All we have is training data - how can we evaluate a `Predictor` on data it has not seen before? One approach to resolve that issue is rather simple: use only part of the data to train a `Predictor`, and evaluate it on the rest, the data that was held out. A nice way to do that is [k-fold validation](https://en.wikipedia.org/wiki/Cross-validation_(statistics)#k-fold_cross-validation): take the training sample, partition it in, say, 10 equal slices. Then, take 1 of the slices out, train a model on the 9 remaining blocks, and evaluate the resulting `Predictor` on the last slice. Repeat the process for every possible combination, training and evaluating 10 different models, and average out the 10 evaluations. The evaluation will now be roughly 10 times slower than before, but the resulting evaluation will be reasonably reliable, because each of the models will be tested against data it has never seen before.

Here is a rough implementation of k-fold; it can certainly be improved, but should illustrate the principle decently well. We pass to the `kfold` function the number of folds `k`, a training sample, and a `Learner`. Each `Example` is assigned a random number, the block it is assigned to, creating `k` slices of roughly the same size. All that's left to do then is to evaluate on each of the `k` slices (filter out the data to hold out, learn a model on the rest and evaluate), and average the results over the slices:

``` fsharp
let kfold 
    (k:int) 
        (sample:Example seq) 
            (learner:Learner) =

    let seed = 123456
    let rng = System.Random(seed)
    
    // assign each Example to a random block
    let partitionedSample = 
        sample
        |> Seq.map (fun x -> rng.Next k, x)

    let evaluateBlock block = 
        printfn "Evaluating block %i" (block+1)
        // extract the data held out for evaluation
        let hold = 
            partitionedSample
            |> Seq.filter (fun (b,_) -> b = block)
            |> Seq.map snd
        // extract the data used for training
        let used = 
            partitionedSample
            |> Seq.filter (fun (b,_) -> b <> block)
            |> Seq.map snd

        printfn "  Learning"
        let predictor = learner used
        printfn "%i" (hold |> Seq.length)
        printfn "  Evaluating"
        evaluate hold predictor

    // evaluate each of the k blocks
    [ 0 .. (k - 1)]
    |> Seq.map (fun block -> evaluateBlock block)
    |> Seq.average
```

The nice thing here is that, because of the way we defined a `Learner`, we don't need to worry about the specifics of how our model is trained. As long as we define a model following the signature `type Learner = Example seq -> Predictor`, which specifies what data it is allowed to use to learn, we can simply pass it to `kfold`, which will handle the annoying details for us:

``` fsharp
kfold 10 training pairsLearner
```

In essence, what we have now is a base setup to conduct rapid experiments: we can define models in a flexible manner with features-as-functions, and validate whether or not they constitute an improvement, by using cross-validation. We can focus on the part that matters - being creative in coming up with features - without being bogged down in extraneous details.

That's it for today! There is one missing piece which we haven't discussed so far, which connects this post to the previous one. Earlier on, we defined a `Feature` as a function `type Feature = Observation -> float`; if you consider this carefully, you'll realize that we have a potential problem, if the feature definition depends on the training sample. However, that would bring us a bit too far for a single post, so we'll leave that for another time.