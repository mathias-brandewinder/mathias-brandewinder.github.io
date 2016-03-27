---
layout: post
title: Kaggle Home Depot competition notes&#58; features
tags:
- F#
- Machine-Learning
- Features
- Patterns
- Experiments
- Accord
- Logistic-Regression
- FSharp-Data
- Kaggle
- Home-Depot
---

Against my better judgment, I ended up getting roped in entering the [Kaggle Home Depot Search Relevance](https://www.kaggle.com/c/home-depot-product-search-relevance) machine learning competition. As expected, this has been a huge time sink, and a lot of fun so far. One thing I found interesting is that this time I am working with [a team](https://www.kaggle.com/t/269401/f-kaggle). Having people to discuss ideas with is awesome; it is also an interesting opportunity to observe how others approach problems, and offers a chance to contrast methods and understand better what problem they are trying to address. In that frame, I thought I would try to put together some notes on recurring patterns I seem to repeat when setting myself up for this type of problem.

<!--more-->

## Context

One aspect where "traditional" software development and machine learning are fairly different is domain modelling. In a typical application, domain modelling revolves around creating a minimal set of entities, composed together into a workflow to perform some real-world process. Coming up with that model is usually somewhat iterative, but mostly involves figuring out boundaries to isolate responsibilities.

Developing a machine learning model is a fairly different affair. At a high level, the problem can be described along these lines: starting from raw data, I want to extract pieces of information that are relevant to something I am attempting to predict. These pieces of information will then be fed into one of many possible algorithms, which will try to learn how to predict the output we care about, based on that information.

To make it less abstract, let's take a look at the Home Depot competition. The goal here is to take a query made by humans in a search engine, look at what product was returned, and decide whether the result is any good, on a scale from 1 (terrible) to 3 (perfect). In other words, when we are done, what we should have is a model (the predictor) that looks along these lines:

``` fsharp
type Observation = {
    SearchTerms: string
    ProductTitle: string 
    }

type Relevance = float

type Predictor = Observation -> Relevance
```

The model above is slightly simpler than the actual one, but fundamentally the same; the only significant difference is that the "real" one has a bit more data available. This is also the archetype of most machine learning problems: you have an `Observation`, the data you have available, and you are trying to produce a prediction, which could be a number, like here, but also classes (Spam/Ham, Click or No Click, ...).

## Learning by example

So how do we go from an `Observation` to a prediction? You learn by example, using a training set, a sample of observations for which the "correct" answer is known. In this particular case, here is how our training set looks like - the product title, the search query, and the actual relevance, determined by a human rater:

```
"HDX 6 ft. Heavy Duty Steel Green Painted T-Post","wire fencing 6 ft high",1.67
"Duck 1.41 in. x 60 yds. Blue Clean Release Masking Tape, (16-Pack)","masking tape",3
"YuTrax Arch XL Folding Aluminum ATV Ramp","car ramps ends",2
"Rust-Oleum Restore 1-gal. 4X Deck Coat","restore 4x",2.67
...
```

Learning by example means that we will use the data we have available, and feed it into one of many possible algorithms (regression, random forest, neural networks...); the algorithm's job is to take in that information, and figure out a function which mimics as closely as possible the correct answer.

Representing this with types is fairly straightforward:

``` fsharp
type Example = Relevance * Observation
type Learner = Example [] -> Predictor
```

An `Example` is an `Observation` for which the correct answer is known, in our case the `Relevance`. We will use a sample, an `Example` collection, and pass it to an algorithm, whose job is to learn, however that works, and give us back a `Predictor`.

As a trivial example, we could for instance create a `Predictor` that returns the average `Relevance`, regardless of the `Observation`. This is probably not going to be a great model, but it could be useful, if only to benchmark other models against a basic measuring stick.

``` fsharp
let trivialModel : Learner = 
    function sample ->
        let average = 
            sample 
            |> Seq.map fst // extract Relevance from the tuple
            |> Seq.average
        let predictor (obs:Observation) = average
        predictor 
```

The nice thing here is that this provides a common structure - no matter what algorithm I use, I should be able to fit it in this skeleton. If not, something is probably off.

## Features

Obviously, in its current form, the data is not very usable by an algorithm. Algorithms typically don't understand English like "wire fencing 6 ft high", and operate on numbers. Our job designing a model is precisely that: transforming the raw input into numbers that can be processed by an algorithm. To be more specific, we need an approach that will be flexible enough to handle potentially multiple algorithms. Some algorithms work better for some problems, and the only way to know is to try it out. We want an approach that enables us to plug in different algorithms, and compare their respective results.

For the sake of illustration, let's assume for instance that perhaps the number of characters in the search terms matter. This is not entirely unreasonable: a search engine has more information to go on with a longer search. It's easier to figure out what "wire fencing 6 ft high" is about, than "restore 4x".

This is called a *feature*: from a raw observation, we extract some measurable and hopefully useful piece of information.

One possible approach here would be to start tacking features as properties onto the `Observation`, like this:

``` fsharp
type Observation = {
    SearchTerms: string
    ProductTitle: string 
    }
    with member this.SearchLength = this.SearchTerms.Length |> float
```

This is technically feasible, but will soon turn out ugly. First, it is quite plausible that we will create many features - dozens of them, or more. An entity with 50 properties doesn't sound like a good idea. Then, this doesn't fit well with what algorithms typically expect, that is, arrays of numbers. 

As an example, consider the [Logistic Regression algorithm in Accord.NET](http://accord-framework.net/docs/html/T_Accord_Statistics_Models_Regression_LogisticRegression.htm). The input is expected to be of the form `float[][]`, where each row is an observation, transformed into an array of floats, its features, and the output is a `float[]`, the correct value to be predicted for each observation. This is pretty typical - and if we want to use the "extended" `Observation`, we will need to put in place some annoying transformation, to flatten the observation into a `float[]`.

This is also going to introduce some rigidity in our process. We currently have one feature in mind, but our design process will be to conduct many experiments: create a new feature, try it out, perhaps remove some others. The iteration cycle is very fast - we need to potentially entirely reshape the way our `Observation` is presented to the algorithm, and feed it different features. We might even want to try and compare different possible combinations of features at the same time. What we really want is a way to keep the source data unchanged (an `Observation` is an `Observation`, and nothing else), but create flexible combinations of features, extracting a `float[]` from them.

## Extracting Features as functions

As often, types provide some guidance on how we might approach the problem. What we want is to transform an `Observation` into a `float[]`. This *is* a function signature. We can then simply create the following:

``` fsharp
type Feature = Observation -> float

let extractFeatures 
    (features: Feature[]) 
        (obs: Observation) =                
        features 
        |> Array.map (fun f -> f obs)
``` 

Any `Feature` should extract a `float` out of an `Observation`; and we can extract any collection of features out of an `Observation` by applying a simple map. This is very convenient: we can now maintain as many features as we wish, and specify a model as a particular combination of them. For instance, we could do the following:

``` fsharp 
let ``Search Terms characters`` : Feature =
    function obs -> 
        obs.SearchTerms.Length |> float

let ``Matching characters between title and search terms`` : Feature = 
    function obs ->
        let searchChars = obs.SearchTerms |> Set.ofSeq
        let titleChars = obs.ProductTitle |> Set.ofSeq
        Set.intersect searchChars titleChars
        |> Set.count
        |> float

let model = [|
    ``Search Terms characters``
    ``Matching characters between title and search terms``
    |]
```

This is pretty nice - at least, I think so :) At that point, I can keep my `Observation` the way it is, maintain independently my features, and create as many "models" as I want, as collections of features that specify how data should be extracted out. I have a reasonably clean way to handle the volatility in my experiments, and share/reuse features across models.

## Example: setting up a Logistic Regression

Let's take a look at how we could use this, for instance using the [Logistic Regression algorithm](http://accord-framework.net/docs/html/T_Accord_Statistics_Models_Regression_LogisticRegression.htm) we mentioned earlier. Without going into details, a Logistic Regression is a model that takes inputs, and uses them to estimate a probability that something happens, assigning weights to each of the features. Whether this is the right model or not for our problem is besides the point - what I want is to show how one could go about using the setup described above to transform our training data and feed it into that particular algorithm.

First, we need to grab data; as it happens, the competition dataset is in CSV format, so we'll use the CSV Type Provider from `FSharp.Data` to retrieve it:

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
```

Nice and easy, we now have a `training` sample that is an `Example[]`. Next, we load up `Accord.Statistics`, and create a `Learner`:

``` fsharp
#r @"Accord/lib/net45/Accord.dll"
#r @"Accord.Math/lib/net45/Accord.Math.dll"
#r @"Accord.Statistics/lib/net45/Accord.Statistics.dll"

open Accord.Statistics.Models.Regression
open Accord.Statistics.Models.Regression.Fitting

let model = [|
    ``Search Terms characters``
    ``Matching characters between title and search terms``
    |]

let logisticModel : Learner = 
    function sample ->
        let inputsCount = model.Length
        let regression = LogisticRegression(inputsCount)
        let teacher = IterativeReweightedLeastSquares(regression)

        let labelNormalize x = (x - 1.) / 2.
        let labelDenormalize x = (x * 2.) + 1.

        let input,output = 
            sample
            |> Seq.map (fun (label,obs) -> 
                extractFeatures model obs, 
                labelNormalize label)
            |> Seq.toArray
            |> Array.unzip

        let rec learn () =
            let error = teacher.Run(input, output)
            if error < 0.01 
            then regression
            else learn ()

        let logPredictor = learn ()

        let predictor (obs:Observation) =
            obs
            |> extractFeatures model
            |> logPredictor.Compute
            |> labelDenormalize

        predictor 
```

Without going into details, we define what algorithm to use (a `LogisticRegression`), and prepare the data, extracting from the sample the input (by applying `extractFeatures`), and the output, which we normalize from [1;3] to [0;1]. We learn from the data, iterating until the error is sufficiently small, and create a `predictor` function, which takes an `Observation`, extracts its features, feeds it into the result of the logistic, and de-normalize the output. And we are done; we can now, for instance, learn from the entire training sample, and test out the predictions:

``` fsharp
let logisticPredictor = logisticModel training

training 
|> Seq.take 10 
|> Seq.map (fun (l,o) -> l,logisticPredictor o)
|> Seq.iter (fun (act,pred) -> 
    printfn "Actual: %.2f, Predicted: %.2f" act pred)
```

```
Actual: 3.00, Predicted: 2.38
Actual: 2.50, Predicted: 2.36
Actual: 3.00, Predicted: 2.44
Actual: 2.33, Predicted: 2.42
Actual: 2.67, Predicted: 2.50
Actual: 3.00, Predicted: 2.41
Actual: 2.67, Predicted: 2.40
Actual: 3.00, Predicted: 2.46
Actual: 2.67, Predicted: 2.51
Actual: 3.00, Predicted: 2.39
```

Are the results any good? That's a great question - one we will discuss in a later post. Our goal for now was to be able to iterate rapidly, creating new feature candidates, and run experiments with various combinations. This we achieved: right now, running a new experiment is as simple as creating a new feature, adding or removing features from the `model`, and running the script again. The only thing we have to focus on is creating and managing features, with the safety of static typing. Create an invalid feature, say, one that returns a `bool` or takes in something that isn't an `Observation`, and the script will complain loudly, refuse to be run, and tell you precisely what you broke.

This approach has become more or less my go-to structure lately, with some small modifications, which I will discuss next time, in the context of validation. Until then, I hope you found something interesting or useful in this!
