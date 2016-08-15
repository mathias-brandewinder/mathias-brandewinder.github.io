---
layout: post
title: Naïve Bayes Classification
tags:
- F#
- Machine-Learning
- Classification
- Bayes
- Probability
- Regex
- StackOverflow
- StackExchange
- Text
- NLP
---

{% include ml-in-action-series.html %}

This is the continuation of my series exploring Machine Learning, converting the code samples of [Machine Learning in Action](http://www.manning.com/pharrington/) from Python to F# as I go through the book. Today's post covers Chapter 4, which is dedicated to Na&iuml;ve Bayes classification - and you can find the resulting code on [GitHub](https://github.com/mathias-brandewinder/Machine-Learning-In-Action).

*Disclaimer: I am new to Machine Learning, and claim no expertise on the topic. I am currently reading [Machine Learning in Action](http://www.manning.com/pharrington/), and thought it would be a good learning exercise to convert the book's samples from Python to F#.*

## The idea behind the Algorithm

The canonical application of Bayes na&iuml;ve classification is in text classification, where the goal is to identify to which pre-determined category a piece of text belongs to - for instance, is this email I just received spam, or ham ("valuable" email)?

The underlying idea is to use individual words present in the text as indications for what category it is most likely to belong to, using [Bayes Theorem](http://en.wikipedia.org/wiki/Bayes'_theorem), named after the cheerful-looking Reverend Bayes.

![Reverend Thomas Bayes]({{ site.url }}/assets/2012-08-18-Thomas_Bayes.gif)

Imagine that you received an email containing the words "Nigeria", "Prince", "Diamonds" and "Money". It is very likely that if you look into your spam folder, you'll find quite a few emails containing these words, whereas, unless you are in the business of importing diamonds from Nigeria and have some aristocratic family, your "normal" emails would rarely contain these words. They have a much higher frequency within the category "Spam" than within the Ham, which makes them a potential flag for undesired business ventures.

On the other hand, let's assume that you are a lucky person, and that typically, what you receive is Ham, with the occasional Spam bit. If you took a random email in your inbox, it is then much more likely that it belongs to the Ham category.

Bayes' Theorem combines these two pieces of information together, to determine the probability that a particular email belongs to the "Spam" category, if it contains the word "Nigeria":

```
P(is "Spam"|contains "Nigeria") = P(contains "Nigeria"|is "Spam") x P(is "Spam") / P(contains "Nigeria")
```

In other words, 2 factors should be taken into account when deciding whether an email containing "Nigeria" is spam: how over-represented is that word in Spam, and how likely is it that any email is spammy in the first place?

The algorithm is named "Na&iuml;ve", because it makes a simplifying assumption about the text, which turns out to be very convenient for computations purposes, namely that each word appears with a frequency which doesn't depend on other words. This is an unlikely assumption (the word "Diamond" is much more likely to be present in an email containing "Nigeria" than in your typical family-members discussion email).

We'll leave it at that on the concepts - I'll refer the reader who want to dig deeper to the book, or to this explanation of [text classification with Na&iuml;ve Bayes](http://nlp.stanford.edu/IR-book/html/htmledition/naive-bayes-text-classification-1.html).

## A simple F# implementation

For my first pass, I took a slightly different direction from the book, and decided to favor readability over performance. I assume that we are operating on a dataset organized as a sequence of text samples, each of them labeled by category, along these lines (example from the book "[Machine Learning in Action](http://www.manning.com/pharrington/)"):

*Note: the code presented here can be found [found on GitHub](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/commit/f632a5c74d1474531af8e0d15d97a9f7a55a1c97)*

``` fsharp
let dataset =
    [| ("Ham",  "My dog has flea problems help please");
       ("Spam", "Maybe not take him to dog park stupid");
       ("Ham",  "My dalmatian is so cute I love him");
       ("Spam", "Stop posting stupid worthless garbage");
       ("Ham",  "Mr Licks ate my steak how to stop him");
       ("Spam", "Quit buying worthless dog food stupid") |]
``` 

We will need to do some word counting to compute frequencies, so let's start with a few utility functions:

``` fsharp
open System
open System.Text.RegularExpressions

// Regular Expression matching full words, case insensitive.
let matchWords = new Regex(@"\w+", RegexOptions.IgnoreCase)

// Extract and count words from a string.
// http://stackoverflow.com/a/2159085/114519        
let wordsCount text =
    matchWords.Matches(text)
    |> Seq.cast<Match>
    |> Seq.groupBy (fun m -> m.Value)
    |> Seq.map (fun (value, groups) -> 
        value.ToLower(), (groups |> Seq.length))

// Extracts all words used in a string.
let vocabulary text =
    matchWords.Matches(text)
    |> Seq.cast<Match>
    |> Seq.map (fun m -> m.Value.ToLower())
    |> Seq.distinct

// Extracts all words used in a dataset;
// a Dataset is a sequence of "samples", 
// each sample has a label (the class), and text.
let extractWords dataset =
    dataset 
    |> Seq.map (fun sample -> vocabulary (snd sample))
    |> Seq.concat
    |> Seq.distinct

// "Tokenize" the dataset: break each text sample
// into words and how many times they are used.
let prepare dataset =
    dataset
    |> Seq.map (fun (label, sample) -> (label, wordsCount sample))
``` 

We use a Regular Expression, `\w+`, to match all words, in a case-insensitive way. **`wordCount`** extracts individual words and the number of times they occur, while **`vocabulary`** simply returns the words encountered. The **`prepare`** function takes a complete dataset, and transforms each text sample into a Tuple containing the original classification label, and a Sequence of Tuples containing all lower-cased words found and their count.

<!--more-->

In our introduction to the algorithm, we mentioned that one of the elements which determines the likelihood of a document belonging to a group is the relative frequency of words within each group. The book discusses two approaches, Set-of-Words and Bag-of-Words. Set-of-Words simply counts whether the word is present or absent in each piece of text; by contrast, Bag-of-Words counts all occurrences of the word in the dataset, and will give a greater weight to a word if it appears multiple times in a single sample document. Let...s write a few functions to support these two cases:

``` fsharp
// Set-of-Words Accumulator function: 
// state is the current count for each word so far, 
// sample the tokenized text.
// setFold increases the count by 1 if the word is 
// present in the sample.
let setFold state sample =
    state
    |> Seq.map (fun (token, count) -> 
        if Seq.exists (fun (t, c) -> t = token) sample 
        then (token, count + 1) 
        else (token, count))

// Bag-of-Words Accumulator function: 
// state is the current count for each word so far, 
// sample the tokenized text.
// setFold increases the count by the number of occurences
// of the word in the sample.
let bagFold state sample =
    state
    |> Seq.map (fun (token, count) -> 
        match Seq.tryFind (fun (t, c) -> t = token) sample with
        | Some((t, c)) -> (token, count + c) 
        | None ->         (token, count))

// Aggregate words frequency across the dataset,
// using the provided folder.
// (Supports setFold and bagFold)
let frequency folder dataset words =
    let init = words |> Seq.map (fun w -> (w, 1))
    dataset
    |> Seq.fold (fun state (label, sample) -> folder state sample) init

// Convenience functions for training the classifier
// using set-of-Words and bag-of-Words frequency.
let bagOfWords dataset words = frequency bagFold dataset words
let setOfWords dataset words = frequency setFold dataset words
``` 

The main action takes place in the **`frequency`** function, which iterates over every document in the dataset it is supplied, and applies a **`folder`** function to update the state, which counts the number of occurrences of  each of the words that have been passed in. Two versions of an acceptable folder function are defined, **`setFold`**, which increases the count of a word by 1 if it is present in the sample document, and **`bagFold`**, which increases the count by the number of times the word is used in the sample document. The **`bagOfWords`** and **`setOfWords`** functions are simply "convenience" functions, which we can use the following way:

``` fsharp
// Retrieve all words from the dataset
let tokens = extractWords dataset

// using the frequency functions
let spam = 
    dataset 
    |> Seq.filter (fun e -> fst e = "Spam") 
    |> prepare
let spamBag = bagOfWords spam tokens |> Seq.toList
``` 

... which produces the following:

``` fsharp
val tokens : seq<string>
val spam : seq<string * seq<string * int>>
val spamBag : (string * int) list =
  [("my", 1); ("dog", 3); ("has", 1); ("flea", 1); ("problems", 1);
   ("help", 1); ("please", 1); ("maybe", 2); ("not", 2); ("take", 2);
   ("him", 2); ("to", 2); ("park", 2); ("stupid", 4); ("dalmatian", 1);
   ("is", 1); ("so", 1); ("cute", 1); ("i", 1); ("love", 1); ("stop", 2);
   ("posting", 2); ("worthless", 3); ("garbage", 2); ("mr", 1); ("licks", 1);
   ("ate", 1); ("steak", 1); ("how", 1); ("quit", 2); ("buying", 2);
   ("food", 2)]
``` 

You may have noted something odd - the frequency function begins with an initial state of 1 for each word, and as a result, the frequencies are all off by one. This is not another case of the classic [computer science error](http://martinfowler.com/bliki/TwoHardThings.html); we do this is to avoid an issue: if a word is never present in a class, its count will be zero, and as a result (as we'll see later when computing classification), whenever that word is observed, the class will be deemed impossible. To mitigate this, every word is initialized with a count of 1 in each class, which preserves the general ranking of frequencies and avoids the issue. This seemed pretty smelly to me, but apparently [the approach has a name](http://en.wikipedia.org/wiki/Additive_smoothing), and if it's named after Laplace, I should probably not argue.

We are now ready to do some classification:

``` fsharp
// Converts 2 integers into a proportion.
let prop (count, total) = (float)count / (float)total

// Train based on a set of words and a dataset:
// the dataset is "tokenized", and broken down into
// one dataset per classification label.
// For each group, we compute:
// the proportion of the group relative to total,
// the probability of each word within the group.
let train frequency dataset words =
    let size = Seq.length dataset
    dataset
    |> prepare
    |> Seq.groupBy fst
    |> Seq.map (fun (label, data) -> 
        label, Seq.length data, frequency data words)
    |> Seq.map (fun (label, total, tokenCount) ->
        let totTokens = Seq.sumBy (fun t -> snd t) tokenCount
        label, 
        prop(total, size), 
        Seq.map (fun (token, count) -> 
            token, prop(count, totTokens)) tokenCount)

// Classifier function:
// the classifier is trained on the dataset,
// using the words and frequency folder supplied.
// A piece of text is classified by computing
// the "likelihood" it belongs to each possible label,
// by checking the presence and weight of each
// "classification word" in the tokenized text,
// and returning the highest scoring label.
// Probabilities are log-transformed to avoid underflow.
// See "Chapter4.fsx" for an illustration.
let classifier frequency dataset words text =
    let estimator = train frequency dataset words
    let tokenized = vocabulary text
    estimator
    |> Seq.map (fun (label, proba, tokens) ->
        label,
        tokens
        |> Seq.fold (fun p token -> 
            if Seq.exists (fun w -> w = fst token) tokenized 
            then p + log(snd token) 
            else p) (log proba))
    |> Seq.maxBy snd
    |> fst
``` 

**`prop`** is a utility function, to convert our integer word counts into float probabilities.

**`train`** is where the action begins. We take our dataset, break it by classification label, and for each group, we compute a 3-elements Tuple (a Truple?), with the Group class, the probability of the Group (how many documents in the group vs. total), and the probability of each word relative to each other within the group, based on the word count produced by the **`frequency`** function we pass in (setOfWords or bagOfWords).

**`classifier`** builds upon **`train`**; it applies the results of the training set to a piece of **`text`** to be classified. The text is broken into words, and we estimate how likely it is for that piece of text to belong to each class, by retrieving the probability of the class, and checking whether each of its words is present in the training set and retrieving its probability. Finally, we simply return the class with the highest likelihood.

In effect, we are computing for each class:

```
P(class) x P(word1 in class if word1 is observed in text) x P(word2 in class if word2 is observed in text) x ...
```

Because each Word probability could be very small, there is a risk of underflow, which is mitigated by applying a log transformation to all probabilities. It preserves the overall order of results, and because Log a x b = Log a + Log b, we can add together the results without risking a multiplicative underflow.

We are now ready to classify our test example!

``` fsharp
// Create 2 classifiers, using all the words found
let setClassifier = classifier setOfWords dataset tokens
let bagClassifier = classifier bagOfWords dataset tokens

let test1 = bagClassifier "what a stupid dog"
let test2 = setClassifier "my dog has flea should I stop going to the park"

// apply the set-of-words classifier 
// to all elements from the dataset,
// and retrieves actual and predicted labels
let setOfWordsTest =
    dataset
    |> Seq.map (fun t -> fst t, setClassifier (snd t))
    |> Seq.toList

// apply the bag-of-words classifier 
// to all elements from the dataset.
let bagOfWordsTest =
    dataset
    |> Seq.map (fun t -> fst t, bagClassifier (snd t))
    |> Seq.toList
``` 

... which produces the following:

``` fsharp
val test1 : string = "Spam"
val test2 : string = "Ham"
val setOfWordsTest : (string * string) list =
  [("Ham", "Ham"); ("Spam", "Spam"); ("Ham", "Ham"); ("Spam", "Spam");
   ("Ham", "Ham"); ("Spam", "Spam")]
val bagOfWordsTest : (string * string) list =
  [("Ham", "Ham"); ("Spam", "Spam"); ("Ham", "Ham"); ("Spam", "Spam");
   ("Ham", "Ham"); ("Spam", "Spam")]
``` 

The classification of the 2 test sentences is plausible, and using the 2 classifiers on the dataset itself also produces the correct results.

## Application: StackOverflow vs. Programmers

Let's try it out on a more realistic example. I have been a long-time fan of StackOverflow, and recall being somewhat confused at the time the sister site "Programmers" was introduced - I could never quite understand what questions belonged where, and it's still somewhat the case today. How about trying automatic classification based on the Title of Questions only?

One of the nice things about StackExchange is how it embraces openness  -  starting by making its own data available via the [StackExchange API](https://api.stackexchange.com/). You can query the various sites in a fairly flexible manner, and create filters to obtain the pieces of information you are interested in as Json.

My initial plan was to write a sample querying live data, but I ended up hitting the throttle limit while experimenting, which turned out to be quite an impediment, so I ended up fetching data from the questions page itself, filtering down the results to just the title of the question, and saving the results into text files containing Json results - with 4 files, 2 training sets (500 questions for each site) and 2 testing sets covering different time periods from the training sets (100 questions for each site).

*Note that this means we are only using one half of the Bayesian inference model - we are ignoring the fact that the proportion of questions arriving to StackOverflow is very likely different from Programmers. If we had a random sample of questions coming from each of the sites, based on their actual activity, and had to classify them, we would benefit from using priors based on the relative weights of each site.*

I then proceeded to create a small F# Console App, "ReverendStack", which has been added to the GitHub project, with the corresponding 4 data files. Rather than a lengthy explanation, I'll dump the resulting code with a few comments afterwards:

``` fsharp
open System
open System.IO
open MachineLearning.NaiveBayes
open Newtonsoft.Json
open Newtonsoft.Json.Linq

let main =

    let stackoverflow = "stackoverflow"
    let programmers = "programmers"

    let extractFromJson text =
        let json = JsonConvert.DeserializeObject<JObject>(text);
        let titles = 
            json.["items"] :?> JArray
            |> Seq.map (fun item -> item.["title"].ToString())
        titles

    let extractFromFile file = File.ReadAllText(file)

    let dataset = seq {
            yield! extractFromFile("StackOverflowTraining.txt") 
                |> extractFromJson 
                |> Seq.map (fun t -> stackoverflow, t)
            yield! extractFromFile("ProgrammersTraining.txt") 
                |> extractFromJson 
                |> Seq.map (fun t -> programmers, t)
        }

    printfn "Training the classifier"

    // http://www.textfixer.com/resources/common-english-words.txt
    let stopWords = "a,able,about,across,after,all,almost,also,am,among,an,and,any,are,as,at,be,because,been,but,by,can,cannot,could,dear,did,do,does,either,else,ever,every,for,from,get,got,had,has,have,he,her,hers,him,his,how,however,i,if,in,into,is,it,its,just,least,let,like,likely,may,me,might,most,must,my,neither,no,nor,not,of,off,often,on,only,or,other,our,own,rather,said,say,says,she,should,since,so,some,than,that,the,their,them,then,there,these,they,this,tis,to,too,twas,us,wants,was,we,were,what,when,where,which,while,who,whom,why,will,with,would,yet,you,your"
    let remove = stopWords.Split(',') |> Set.ofArray

    let words = 
        dataset
        |> extractWords
        |> Set.filter (fun w -> remove.Contains(w) |> not)

    // Visualize the training results:
    // what are the most significant words for each site?
    let training = train setOfWords dataset words
    training 
        |> Seq.iter (fun (label, prop, tokens) ->
            printfn "---------------" 
            printfn "Group: %s, proportion: %f" label prop
            tokens 
                |> Map.toSeq
                |> Seq.sortBy (fun (w, c) -> -c )
                |> Seq.take 50
                |> Seq.iter (fun (w, c) -> printfn "%s Proba: %f" w c))

    // create a classifier
    let classify = classifier setOfWords dataset words

    // Apply the classifier to 2 test samples
    let stackoverflowTest = seq {
            yield! extractFromFile("StackOverflowTest.txt") 
                |> extractFromJson 
                |> Seq.map (fun t -> stackoverflow, t)
        }
    
    let programmersTest = seq {
            yield! extractFromFile("ProgrammersTest.txt") 
                |> extractFromJson 
                |> Seq.map (fun t -> programmers, t)
        }

    printfn "Classifying StackOverflow sample"  
    stackoverflowTest 
        |> Seq.map (fun sample -> if (fst sample) = (classify (snd sample)) then 1.0 else 0.0)
        |> Seq.average
        |> printfn "Success rate: %f"

    printfn "Classifying Programmers sample"  
    programmersTest
        |> Seq.map (fun sample -> if (fst sample) = (classify (snd sample)) then 1.0 else 0.0)
        |> Seq.average
        |> printfn "Success rate: %f"


    Console.ReadKey()
``` 

The code references the NaiveBayes module, and uses the awesome [Json.Net](http://james.newtonking.com/projects/json-net.aspx) library to extract from each file a Sequence of strings, the titles of all the questions retrieved. I also used a list of common English stop words, highly common words which are considered "noise" in the classification, and which we remove from the classification tokens.

We use the **`train`** method on the dataset, which allows us to display what words the classification mechanism has extracted as significant for each group, and finally apply the classifier to each test sample, measuring the proportion of cases we got right.
A word of advice - do not try to run this using the initial, simple F# implementation for the Na&iuml;ve Bayes classifier - it's dog slow.

The main reason for this (I believe) is the poor choice of data structure in the NaiveBayes module. Storing words and word counts as Sequences of strings or `(String, int)` Tuples worked nicely for debugging and figuring out the program flow, but we pay a heavy performance price for it when we are checking whether a given string exists when using the classifier. This seems to be a perfect situation to use the F# `Set` and `Map` classes / modules, which are suited for fast access by key.

I won't go into the details of the rewrite, which was fairly straightforward - the result can be found [here on GitHub](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/commit/a8a4680e606d0181b3eac1b893dfb7b42a927db6). The result, while still not as fast as I would like it to be, is much faster than the original.

First things first, how well does the classifier do? Not too bad:

> Classifying StackOverflow sample      
> Success rate: 0.730000       
> Classifying Programmers sample       
> Success rate: 0.820000  

We get 73% correct results on StackOverflow, and 82% on Programmers. Given that we are not even looking into the content of the question, but just using the title, I think it's really not bad.

What are the top keywords for each site?

**StackOverflow top 10:**

```
using Proba: 0.006865    
file Proba: 0.005380     
c Proba: 0.004453     
39 Proba: 0.004267     
php Proba: 0.004267     
jquery Proba: 0.003896     
net Proba: 0.003711     
android Proba: 0.003525     
data Proba: 0.003525     
text Proba: 0.003525
```

**Programmers top 10:**

```
programming Proba: 0.007656    
39 Proba: 0.005550     
c Proba: 0.005359     
use Proba: 0.005359     
best Proba: 0.004402     
code Proba: 0.003828     
project Proba: 0.003828     
development Proba: 0.003636     
language Proba: 0.003636     
s Proba: 0.003636
```

I have no idea (yet) what the 39 is about, but otherwise this makes some sense - while most of the top words on StackOverflow pertain to a specific language or technology, the list on Programmers is much more general, with words like "development", "project", or "language". If you want to know the next words in the list... go check the code :)

## Conclusion

This is as far as I will go on the topic of Na&iuml;ve Bayes classification - I hope you found it interesting.

From a code standpoint, the resulting F# code was slightly more compact that Python (all in all, stripped from the comments, it...s less than 100 lines of code, with extra spacing for readability), and, in my opinion, also more expressive.

I was somewhat surprised by the poor initial performance, which in hindsight made total sense - the training set extracted about 2,000 words, and matching each of them against question titles using Sequences wasn't a great idea. What came as a good surprise was the refactoring to Set and Map. I expected it to be painful, but in the end I had to change signatures / code in only a dozen places or so. First, type inference saved me from changing types manually everywhere (just change a function, and follow the trail of build breaks until it builds again), and then, Set and Map are actually fairly similar to the types I was originally using in how they are used - they are just much more efficient at accessing data by keys, but otherwise they support essentially the same functions as what was originally in place.

I am still not 100% happy with the speed of the algorithm; the learning part seems pretty fast, but the classification of individual text pieces is still somewhat slow. I may revisit it later, but at that point it's good enough for my purposes!

As far as the algorithm itself goes, I have to confess mixed feelings. On one hand, it works pretty nicely - on the other hand, I spent a couple of days mulling over the fact that the probabilities involved are not very clearly defined. The evaluation of the "likelihood" of each class is certainly not a probability (if it were, then the probabilities across all classes should sum to 100%), and in a perfect Bayesian world, I would expect the computation to involve not only the presence of words, but also their absence. Stated differently, I am a bit unclear on what the underlying probability model for text generation is.

That's all I have for now - let me know if you have questions or comments, and our next stop will be Logistic Regression, with Chapter 5 of "[Machine Learning in Action](http://www.manning.com/pharrington/)".

## Resources

[Na&iuml;ve Bayes Text Classification](http://nlp.stanford.edu/IR-book/html/htmledition/naive-bayes-text-classification-1.html)  

[Simple implementation on GitHub](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/commit/f632a5c74d1474531af8e0d15d97a9f7a55a1c97)

[Set and Map based implementation on GitHub](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/commit/a8a4680e606d0181b3eac1b893dfb7b42a927db6)
