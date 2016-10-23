---
layout: post
title: Using the ALGLIB random forest with F#  
tags:
- F#
- Machine-Learning
- Random-Forest
- Regression
- Classification
- Tree
- Ensemble-Method
- ALGLIB
- Features
---

The intent of this post is primarily practical. During the Kaggle Home Depot competition, we ended up using the Random Forest implementation of [ALGLIB][1], which worked quite well for us. [Taylor Wood](https://twitter.com/squeekeeper) did all the work figuring out how to use it, and I wanted to document some of its aspects, as a reminder to myself, and to provide a starting point for others who might need a Random Forest from F#.

The other reason I wanted to do this is, I have been quite interested lately in the idea of developing a DSL to specify a machine learning model, which could be fed to various algorithms implementation via simple adapters. In that context, I thought taking a look at ALGLIB and how they approached data modelling could be useful.

I won't discuss the Random Forest algorithm itself; my goal here will be to "just use it". In order to do this, I will be using the [Titanic dataset][2] from the Kaggle "Learning From Disaster" competition. I like that dataset because it's not too big, but it hits many interesting problems: missing data, features of different types, ... I will be using it two ways, for classification (as is usually the case), but also for regression. 

Let's dive in the ALGLIB random forest. The library is available as a nuget package, [`alglibnet2`][3]. To use it, simply reference the assembly `#r @"alglibnet2/lib/alglibnet2.dll"`; you can then immediately train a random forest, using the `alglib.dfbuildrandomdecisionforest` method - no need to open any namespace. The training method comes in 2 flavors, [`alglib.dfbuildrandomdecisionforest`][4] and [`alglib.dfbuildrandomdecisionforestx1`][5]. The first one is a specialization of the second one, which takes an additional argument; therefore, I'll work on the second, most general version.

<!--more-->

## Signature of dfbuildrandomdecisionforestx1

The signature of `dfbuildrandomdecisionforestx1` is the following:

``` fsharp
let info,forest,report = 
    alglib.dfbuildrandomdecisionforestx1(
        trainingset, // training data
        samplesize, // how many observations
        features, // how many features/variables
        classes, // how many classes; 1 represents regression
        trees, // how many trees to build; recommended: 50 to 100
        featuresincluded, // how many features retained when splitting
        learningproportion // how much of the sample to use for each tree. Recommended: 0.05 (high noise) to 0.66 (low noise)
        )
```

We'll illustrate shortly how the inputs should be prepared. The function produces 3 outputs:  

* `info`: an integer return code. `1` signals success, `-2` or `-1` are supposed to signal issues (more on that in a second).  
* `forest`: a random forest (`alglib.decisionforest`), which can be used to produce predictions.  
* `report`: an `alglib.dfreport` that contains various quality metrics. 

## The Titanic dataset

The dataset (which you can [download from here]({{ site.url }}/assets/titanic.csv)) we will use comes as a CSV file, "titanic.csv", which contains the following columns:

Name | Type | Notes
--- | --- | ---
PassengerId | int | Unique ID for passenger
Survived | bool | survival, encoded as 0 (no) or 1 (yes)
Pclass | int | 1, 2 or 3 for 1st, 2nd and 3rd class
Name | string | name, title
Sex | string | "male" or "female"
Age | float | 
SibSp | int | number of siblings or spouses travelling together
Parch | int | number of parents or children travelling together
Ticket | string | ticket number/identifier
Fare | decimal | price paid for ticket
Cabin | string | cabin number/identifier
Embarked | string | Boarding port: S, C or Q for Southampton, Cherbourg or Queenstown

We consume the dataset using the [`fsharp.data` CSV Type Provider][6], in the simplest fashion:

``` fsharp
#r @"fsharp.data/lib/net40/fsharp.data.dll"
open FSharp.Data
type Titanic = CsvProvider<"titanic.csv">
type Passenger = Titanic.Row
let sample = Titanic.GetSample().Rows
```

## Setting up a regression

Let's start first with a regression. In this case, we will try to predict `Fare` - how much each passenger paid - using the data we have available.

The training set format is a bit unusual. ALGLIB expects a 2D array, where the first columns are the input variables `X`, and the last column is the value we are trying to predict, `Y`. 

We can for instance prepare a training set this way:

``` fsharp
let trainingset = 
    sample
    |> Seq.map (fun row ->
        [|
            // the inputs x
            row.Age
            float row.Parch
            float row.SibSp
            // the output y
            float row.Fare
        |])
    |> array2D
```

This will produce something like this:

``` fsharp
val trainingset : float [,] = [[22.0; 0.0; 1.0; 7.25]
                               [38.0; 0.0; 1.0; 71.2833]
                               [26.0; 0.0; 0.0; 7.925]
                               [35.0; 0.0; 1.0; 53.1]
                               [35.0; 0.0; 0.0; 8.05]
                               [nan; 0.0; 0.0; 8.4583]
                               [54.0; 0.0; 0.0; 51.8625]
```

> Note the presence of a `nan` ("Not a number") in row 6 - we have missing values.

We can now attempt to train a regression model:

``` fsharp
let samplesize = trainingset.GetUpperBound(0)
let features = 3
let classes = 1 // regression
let trees = 10
let featuresincluded = 2
let learningproportion = 0.50
    
let info,forest,report = 
    alglib.dfbuildrandomdecisionforestx1(
        trainingset,
        samplesize,
        features,
        classes,
        trees,
        featuresincluded,
        learningproportion
        )
```

Some points of note here:  

* `features` represents the number of columns that are input values  
* when set to `1`, `classes` indicates a regression  
* `trees` represents how many trees we want in the forest, that is, how deep / long we want to train. The documentation recommends 50 to 100. From experience, higher is possible, but an `OutOfMemoryException` is also a possibility :)   
* `featuresincluded`: this is the extra parameter from the other function available. It drives how many of the available features should be randomly selected at each split. This is done automatically in the other case.  
* `learningproportion`: this is a tuning parameter, the documentation recommends values between 0.05 (for very noisy datasets) and 0.66 (for clean datasets). This determines how much of the training set is used for each tree, and lower values should help prevent over-fitting.  

