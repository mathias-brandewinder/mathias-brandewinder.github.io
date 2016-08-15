---
layout: post
title: Support Vector Machine in F#&#58; getting there
tags:
- F#
- Machine-Learning
- SVM
- Support-Vector-Machine
- Classification
- Character-Recognition
---

{% include ml-in-action-series.html %}

This is the continuation of my series converting the samples found in [Machine Learning in Action](http://www.manning.com/pharrington/) from Python to F#. After starting on a nice and steady pace, I hit a speed bump with Chapter 6, dedicated to the Support Vector Machine algorithm. The math is more involved than the previous algorithms, and the original Python implementation is very procedural , which both slowed down the conversion to a more functional style.

Anyways, I am now at a good point to share progress. The current version uses Sequential Minimization Optimization to train the classifier, and supports Kernels. Judging from my experiments, the algorithm works - what is missing at that point is some performance optimization.

I'll talk first about the code changes from the ["na&iuml;ve SVM"]({{ site.url }}/2012/11/25/Support-Vector-Machine-in-FSharp-work-in-progress/) version previously discussed, and then we'll illustrate the algorithm in action, recognizing hand-written digits.

## Main changes from previous version

From a functionality standpoint, the 2 main changes from the [previous post]({{ site.url }}/2012/11/25/Support-Vector-Machine-in-FSharp-work-in-progress/) are the replacement of the hard-coded vector dot product by arbitrary Kernel functions, and the modification of the algorithm from a na&iuml;ve loop to the SMO double-loop, pivoting on observations based on their prediction error.

You can browse the [current version of the SVM algorithm on GitHub here](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/blob/17235cb72f8608cd6c61e0b3087852eb939ad998/MachineLearningInAction/MachineLearningInAction/SupportVectorMachine.fs).

**Injecting arbitrary Kernels**

The code I presented last time relied on vector dot-product to partition linearly separable datasets. The obvious issue is that not all datasets are linearly separable. Fortunately, with minimal change, the SVM algorithm can be used to handle more complex situations, using what's known as the "[Kernel Trick](http://en.wikipedia.org/wiki/Kernel_trick)
". In essence, instead of working on the original data, we transform our data in a new space where it is linearly separable:

<iframe width="420" height="315" src="https://www.youtube.com/embed/3liCbRZPrZA" frameborder="0" allowfullscreen></iframe>

[via Cesar Souza](http://crsouza.com/)

<!--more-->

Thanks to the functional nature of F#, the algorithm modification is completely straightforward. Wherever we used the hardcoded vector dot-product before...

``` fsharp
// Product of vectors
let dot (vec1: float list) 
        (vec2: float list) =
    List.fold2 (fun acc v1 v2 -> 
        acc + v1 * v2) 0.0 vec1 vec2
``` 

... we substitute with an inner-product function of the appropriate signature:

``` fsharp
// A Kernel transforms 2 data points into a float
type Kernel = float list -> float list -> float
``` 

... which we can now explicitly inject in the algorithm, like this:

``` fsharp
let smo dataset labels (kernel: Kernel) parameters =
    ... do stuff here
``` 

This allows us to still support the linear case, by passing in the dot function as a Kernel - but also other more exotic Kernels, like the [Gaussian Radial Basis Function](http://en.wikipedia.org/wiki/Radial_basis_function), which we will see in action later, in the hand-written digits recognition part:

``` fsharp
// distance between vectors
let dist (vec1: float list) 
         (vec2: float list) =
    List.fold2 (fun acc v1 v2 -> 
        acc + (v1 - v2) ** 2.0) 0.0 vec1 vec2

// radial bias function
let rbf sig2 x = exp ( - x / sig2 )

// radial bias kernel
let radialBias sigma 
               (vec1: float list) 
               (vec2: float list) =
    rbf (sigma * sigma) (dist vec1 vec2)
``` 

Note that the radialBias function has 3 arguments, and the Kernel type expects two - when using that Kernel, you simply need to supply the sigma argument by currying:

``` fsharp
let rbfKernel = radialBias 10.0
``` 

... which now has the correct signature. Using a different Kernel would be as simple as creating a new function which has the proper signature, and passing it to the algorithm. First-class functions rule.

 **The SMO algorithm**

The "na&iuml;ve version" of the algorithm worked essentially this way:

* assign coefficients Alpha to each observation, 
* iterate over the observations, pick another random observation and attempt to "pivot" them, updating the Alpha coefficients for the selected pair while respecting some constraints, 
* until no Alpha updates are occurring for a while. 

By design, the Alpha coefficients stay between 0 and an upper value C, and once the algorithm finishes, observations with Alpha > 0, the "Support Vectors", are used to generate a separation boundary.

The SMO algorithm is largely similar, with two main differences:

* instead of picking a random pivot candidate, it uses a heuristic to select the candidate: from the unbounded candidates (where 0 < Alpha < C), it picks the candidate with the largest absolute error difference, 

* instead of a single-loop, it switches between full passes over the entire dataset, and passes over the unbounded candidates. 

At that point, I think the code in the **`smo`** function is decently readable, and conveys the "how" of the algorithm fairly well. I won't go into the "why", which would lead us way beyond a single post. I provided a list of resources at the end of the post, in case you want to understand the logic behind the algorithm better, including the original article by Platt.

Three final comments before moving to the fun part, using the algorithm on hand-written recognition.
First, I mentioned last time that I was bothered by the deeply-nested structure of the pivot code. The original Python code was performing multiple checks, and exiting the computation early if some conditions was or wasn't met. I resolved that issue by using a Maybe builder in the **`pivotPair`** function, which I lifted from [here](http://en.wikibooks.org/wiki/F_Sharp_Programming/Computation_Expressions) - and I really like the result.

Then, I reorganized a bit the code from the original. In Platt's pseudo code (and in the Python code from Machine Learning in Action), there are 2 key methods: `takeStep`, and `examineExample`. The pivot is performed by **`takeStep`**, and **`examineExample`** selects a suitable pivot - and calls **`takeStep`** to execute the pivot. I re-arranged a bit the code, so that these two steps are completely separate: **`identifyCandidate`**, given an observation, returns a pair of observations (or None), as well as the corresponding prediction error, and doesn't call **`pivotPair`**, which is called in a separate step and handles the alpha updates. In my opinion, this makes the algorithm workflow much clearer.

Finally, the code in the book uses some error caching, which I have not included in my version - because I actually don't understand how it is useful. I am under the impression that my current implementation avoids un-necessary error computations, but I may be missing something. If anyone spots an error, I'd love to hear about it! In the same vein, at that point, the algorithm seems to be behaving correctly (the file in [Chapter6.fsx](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/blob/17235cb72f8608cd6c61e0b3087852eb939ad998/MachineLearningInAction/MachineLearningInAction/Chapter6.fsx) illustrates it on a variety of test datasets), but can be very slow on larger datasets or specific parameters settings. I attempted to use memoization to cache some of the Kernel computations, which was a complete failure (I'll probably post more about that later), and will probably revisit the code for some tuning later (input welcome). In any case, you've been warned - this is not a fully optimized version (yet)!

## Illustration: recognizing hand-written digits

Enough talk - let's see some action: we'll use our SVM to perform some hand-writing recognition. The dataset we will use is the [Semeion dataset](http://archive.ics.uci.edu/ml/datasets/Semeion+Handwritten+Digit), which you can find on the [Machine Learning Repository of the University of California, Irvine](http://archive.ics.uci.edu/ml/index.html).

The dataset consists of 1593 scanned digits, written down by 80 people. Each scan is stored as 256 values (1 or 0), representing the 16x16 pixels of the scan, and 10 values (1 or 0), where 1 marks the digit that was written down (i.e. there should be 9 zeroes and 1 one).

You can browse the full script in [Chapter6-digits.fsx](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/blob/f5289cf18ad3f5f9e9e22205faebf9e4d6c3f7b8/MachineLearningInAction/MachineLearningInAction/Chapter6-digits.fsx) on GitHub.

First, we need to get the data from the UC Irvine website:

``` fsharp
#load "SupportVectorMachine.fs"

open System.IO
open System.Net
open MachineLearning.SupportVectorMachine

// retrieve data from UC Irvine Machine Learning repository
let url = "http://archive.ics.uci.edu/ml/machine-learning-databases/semeion/semeion.data"
let request = WebRequest.Create(url)
let response = request.GetResponse()

let stream = response.GetResponseStream()
let reader = new StreamReader(stream)
let data = reader.ReadToEnd()
reader.Close()
stream.Close()
``` 

We create a web request, and grab the result into data, which at that point contains a gigantic string - our dataset. We need to put it into the shape our algorithm expects, that is, an array of observations (each observation represented as a list of floats), and a matching array of labels. To do that, we need to break the data into lines, and parse each line into 256 numbers (our observations), and the label of the observation - like this:

``` fsharp
// a line in the dataset is 16 x 16 = 256 pixels,
// followed by 10 digits, 1 denoting the number
let parse (line: string) =
    let parsed = line.Split(' ') 
    let observation = 
        parsed
        |> Seq.take 256
        |> Seq.map (fun s -> (float)s)
        |> Seq.toList
    let label =
        parsed
        |> Seq.skip 256
        |> Seq.findIndex (fun e -> (int)e = 1)
    observation, label

// classifier: 7s vs. rest of the world
let dataset, labels = 
    data.Split((char)10)
    |> Array.filter (fun l -> l.Length > 0) // because of last line
    |> Array.map parse
    |> Array.map (fun (data, l) -> 
        data, if l = 7 then 1.0 else -1.0 )
    |> Array.unzip
``` 

The parse function splits a line according to whitespace, take the 256 first elements, and transform them to an list of floats (the "observation" part), and identifies what digit was scanned by finding the index/position marked "1" in the last block (a "2" is encoded for instance as 0 0 1 0 0 0 0 0 0 0: all positions are 0, except index 2).

Out of the box, the SVM classifier only separates between 2 classes. In this case, we'll arbitrarily try to recognize 7s. We process the string data, breaking it into an array split by line breaks (char 10), remove the last chunk (the file ends with an end line), apply our parse function to transform each line into a tuple observation/label, and reduce the labels into 1.0 for 7s, -1.0 otherwise - and finally unzip, exploding the array of tuples into 2 arrays, one containing observations, the other labels. Done!

Because I am a visual guy, I thought it would be nice to see how the original scans looked like, hence the render function:

``` fsharp
// renders a scanned digit as "ASCII-art"
let render observation =
    printfn " "
    List.iteri (fun i pix ->
        if i % 16 = 0 then printfn "" |> ignore
        if pix > 0.0 then printf "■" else printf " ") observation
``` 

This "reconstructs" the scan ASCII-style, drawing a square for 1s and nothing otherwise, and inserting a new line every 16 characters. Let's see it in action:

``` fsharp
> render dataset.[0];;
 

      ■■■■■■■■  
     ■■■■■■ ■■  
    ■■■■■■   ■■ 
   ■■■■■    ■■■■
   ■■■■ ■■■■■■■ 
   ■■■ ■■■■■ ■■ 
  ■■■■■■■■   ■■ 
  ■■■■■■    ■■  
 ■■■■■■     ■■  
 ■■■■       ■■  
 ■■■      ■■■   
■■■       ■■    
■■■■    ■■■■    
■■■■   ■■■      
■ ■■■■■■■       
   ■■■■         val it : unit = ()
``` 

``` fsharp
> render dataset.[140];;
 

  ■■■■■■■■■     
■■■■■■  ■■■     
■        ■■■    
         ■■■    
         ■■     
         ■■     
         ■■     
         ■■     
         ■■     
      ■■■■■     
       ■■■■■■■■■
        ■■■     
        ■■■     
        ■■■     
        ■■      
        ■■      val it : unit = ()
``` 

In case you are wondering, the first one is a 0, the second a 7. The 0 is pretty ugly - if you ask me, I wouldn't have been surprised to hear it was an 8. Let's see how the SVM deals with it.

``` fsharp
let parameters = { C = 5.0; Tolerance = 0.001; Depth = 20 }
let rbfKernel = radialBias 10.0

// split dataset into training vs. valiation
let sampleSize = 600
let trainingSet = dataset.[ 0 .. (sampleSize - 1)]
let trainingLbl = labels.[ 0 .. (sampleSize - 1)]
let validateSet = dataset.[ sampleSize .. ]
let validateLbl = labels.[ sampleSize .. ]

printfn "Training classifier"
let model = smo trainingSet trainingLbl rbfKernel parameters
let classify = classifier rbfKernel model
``` 

We set the search parameters and pick a radial basis kernel (more on parameters selection further), split the dataset into 600 observations for training, the rest for validation, using array slices - and start training the classifier.

*Note: the choice of 600 is largely random. I just selected a multiple of 200, because of the internal organization of the dataset, which has blocks of 20 times the same digit in a row. Taking multiples of 200 ensures every digit will be represented. Note also that the sample is heavily unbalanced, with only 10% of 7s.*

Given the nature of the algorithm, the time to complete the training step will vary. On my humble machine, I have seen it take typically 6 to 9 minutes - so give it a bit of time.

So this is nice but... how good is our classifier?

The proof of the pudding is in the eating, and of the classifier in the classifying, so let's see if we can gauge quality. One straightforward metric we can use here is the percentage properly recognized for each group. Let's do that:

``` fsharp
// Compute average correctly classified
let quality classifier sample =
    sample
    |> Array.map (fun (d, l) -> if (classifier d) * l > 0.0 then 1.0 else 0.0)
    |> Array.average
    |> printfn "Proportion correctly classified: %f"

// split dataset by label and compute quality for each group
let evaluate classifier (dataset, labels) =
    let group1, group2 =
        Array.zip dataset labels
        |> Array.partition (fun (d, l) -> l > 0.0)
    quality classifier group1
    quality classifier group2
``` 

**`quality`** takes a classifier and a sample. The **`classifier`** is a function that takes in a observation, and returns a float: if the result is greater than 0.0, the prediction is the group with label 1.0, otherwise it's the group labeled -1.0. The **`sample`** is an array of tuples - an observation, and its known label, 1.0 or  -1.0. **quality** computes the % properly classified by computing the prediction for each observation. If the prediction and label are of the same sign, their product is positive, and the prediction is correct: we map the correct predictions to 1.0, 0.0 otherwise  -  and the percentage properly classified is simply the average of these.

**`evaluate`** has the same structure, but first splits the data into 2 groups, separating by class. This is important, because computing the raw proportion on the entire sample could be highly misleading. For instance, imagine a classifier that predicts "not a 7" for every observation: that predictor would be correct 90% of the time, because 90% of the sample is in that class. On the other hand, splitting by class would show us that it gets 100% hits in one group, and 0% in the other, a much more informative diagnosis of our state of affairs!

We can now evaluate how the classifier does, on the training set, and on the validation set, the one we really care about. Here is what I got:

``` fsharp
// verify training sample classification
printfn "Classification in training set"
evaluate classify (trainingSet, trainingLbl)

// validate on remaining sample
printfn "Classification in validation set"
evaluate classify (validateSet, validateLbl);;

Classification in training set
Proportion correctly classified: 1.000000
Proportion correctly classified: 0.990741
Classification in validation set
Proportion correctly classified: 0.918367
Proportion correctly classified: 0.958659
Real: 00:00:03.500, CPU: 00:00:03.500, GC gen0: 1, gen1: 0, gen2: 0
``` 

Classification is excellent in the training set, which is reassuring, and pretty good on the validation set (92% of 7s properly recognized, and 96% for the rest of the world) - the classifier is obviously doing something right.

How did I come up with the parameter C = 5.0, and sigma = 10.0 for the radial basis kernel? Frankly, by poking around. In the end of the script, you'll find a block of code which iterates over various values for C and sigma:

``` fsharp
// calibration (Careful,takes a while)
for c in [ 0.1; 1.0; 10.0 ] do
    for s in [ 0.1; 1.0; 10.0 ] do
        let parameters = { C = c; Tolerance = 0.001; Depth = 10 }
        let rbfKernel = radialBias s
        // do evaluation stuff here
``` 

**Run this only if you have some time on your hands** - this tries out various combinations, and prints out some quality metrics for each setting, which helps determining what order of magnitude "works". I reduced Depth to 10, to limit the search time, but this is still fairly lengthy.

## Conclusion

That's it for now on the Support Vector Machine classification algorithm. Compared to the other classification algorithms I looked into so far, this one has been the hardest to convert, and I frankly can't wait to move on with my life and look into other algorithms!

I was very impressed by the results on the digits classification - there is something almost magical in seeing 200+ lines of F# and a function as simple as the radial basis function do a pretty good job at classifying fairly messy data.

I suspect the current code is not running as fast as it should, and has room for optimization. I actually tried out some avenues - for instance, I attempted memoizing the Kernel evaluations, but the results were worse than disappointing. If anyone sees some obvious improvements, or has comments on the code, I'd love to hear them! In the meanwhile, I'll start looking into other algorithms - and come back to this later.

## Resources / references

[http://www.manning.com/pharrington/](http://www.manning.com/pharrington/): Machine Learning in Action, the book where the original Python code comes from.

[github](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/tree/f5289cf18ad3f5f9e9e22205faebf9e4d6c3f7b8): current version of the code on GitHub.

[http://archive.ics.uci.edu/ml/datasets/Semeion+Handwritten+Digit](http://archive.ics.uci.edu/ml/datasets/Semeion+Handwritten+Digit): the Semeion dataset, a collection of 1600 scanned hand-written digits, from the wonderful Machine Learning dataset library of the University of California, Irvine repository.

[http://research.microsoft.com/pubs/69644/tr-98-14.pdf](http://research.microsoft.com/pubs/69644/tr-98-14.pdf): the original Platt article on training Support Vector Machines with Sequential Minimization Optimization. Fairly readable, the algorithm pseudo-code can be found on page 10.

[http://crsouza.blogspot.com.br/2010/04/kernel-support-vector-machines-for.html](http://crsouza.blogspot.com.br/2010/04/kernel-support-vector-machines-for.html#!/2010/04/kernel-support-vector-machines-for.html): a C# implementation of SVM, with great explanations by Cesar Souza, the author of [Accord.NET](https://code.google.com/p/accord/), which looks like a fairly complete ML library.

[http://pyml.sourceforge.net/doc/howto.pdf](http://pyml.sourceforge.net/doc/howto.pdf): a good discussion on SVMs from the PyML project (ML library in Python), how to use them and what the various parameters mean.

[http://en.wikibooks.org/wiki/F_Sharp_Programming/Computation_Expressions](http://en.wikibooks.org/wiki/F_Sharp_Programming/Computation_Expressions): a nice explanation on Computation Expressions in F#, where I shamelessly lifted the Maybe monad implementation from.

[The previous post also contains some relevant links]({{ site.url }}/2012/11/25/Support-Vector-Machine-in-FSharp-work-in-progress/).
