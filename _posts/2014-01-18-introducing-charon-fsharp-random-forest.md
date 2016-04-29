---
layout: post
title: Version 0.1 of Charon, an F# Random Forest
tags:
- F#
- Machine-Learning
- Random-Forest
- Decision-Tree
- Classification
- Charon
---

A couple of months ago, I started working on an F# decision tree & random forest library, and pushed a first draft out in July 2013. It was a very minimal implementation, but it was a start, and my plan was to keep refining and add features. And then life happened: I got really busy, I began a very poorly disciplined refactoring effort on the code base, I second and third guessed my design - and got nothing to show for a while. Finally in December, I took some time off in Europe, disappeared in the French country side, a perfect setup to roll up my sleeves and finally get some serious coding done.

And here we go - drum roll please, version 0.1 of Charon is out. You can [find it on GitHub](http://mathias-brandewinder.github.io/Charon/), or install it as a [NuGet package](http://www.nuget.org/packages/Charon/).

<!--more-->

As you can guess from the version number, this is alpha-release grade code. There will be breaking changes, there are probably bugs and obvious things to improve, but I thought it was worth releasing, because it is in a shape good enough to illustrate the direction I am taking, and hopefully get some feedback from the community.

But first, what does Charon do? Charon is a [decision tree](http://en.wikipedia.org/wiki/Decision_tree_learning) and [random forest](http://en.wikipedia.org/wiki/Random_forest) machine learning classifier. An example will probably illustrate best what it does - let's work through the [classic Titanic example](http://www.kaggle.com/c/titanic-gettingStarted). Using the Titanic passenger list, we want to create a model that predicts whether a passenger is likely to survive the disaster – or meet a terrible fate. Here is how you would do that with Charon, in a couple of lines of F#.

First, we use the [CSV type provider](http://fsharp.github.io/FSharp.Data/library/CsvProvider.html) to extract passenger information from our data file:

``` fsharp
open Charon
open FSharp.Data
 
type DataSet = CsvProvider<"""C:\Users\Mathias\Documents\GitHub\Charon\Charon\Charon.Examples\titanic.csv""",
SafeMode=true, PreferOptionals=true>
 
type Passenger = DataSet.Row
```

In order to define a model, Charon needs two pieces of information: what is it you are trying to predict (the label, in that case, whether the passenger survives or not), and what information Charon is allowed to use to produce predictions (the features, in that case whatever passenger information we think is relevant):

``` fsharp
let training =
    use data = new DataSet()
    [| for passenger in data.Data ->
        passenger, // label source
        passenger |] // features source
 
let labels = "Survived", (fun (obs:Passenger) -> obs.Survived) |> Categorical
 
let features =
    [
        "Sex", (fun (o:Passenger) -> o.Sex) |> Categorical;
        "Class", (fun (o:Passenger) -> o.Pclass) |> Categorical;
        "Age", (fun (o:Passenger) -> o.Age) |> Numerical;
    ]
```

For each feature, we specify whether the feature is Categorical (a finite number of "states" is expected, for instance Sex) or Numerical (the feature is to be interpreted as a numeric value, such as Age).

The Model is now fully specified, and we can train it on our dataset, and retrieve the results:

``` fsharp
let results = basicTree training (labels,features) { DefaultSettings with Holdout = 0.1 }
 
printfn "Quality, training: %.3f" (results.TrainingQuality |> Option.get)
printfn "Quality, holdout: %.3f" (results.HoldoutQuality |> Option.get)
 
printfn "Tree:"
printfn "%s" (results.Pretty)
```

… which generates the following output:

```
Quality, training: 0.796 
Quality, holdout: 0.747 
Tree: 
├ Sex = male 
│   ├ Class = 3 → Survived False 
│   ├ Class = 1 → Survived False 
│   └ Class = 2 
│      ├ Age = <= 16.000 → Survived True 
│      └ Age = >  16.000 → Survived False 
└ Sex = female 
   ├ Class = 3 → Survived False 
   ├ Class = 1 → Survived True 
   └ Class = 2 → Survived True
```

Charon automatically figures out what features are most informative, and organizes them into a tree; in our example, it appears that being a lady was a much better idea than being a guy – and being a rich lady traveling first or second class an even better idea. Charon also automatically breaks down continuous variables into bins. For instance, second-class male passengers under 16 had apparently much better odds of surviving than other male passengers. Charon splits the sample into training and validation; in this example, while our model appears quite good on the training set, with nearly 80% correct calls, the performance on the validation set is much weaker, with under 75% correctly predicted, suggesting an over-fitting issue.

I won’t demonstrate the Random Forest here; the API is basically the same, with better results but less human-friendly output. While formal documentation is lacking for the moment, you can find code samples in the Charon.Examples project that illustrate usage on the [Titanic](https://github.com/mathias-brandewinder/Charon/blob/1188e24e312069e4a4e19199342ae9db5e5456d0/Charon/Charon.Examples/Titanic.fsx) and the [Nursery](https://github.com/mathias-brandewinder/Charon/blob/1188e24e312069e4a4e19199342ae9db5e5456d0/Charon/Charon.Examples/Nursery.fsx) datasets.

What I hope I conveyed with this small example is the design priorities for Charon: a lightweight API that permits quick iterations to experiment with features and refine a model, using the F# Interactive capabilities.

I will likely discuss in later posts some of the challenges I ran into while implementing support for continuous variables – I learnt a lot in the process. I will leave it at that for today – in the meanwhile, I would love to get feedback on the current direction, and what you may like or hate about it. If you have comments, feel free to hit me up on Twitter, or to open an Issue on GitHub!
