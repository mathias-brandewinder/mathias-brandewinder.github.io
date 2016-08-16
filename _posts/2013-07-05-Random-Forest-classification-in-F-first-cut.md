---
layout: post
title: Random Forest classification in F#&#58; first cut
tags:
- F#
- Machine-Learning
- Decision-Tree
- Random-Forest
- Classification
- Titanic
---

Besides having one of the coolest names around, Random Forest is an interesting machine learning algorithm, for a few reasons. It is applicable to a large range of classification problems, isn’t prone to over-fitting, can produce good quality metrics as a side-effect of the training process itself, and is very suitable for parallelization. For all these reasons, I thought it would be interesting to try it out in F#.  

**The current implementation I will be discussing below works, but isn’t production ready** (yet) – it is work in progress. The API and implementation are very likely to change over the next few weeks. Still, I thought I would share what I did so far, and maybe get some feedback! 

## The idea behind the algorithm 

As the name suggests, Random Forest (introduced in the early 2000s by Leo Breiman) can be viewed as an extension of [Decision Trees]({{ site.url }} /2012/08/05/Decision-Tree-classification/), which I discussed before. A decision tree grows a single classifier, in a top-down manner: the algorithm recursively selects the feature which is the most informative, partitions the data according to the outcomes of that feature, and repeats the process until no information can be gained by partitioning further. On a non-technical level, the algorithm is playing a smart “[game of 20 questions](https://en.wikipedia.org/wiki/Twenty_Questions)”: given what has been deduced so far, it picks from the available features the one that is most likely to lead to a more certain answer. 

How is a Random Forest different from a Decision Tree? The first difference is that instead of growing a single decision tree, the algorithm will create a “forest” – a collection of Decision Trees; the final decision of the classifier will be the majority decision of all trees in the forest. However, having multiple times the same tree wouldn’t be of much help, because we would get the same classifier repeated over and over again. This is where the algorithm gets interesting: instead of growing a Tree using the entire training set and features, it introduces two sources of randomness:  

* each tree is grown on a new sample, created by randomly sampling the original dataset with replacement (“[bagging](http://en.wikipedia.org/wiki/Bootstrap_aggregating)”),  
* at each node of the tree, only a random subset of the remaining features is used. 

<!--more-->

Why would introducing randomness be a good idea? It has a few interesting benefits:  

* by selecting different samples, it mitigates the risk of over-fitting. A single tree will produce an excellent fit on the particular dataset that was used to train it, but this doesn’t guarantee that the result will generalize to other sets. Training multiple trees on random samples creates a more robust overall classifier, which will by construction handle a “wider” range of situations than a single dataset,  
* by selecting a random subset of features, it mitigates the risks of greedily picking locally optimal features that could be overall sub-optimal. As a bonus, it also allows a computation speed-up for each tree, because fewer features need to be considered at each step,  
* the bagging process, by construction, creates for each tree a Training Set (the selected examples) and a Cross-Validation Set (what’s “out-of-the-bag”), which can be directly used to produce quality metrics on how the classifier may perform in general. 

## Usage 

Before delving into the current implementation, I thought it would be interesting to illustrate on an example the intended usage. I will be using the Titanic dataset, from the [Kaggle Titanic contest](http://www.kaggle.com/c/titanic-gettingStarted). The goal of the exercise is simple: given the passengers list of the Titanic, and what happened to them, can you build a model to predict who sinks or swims? 

I didn’t think the state of affairs warranted a Nuget package just yet, so this example is implemented as a script, in the [Titanic branch of the project itself on GitHub](https://github.com/mathias-brandewinder/Charon/blob/9b8f662b0ef42eee2a4dbdd93cf33cf8ce82fe02/Charon/Charon/TitanicDemo.fsx). 

First, let’s create a Record type to represent passengers:

``` fsharp
type Passenger = {
    Id: string; 
    Class: string;
    Name: string;
    Sex: string;
    Age: string;
    SiblingsOrSpouse: string;
    ParentsOrChildren: string;
    Ticket: string;
    Fare: string;
    Cabin: string;
    Embarked: string }
``` 

Note that all the properties are represented as strings; it might be better to represent them for what they are (Age is a float, SiblingsOrSpouse an integer…) – but given that the dataset contains missing data, this would require dealing with that issue, perhaps using an Option type. We’ll dodge the problem for now, and opt for a stringly-typed representation.

Next, we need to construct a training set from the Kaggle data file. We’ll use the CSV parser that comes with [FSharp.Data](http://fsharp.github.io/FSharp.Data/library/CsvFile.html) to extract the passengers from that list, as well as their known fate (the file is assumed to have been downloaded on your local machine first):

``` fsharp
let path = @"C:\Users\Mathias\Documents\GitHub\Charon\Charon\Charon\train.csv"
let data = CsvFile.Load(path).Cache()

let trainingSet =
    [| for line in data.Data -> 
        line.GetColumn "Survived" |> Some, // the label
        {   Id = line.GetColumn "PassengerId"; 
            Class = line.GetColumn "Pclass";
            Name = line.GetColumn "Name";
            Sex = line.GetColumn "Sex";
            Age = line.GetColumn "Age";
            SiblingsOrSpouse = line.GetColumn "SibSp";
            ParentsOrChildren = line.GetColumn "Parch";
            Ticket = line.GetColumn "Ticket";
            Fare =line.GetColumn "Fare";
            Cabin = line.GetColumn "Cabin";
            Embarked = line.GetColumn "Embarked" } |]
``` 

Now that we have data, we can get to work, and define a model. We’ll start first with a regular Decision Tree, and extract only one feature, Sex:

``` fsharp
let features = 
    [| (fun x -> x.Sex |> StringCategory); |]

``` 

What this is doing is defining an Array of features, a feature being a function which takes in a Passenger, and returns an Option string, via the utility StringCategory. StringCategory simply expects a string, and transforms a null or empty case into the “missing data” case, and otherwise treats the string as a Category. So in that case, x is a passenger, and if no Sex information is found, it will transform it into None, and otherwise into Some(“male”) or Some(“female”), the two cases that exist in the dataset.

We are now ready to go – we can run the algorithm and get a Decision Tree classifier, with a minimum leaf of 5 elements (i.e. we stop partitioning if we have less than 5 elements left):

``` fsharp
let minLeaf = 5
let classifier = createID3Classifier trainingSet features minLeaf
``` 

… and we are done. How good is our classifier? Let’s check:

``` fsharp
let correct = 
    trainingSet
    |> Array.averageBy (fun (label, obs) -> 
        if label = Some(classifier obs) then 1. else 0.)
printfn "Correct: %.4f" correct
``` 

We take our training set, and for each passenger, we compare the result of the classifier (classifier obs) with the known label, count the correctly classified cases, and compute the proportion we got right. Running this in FSI produces the following:

```
val correct : float = 0.7867564534
```

78.6% correct calls – not too bad. Is this any good? Let’s check, and compute the same thing with no feature selected, which will return the “naïve” prediction we would make if we knew nothing about the passengers:

``` fsharp
let features = [| |]
``` 

This time, we get only 61.6% correct calls – adding the Sex feature to our model is clearly beneficial, and improved our predictions quite a bit.

Let’s see if adding a few more features helps. This time, we’ll use Sex, Class, and Age. The tricky part here is that Age is a float, which can take many different values. Using it as a Category as-is isn’t a good idea, because we would  have way too many categories – we need to discretize it. Somewhat arbitrarily, we’ll create a cut-off between 10 years old (kids), versus older (adults):

``` fsharp
let binnedAge (age: string) =
    let result, value = Double.TryParse(age)
    if result = false then None
    else
        if value < 10. 
        then Some("Kid") 
        else Some("Adult")
``` 

We can now add our expanded features and create a new model:

``` fsharp
let features = 
    [| (fun x -> x.Sex |> StringCategory);
       (fun x -> x.Class |> StringCategory);
       (fun x -> x.Age |> binnedAge); |]
``` 

Is our new model any better? Let’s run it – we now get 81.0% correctly classified.

So far, we have been using a classic decision tree – let’s crank it up a notch, and use a Random Forest, with more features crammed in, because why not:

``` fsharp
let features = 
    [| (fun x -> x.Sex |> StringCategory);
       (fun x -> x.Class |> StringCategory);
       (fun x -> x.Age |> binnedAge);
       (fun x -> x.SiblingsOrSpouse |> StringCategory);
       (fun x -> x.ParentsOrChildren |> StringCategory);
       (fun x -> x.Embarked |> StringCategory); |]

let minLeaf = 5 // min observations per leaf
let bagging = 0.75 // proportion of sample used for estimation
let iters = 50 // number of trees to grow
let rng = Random(42) // random number generator
let forest = createForestClassifier trainingSet features minLeaf bagging iters rng
            
let correct = 
    trainingSet
    |> Array.averageBy (fun (label, obs) -> 
        if label = Some(forest obs) then 1. else 0.)
printfn "Correct: %.4f" correct
``` 

… and we go up to 85.1% correctly classified, with very little code. The main differences between the Decision Tree and the Random Forest are a few extra arguments: the proportion of elements we use in a bag (we construct samples containing 75% of the original sample), the number of trees to grow (50), and a Random number generator (which we seed to an arbitrary value so that we can replicate results).

*Note: if you run the same features in a Decision Tree, you will observe an even better prediction accuracy; this doesn’t necessarily mean that the Decision Tree is better than the Random Forest; at that point, the model is probably already over-fitting.*

And that’s pretty much it. My primary goal was to provide a flexible and lightweight API to define features, and play around with models. I plan on improving on this (see “what’s next” below), but I would love some feedback and comments on the approach! 

## Under the hood

Now for a few quick comments on the current implementation. I decided to try out a data structure which might not be the most obvious; I may end up doing something different, but I thought I would discuss it a bit.

The obvious way to approach the recursive partitioning of the training set goes along these lines: starting with an original dataset like this one...

Sex | Age | Result   
--- | --- | ---
male | kid | survive
male | adult | die
female | kid | survive
female | adult | survive
female | adult | die

… if we decide to partition on Sex, we’ll split into 2 datasets, removing the feature that was used:

[male group]

Age | Result  
--- | ---
kid | survive
adult | die

[female group]

Age | Result  
--- | --- |
kid | survive
adult | survive
adult | die

… and repeat the process recursively on each reduced dataset, until there is nothing to do.

Instead of going that route, I went a different direction. My thinking was that the core of the algorithm revolves around computing entropy, which boils down to identifying how many distinct cases exist, and counting how many instances of each there is. So I transformed the dataset in an alternate representation, centered on features, storing for each category present in the feature the indices of the observations that fall in that category. In our current example, the dataset would be transformed as:

Feature 1 (Sex)

* “male”: [ 0; 1; 2 ]  
* “female”: [ 3; 4 ]  

Feature 2 (Age)

* “kid”: [ 0; 2 ]  
* “adult”: [ 1; 3; 4 ]  

Labels

* “survive”: [ 0; 2; 3 ]  
* “die”: [ 1; 4 ]  

The advantage is that when features are in that form, computing entropy is fast, and very little information needs to be passed around in the recursive partitioning – only the indexes matter. So if I decided to partition on Sex, I would just need to pass down the “male” indexes [ 0; 1; 2 ] and “female” indexes [ 3; 4 ]. The group “male” is now simply the indexes [ 0; 1; 2 ], and computing the labels entropy for that group boils down to computing the intersection of these indexes with the Labels, which now become:

Labels

* “survive”: [ 0; 2; ] (that is, [ 0; 1; 2 ] ∩ [ 0; 2; 3 ])  
* “die”: [ 1 ] (that is, [ 0; 1; 2 ] ∩ [ 1; 4 ])  

An interesting side-effect (at least from my perspective) was that this approach made the extension from Decision Tree to Random Forest rather trivial; essentially, where I passed in the entire list of indexes to grow a Decision Tree (using all the observations for training), I just had to randomly select indexes with repetition to implement bagging.

The drawback is that what I gained comes at a cost – computing intersections needs to be fast, and I am performing intersections which would not be needed if I had partitioned the entire dataset in the first place. My sense so far has been that this approach seems pretty efficient for “thin” datasets, with a moderate number of features, but may start becoming a bad idea for “wide” datasets. I’ll keep playing with it, and tune it; I suspect that in the end, the right approach might be to handle different dataset shapes differently. In any case, this has no implications to the outer API – just performance implications.

## What’s next

Besides tuning for performance, there are a few obvious things I still need to work on.

Numeric values: to an extent, the current implementation can handle numeric values, as long as you pre-discretize them along the lines of what we did for the Age variable. However, this is tedious, and, in the case of the Random Forest, it is desirable to perform the discretization at each node, based on the current subset of the training sample under consideration. I plan on using the [Minimum Description Length]({{ site.url }}/2013/05/26/Discretizing-a-continuous-variable-using-Entropy/) approach describe in a previous post for that, but this will also require a change in how I store the variables themselves – because for continuous variables, it won’t be possible to decide upfront what the discrete categories are.

The current output is as raw as it gets – providing something besides the classifier would be nice. At a minimum, I plan to add a visualization of the decision tree, and Out-of-the-bag metrics for the Random Forest.

Besides that, I would like to provide a clean way to handle categorical features that are not strings. I went back and forth quite a bit on how to handle missing values, and I think the current approach, which forces features to be options, with None representing missing values, works pretty well. It is reasonably lightweight, and elicits a clear definition of what a missing value is. At the same time, an Observation with an Integer property and no missing value currently requires a conversion to a string Option, which works but seems heavy handed. At a minimum, I’ll need to work on some more utility functions along the lines of StringCategory, to keep the easy situations easy.

In any case, I have had lots of fun with this project so far. Comments, questions, criticisms? I’d love to hear them!

## References

[Leo Breiman and Adele Cutler’s Random Forest page](http://www.stat.berkeley.edu/~breiman/RandomForests/cc_home.htm)

[Demo script on GitHub](https://github.com/mathias-brandewinder/Charon/blob/9b8f662b0ef42eee2a4dbdd93cf33cf8ce82fe02/Charon/Charon/TitanicDemo.fsx)
