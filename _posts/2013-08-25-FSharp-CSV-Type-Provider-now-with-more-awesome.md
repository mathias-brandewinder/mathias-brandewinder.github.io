---
layout: post
title: CSV Type Provider, now with more awesome
tags:
- Type-Provider
- Kaggle
- Titanic
- Decision-Tree
- CSV
---

About a month ago, [FSharp.Data](http://fsharp.github.io/FSharp.Data/) released version 1.1.9, which contains some very nice improvements – you can find them listed on [Gustavo Guerra’s blog](http://blog.codebeside.org/blog/2013/07/21/fsharp-data-1-1-9-released/). I was particularly excited by the changes made to the CSV Type Provider, because they make my life digging through datasets even simpler, but couldn’t find the time to write about it, because of my recent [cross-country peregrinations]({{ site.url }}/2013/07/13/Summer-of-FSharp-Tour/).  

Now that I am back, let’s talk about why this update made me so happy, with a concrete example. My latest week-end project is an [F# implementation of Random Forests](http://www.clear-lines.com/blog/post/Random-Forest-classification-in-F-first-cut.aspx); as part of the process, I am trying out the algorithm on various datasets, to get a sense for potential performance problems, and dog-food my own API, the best way I know to quickly spot suckiness. 

One of the problems I ran into was the representation of missing values. Most datasets don’t come clean and ready to use – usually you’ll have a few records with missing data. I opted for what seemed the most straightforward representation in F#, and decided to represent every feature value as an `Option` – anything can either have `Some` value, or `None`. 

The original CSV Type Provider introduced a bit of friction there, because it inferred types “optimistically”: if the sample used contained only integers, it would create an integer, which is great in most cases, except when you want to be “pessimistic” (which is usually a safe world-view when setting expectations regarding data). 

The new-and-improved CSV Type Provider fixes that, and introduces a few niceties. Case in point: the [Kaggle Titanic dataset](http://www.kaggle.com/c/titanic-gettingStarted), which contains the Titanic’s passenger list. With the new version, extracting the data is as simple as this:

``` fsharp
type DataSet = CsvProvider<"titanic.csv", 
                           Schema="PassengerId=int, Pclass->Class, Parch->ParentsOrChildren, SibSp->SiblingsOrSpouse", 
                           SafeMode=true, 
                           PreferOptionals=true>

type Passenger = DataSet.Row
``` 

This is pretty awesome. In a couple of lines, just by passing in the path to my CSV file and some (optional) schema information, I get a Passenger type:

![All properties are optional]({{ site.url}}/2013-08-25-Titanic_thumb.png)

What’s neat here is that first, I immediately get a Passenger with properties – with the correct Optional types, thanks to `SafeMode` and `PreferOptional`. Then, notice in the Schema the `Pclass->Class, Parch->ParentsOrChildren, SibSp->SiblingsOrSpouse` bit? This renames “on the fly” the properties; instead of the pretty obscurely named **`Parch`** feature coming from the CSV file header, I get a nice and readable **`ParentsOrChildren`** property. The Type Provider even does a few more cool things, automagically; for instance, the feature “Survived”, which is encoded in the original dataset as 0 or 1, gets automatically converted to a boolean. Really nice.

And just like that, I can now use this CSV file, and send it to my (still very much in alpha version) Decision Tree classifier:

``` fsharp
// We read the training set into an array,
// defining the Label we want to classify on:
let training =
    use data = new DataSet()
    [| for passenger in data.Data -> 
        passenger.Survived |> Categorical, // the label
        passenger |]
// We define what features should be used:
let features = [|
    "Sex", (fun (x:Passenger) -> x.Sex |> Categorical);
    "Class", (fun x -> x.Class |> Categorical); |]
// We run the classifier...
let classifier, report = createID3Classifier training features { DefaultID3Config with DetailLevel = Verbose }
// ... and display the resulting tree:
report.Value.Pretty()
``` 

… which produces the following results in the F# Interactive window:

```
> titanicDemo();;
├ Sex = male
│   ├ Class = 3 → False
│   ├ Class = 1 → False
│   └ Class = 2 → False
└ Sex = female
   ├ Class = 3 → False
   ├ Class = 1 → True
   └ Class = 2 → True
val it : unit = ()
>
```

The morale of the story here is triple. First, it was a much better idea to be a rich lady on the Titanic, rather than a (poor) dude. Then, Type Providers are really awesome – in a couple of lines, we extracted from a CSV file a collection of Passengers, all of them statically typed, with all the benefits attached to that; in a way, this is the best of both worlds – access the data as easily as with a dynamic language, but with all the benefits of types. Finally, the F# community is just awesome – big thanks to [everyone who contributed to FSharp.Data](https://github.com/fsharp/FSharp.Data/graphs/contributors), and specifically to [@ovatsus](https://twitter.com/ovatsus) for the recent improvements to the CSV Type Provider!

*You can find the full [Titanic example here on GitHub](https://github.com/mathias-brandewinder/Charon/blob/1d18778e4390ff764b860de4d1ccc29a3adc1d37/Charon/Charon.Examples/Titanic.fsx)*