## Running the regression

Running the regression produces... well, on my machine, with the current setup, the computation never returns. If I change the `learningproportion` to 0.1 instead, I get this:

``` fsharp
alglib+alglibexception: Exception of type 'alglib+alglibexception' was thrown.
   at alglib.dforest.dfsplitr(Double[]& x, Double[]& y, Int32 n, Int32 flags, Int32& info, Double& threshold, Double& e, Double[]& sortrbuf, Double[]& sortrbuf2)
   // more stack trace from hell.
```

So much for using error codes. My experience with the library has been that if there is something wrong with the input, it will either explode or never return. Perhaps I am doing something wrong?

The 2 issues you may hit when preparing the data are:  

* invalid indexing: for instance, setting `samplesize` to a value larger than the sample size will result in `System.IndexOutOfRangeException: Index was outside the bounds of the array.`.  
* missing data / `nan`: this is the problem we are hitting here. The training set is expected to be a `float [,]`, but if it contains `nan` values, for either input or output, you'll run into problems.  

Let's address this, with a quick-and-dirty filter:

``` fsharp
open System 
let number x = not (Double.IsNaN x || Double.IsInfinity x)

let trainingset = 
    sample
    |> Seq.map (fun row ->
        [|
            // the inputs x
            row.Age
            float row.Parch
            float row.SibSp
            // the output y
            float row.Fare
        |])
    |> Seq.filter (fun row -> row |> Seq.forall (number))
    |> array2D

```

> Side-note: is there a more elegant way to check if a `float` is a "normal number"?

This eliminates every row that contains one or more invalid input, and `alglib.dfbuildrandomdecisionforestx1` runs like a champ now. The `info` flag is `1`, signaling success. The `report` results are as follows:

``` fsharp
> report;;
val it : alglib.dfreport =
  alglib+dfreport {avgce = 0.0;
                   avgerror = 20.11038675;
                   avgrelerror = 0.9471424989;
                   innerobj = alglib+dforest+dfreport;
                   oobavgce = 0.0;
                   oobavgerror = 29.25122031;
                   oobavgrelerror = 1.277852568;
                   oobrelclserror = 0.0;
                   oobrmserror = 57.16207433;
                   relclserror = 0.0;
                   rmserror = 39.4817227;}
``` 

You get the [expected metrics in the report][7] (average error, root mean square error, ...), in two flavors. The values prefixed with `oob` indicate out-of-bag, and I suspect the other ones are on data that has been used for training (that is, the complement of out-of-bag). I am not 100% sure about this one. In general, out-of-bag is the better indicator for what performance you should expect from your model when using it on new data points.

## Generating predictions

You can now use the `forest` to generate predictions, by calling [`alglib.dfprocess`][8]. `dfprocess` is expecting a forest, and a vector of input values, and will compute the output value. The output value is expected by reference, and is not a `float`, but a `float[]` (more on this when we discuss classification later). In our case, our model has 3 features / variables, so we should pass in a `float[]` of size 3.

``` fsharp
let mutable output = Array.empty<float>
let input = [| 30.0; 0.0; 1.0 |]
alglib.dfprocess(forest,input,&output)
printfn "Prediction: %A" output 
> 
Prediction: [|33.45812375|]
```

In other words, for a passenger that is 30 years old, travelling with 0 parents or children and 1 siblings or spouses, our model predicts that his ticket has cost him 33.45.

This is obviously a bit gross. [Taylor](https://twitter.com/squeekeeper) wrote a nice wrapper for this, making this process a bit more palatable:

``` fsharp
let predict (input:float[]) =
    let mutable result = Array.empty<float>
    alglib.dfprocess(forest, input, &result)
    result.[0]

predict [| 30.0; 0.0; 1.0 |]
> 
val it : float = 33.45812375
```

Interestingly, while training doesn't like missing values, it seems `dfprocess` deals with it quite well:

``` fsharp
predict [| Double.NaN; Double.NaN; Double.NaN |]
> 
val it : float = 183.445
```

I tried out a couple of variants (`predict [| 30.0; 0.0; Double.NaN |]`, `predict [| Double.NaN; 0.0; 1.0 |]`), and in each case got a different prediction. I assume ALGLIB is picking up the most likely value when the input is missing, but I don't know for sure what the algorithm is doing there.

## Categorical and Ordinal input

So far, we have used only input values that were numerical. However, one of the nice properties of random forests is that they are quite flexible, and can handle virtually any type of input.

Let's try to incorporate sex, and the port of embarkation - Southampton, Cherbourg or Queenstown. ALGLIB has a very good description of how they [encode variables][9]. Categorical (or, in their parlance, Nominal) variables are encoded either as:

* 0 or 1 for variables with 2 states,
* "1-of-N" for variables with 3 states or more.

So incorporating sex would simply entail adding a column with 0.0 or 1.0 values for either case, and encoding the port of embarkation would use a 3-state vector, `[1.0;0.0;0.0]` for Southampton, `[0.0;1.0;0.0]` for Cherbourg, and `[0.0;0.0;1.0]` for Queenstown.

This ignores the possibility of missing data, however. We can take 3 strategies here (as well as for numerical values):  

* we do not think missing data conveys useful information, and filter it out as we did,  
* we think missing value conveys useful information, in what case we can simply add another state. For instance, port of embarkation would take 4 states, the 4th one being "unknown port of embarkation", represented as `[0.0;0.0;0.0;1.0]`,  
* we can attempt to replace missing values by "reasonable ones". In general I tend to dislike making up data, but at the same time, in the case of a dataset where all rows contain mostly good data with some missing, we would end up discarding a lot of rows, which can be a problem.  

We could for instance model our data like this, without making any attempt at elegance:

``` fsharp
let trainingset = 
    sample
    |> Seq.map (fun row ->
        [|
            // the inputs x
            row.Age
            float row.Parch
            float row.SibSp
            // modelling a simple categorical,
            // discarding unknown / missing data
            (if row.Sex = "male" then 1.0 elif row.Sex = "female" then 0.0 else Double.NaN)
            // modelling a categorical with missing values
            (if row.Embarked = "S" then 1.0 else 0.0)
            (if row.Embarked = "C" then 1.0 else 0.0)
            (if row.Embarked = "Q" then 1.0 else 0.0)
            (if row.Embarked = "" then 1.0 else 0.0)
            // the output y
            float row.Fare
        |])
    |> Seq.filter (fun row -> row |> Seq.forall (number))
    |> array2D

let samplesize = trainingset.GetUpperBound(0)
let features = 8
let classes = 1 // regression
let trees = 10
let featuresincluded = 4
let learningproportion = 0.5
```

Note that we increased both `features` and `featuresincluded`.

> Side-note: an interesting point with the port of embarkation is that if we encountered not a missing value, but an unexpected one, the variable would be encoded as `[0.0;0.0;0.0;0.0]`.

Just for kicks, here is the report we get for that model:


``` fsharp
  alglib+dfreport {avgce = 0.0;
                   avgerror = 16.9561193;
                   avgrelerror = 0.80103117;
                   innerobj = alglib+dforest+dfreport;
                   oobavgce = 0.0;
                   oobavgerror = 27.7157343;
                   oobavgrelerror = 1.263475249;
                   oobrelclserror = 0.0;
                   oobrmserror = 56.29947845;
                   relclserror = 0.0;
                   rmserror = 33.70286595;}
```

The out-of-bag RMSE dropped from 57.16 to 56.29. Looks like these features are not very helpful...

One last thing worth considering is ordinal values. A good example on this dataset is Class. Class is not quite a numerical value (how far apart they are is meaningless), but the order matters: first class is (in some sense) greater than second, which itself is greater than third.

Both encodings - as a Categorical, or as a Numerical - are valid. One possible benefit of representing Class as Numerical is that it can implicitly create "groupings". Because 1 < 2 < 3, it would make sense to lump together "1 and 2" vs. "3", or "1" vs. "2 and 3", which is how continuous values are handled in a tree, dividing them by segments.

## Classification

Let's try now to use the random forest as a classifier. The only differences here are with the last column in the training set, which will now contain the "index" of the class, and the form of the output.

Let's begin with a classic exercise, and predict who survives on the Titanic.  

``` fsharp
let trainingset = 
    sample
    |> Seq.map (fun row ->
        [|
            // the inputs x
            row.Age
            float row.Parch
            float row.SibSp
            // modelling a simple categorical,
            // discarding unknown / missing data
            (if row.Sex = "male" then 1.0 elif row.Sex = "female" then 0.0 else Double.NaN)
            // modelling a categorical with missing values
            (if row.Embarked = "S" then 1.0 else 0.0)
            (if row.Embarked = "C" then 1.0 else 0.0)
            (if row.Embarked = "Q" then 1.0 else 0.0)
            (if row.Embarked = "" then 1.0 else 0.0)
            // the output y
            (if row.Survived then 1.0 else 0.0)
        |])
    |> Seq.filter (fun row -> row |> Seq.forall (number))
    |> array2D
```

We simply encode survival as 1.0 or 0.0; all we need to do then is change `classes` to 2 (we have 2 cases) and run the model:

``` fsharp
let samplesize = trainingset.GetUpperBound(0)
let features = 8
let classes = 2 // classification
let trees = 10
let featuresincluded = 4
let learningproportion = 0.5
    
let info,forest,report = 
    alglib.dfbuildrandomdecisionforestx1(
        trainingset, // training data
        samplesize, // how many observations
        features, // how many features/variables
        classes, // how many classes; 1 represents regression
        trees, // how many trees to build; recommended: 50 to 100
        featuresincluded, // how many features retained when splitting
        learningproportion // how much of the sample to use for each tree. Recommended: 0.05 (high noise) to 0.66 (low noise)
        )
```

What predictions do we get now?

``` fsharp
let mutable output = Array.empty<float>
let input = [| 30.0; 0.0; 1.0; 0.0; 1.0; 0.0; 0.0; 0.0 |]
alglib.dfprocess(forest,input,&output)
printfn "Prediction: %A" output 
> 
Prediction: [|0.7; 0.3|]
```

Instead of a bare-bones class prediction, we get a full probability distribution on the possible outcomes: 70% chances of not making it, and 30% of surviving. This is quite nice (for us, not for that hypothetical passenger, obviously).

Similarly, we could try, say, to predict the port of embarkation. In this case, we have 3 classes (Southampton, Cherbourg or Queenstown). Without any attempt at elegance, let's encode this, creating values 0, 1 and 2 for each case, and changing classes to 3:

``` fsharp
let trainingset = 
    sample
    |> Seq.map (fun row ->
        [|
            // the inputs x
            row.Age
            float row.Parch
            float row.SibSp
            // modelling a simple categorical,
            // discarding unknown / missing data
            (if row.Sex = "male" then 1.0 elif row.Sex = "female" then 0.0 else Double.NaN)
            // the output y
            (if row.Embarked = "S" then 0.0 
             elif row.Embarked = "C" then 1.0
             elif row.Embarked = "Q" then 2.0
             else Double.NaN)
        |])
    |> Seq.filter (fun row -> row |> Seq.forall (number))
    |> array2D

// note the NaNs

let samplesize = trainingset.GetUpperBound(0)
let features = 4
let classes = 3 // classification
let trees = 10
let featuresincluded = 2
let learningproportion = 0.5
```

If we now ask for predictions, for, say, a 30-years old male travelling without children or parents, with a spouse or sibling, we get:

``` fsharp
let mutable output = Array.empty<float>
let input = [| 30.0; 0.0; 1.0; 0.0 |]
alglib.dfprocess(forest,input,&output)
printfn "Prediction: %A" output 
> 
Prediction: [|0.4; 0.6; 0.0|]
```

That person most likely embarked in Cherbourg, with 60% chance, or in Southampton, with 40% chance.

> Note: if the classes do not match the number of cases in the last column, `alglib.dfbuildrandomdecisionforestx1` will return a flag of -2.

## Parting thoughts

In my opinion, in spite of some quirks, the ALGLIB random forest is quite nice, and potentially very useful. What I like about it is that it is a full-fledged random forest; this is an extremely versatile algorithm, which, in my experience, "always works". What I mean by that is, other algorithms will potentially give you better results - but a random forest is fast, easy to set up, and will produce decent predictions, and handle with minimal effort both regression and classification problems, incorporating data in all shapes and forms.

The quirky parts are around the API. I would have expected the function `alglib.dfbuildrandomdecisionforestx1` to always return, indicating with return codes if something went wrong. This is obviously not the case; I might be misunderstanding some aspects, and would love to hear from you if you know something about this. 

The way `alglib.dfprocess` uses `byref` to produce outputs is a bit unsettling, and some of the choices around the `alglib.dfbuildrandomdecisionforestx1` function signature are a bit odd to me. Why do I need to pass the size of the training set, when it can be computed from the data we are passing in? Similarly, why do I need to specify how many variables are used? The documentation hints at the possibility of having [more than one column for regression outputs](http://www.alglib.net/dataanalysis/generalprinciples.php#header0), but I had no success with that.

Still - these are details. I'll take the quirks, for a library that does what I want, and there are things I like about the modelling choices. Getting a full distribution on the possible classification outputs instead of a single prediction is nice; even though in both cases the most likely output is the same, it is quite different to know that the model thinks a particular outcome has a 99.9% chances of happening, vs. only 50.1%.

That's it - hope you got something out of this guided tour of the ALGLIB random forest.

[1]: http://www.alglib.net
[2]: https://www.kaggle.com/c/titanic
[3]: https://www.nuget.org/packages/alglibnet2/
[4]: http://www.alglib.net/translator/man/manual.csharp.html#sub_dfbuildrandomdecisionforest
[5]: http://www.alglib.net/translator/man/manual.csharp.html#sub_dfbuildrandomdecisionforestx1
[6]: http://fsharp.github.io/FSharp.Data/library/CsvProvider.html
[7]: http://www.alglib.net/translator/man/manual.csharp.html#struct_dfreport
[8]: http://www.alglib.net/translator/man/manual.csharp.html#sub_dfprocess
[9]: http://www.alglib.net/dataanalysis/generalprinciples.php#trnset
