---
layout: post
title: Discretizing a continuous variable using Entropy
tags:
- Entropy
- Machine-Learning
- F#
- Discretization
- Decision-Tree
---

I got interested in the following question lately: given a data set of examples with some continuous-valued features and discrete classes, what’s a good way to reduce the continuous features into a set of discrete values? 

What makes this question interesting? One very specific reason is that some machine learning algorithms, like [Decision Trees]({{ site.url }}/2012/08/05/Decision-Tree-classification/), require discrete features. As a result, potentially informative data has to be discarded. For example, consider the [Titanic dataset](http://www.kaggle.com/c/titanic-gettingStarted): we know the age of passengers of the Titanic, or how much they paid for their ticket. To use these features, we would need to reduce them to a set of states, like “Old/Young” or “Cheap/Medium/Expensive” – but how can we determine what states are appropriate, and what values separate them? 

More generally, it’s easier to reason about a handful of cases than a continuous variable – and it’s also more convenient computationally to represent information as a finite set states. 

So how could we go about identifying a reasonable way to partition a continuous variable into a handful of informative, representative states? 

<!--more-->

In the context of a classification problem, what we are interested in is whether the states provide information with respect to the Classes we are trying to recognize. As far as I can tell from my cursory review of what’s out there, the main approaches use either [Chi-Square tests](http://en.wikipedia.org/wiki/Pearson%27s_chi-squared_test) or [Entropy](http://en.wikipedia.org/wiki/Entropy_(information_theory)) to achieve that goal. I’ll leave aside Chi-Square based approaches for today, and look into the Recursive Minimal Entropy Partitioning algorithm proposed by Fayyad & Irani in 1993. 

## The algorithm idea 

The algorithm hinges on two key ideas:  

* Data should be split into intervals that maximize the information, measured by Entropy,  
* Partitioning should not be too fine-grained, to avoid over-fitting. 

The first part is classic: given a data set, split in two halves, based on whether the continuous value is above or below the “splitting value”, and compute the [gain in entropy](http://en.wikipedia.org/wiki/Information_gain_in_decision_trees). Out of all possibly splitting values, take the one that generates the best gain – and repeat in a recursive fashion. 

Let’s illustrate on an artificial example – our output can take 2 values, Yes or No, and we have one continuous-valued feature: 

Continuous Feature	| Output Class
--- | ---
1.0	| Yes
1.0	| Yes
2.0	| No
3.0	| Yes
3.0	| No

As is, the dataset has an Entropy of H = - 0.6 x Log (0.6) – 0.4 x Log (0.4) = 0.67 (5 examples, with 3/5 Yes, and 2/5 No). 

The Continuous Feature takes 3 values: 1.0, 2.0 and 3.0, which leaves us with 2 possible splits: strictly less than 2, or strictly less than 3. Suppose we split on 2.0 – we would get 2 groups. Group 1 contains Examples where the Feature is less than 2: 

Continuous Feature	| Output Class
--- | ---
1.0	| Yes
1.0	| Yes

The Entropy of Group 1 is H(g1) = - 1.0 x Log(1.0) = 0.0 
Group 2 contains the rest of the examples: 

Continuous Feature | Output Class
--- | ---
2.0 | No
3.0 | Yes
3.0 | No

The Entropy of Group 2 is H(g2) = - 0.33 x Log(0.33) – 0.66 x Log(0.66) = 0.63  

Partitioning on 2.0 gives us a gain of H – 2/5 x H(g1) – 3/5 x H(g2) = 0.67 – 0.4 x 0.0 – 0.6 x 0.63 = 0.04. That split gives us additional information on the output, which seems intuitively correct, as one of the groups is now formed purely of “Yes”. In a similar fashion, we can compute the information gain of splitting around the other possible value, 3.0, which would give us a gain of 0.67 – 0.6 x 0.63 – 0.4 x 0.69 =  - 0.00: that split doesn’t improve information, so we would use the first split (or, if we had multiple splits with positive gain, we would take the split leading to the largest gain). 

So why not just recursively apply that procedure, and split our dataset until we cannot achieve information gain by splitting further? The issue is that we might end up with an artificially fine-grained partition, over-fitting the data. 

As an illustration, consider the following contrived example: 

Continuous Feature | Output Class
--- | ---
1.0 | Yes
2.0 | No
3.0 | Yes
4.0 | No

From a “human perspective”, the Continuous Feature looks fairly uninformative. However, if we apply our recursive split, we’ll end up doing something like this (hope the notation is understandable): 

```
[ 1.0; 2.0; 3.0; 4.0 ] –> 
[ 1.0 ], [ 2.0; 3.0; 4.0 ]  –>  
[ 1.0 ], [ 2.0 ], [ 3.0 ; 4.0 ] –> 
[ 1.0 ], [ 2.0 ], [ 3.0 ], [ 4.0 ]. 
```

At every step, extracting a single Example increases our information, and the final result  has a clear over-fitting problem, with each Example forming its own group. 

To address this issue, we need a “compensating force”, to penalize the formation of blocks that are too small. For that purpose, the algorithm uses a criterion based on the [Minimum Description Length](http://en.wikipedia.org/wiki/Minimum_description_length) principle (MDL). From what I gather, conceptually, the MDL principle *“basically says you should pick the model which gives you the most compact description of the data, including the description of the model itself”* [[source](http://vserver1.cscs.lsa.umich.edu/~crshalizi/notabene/mdl.html)]. In this case, our model is pretty terrible, because to represent the data, we end up using all of the data itself. 

This idea appears in the full algorithm as an additional condition: a split will be accepted only if the entropy gain is greater than a minimum level, given by the formula 

```
gain >= (1/N) x log<sub>2</sub>(N-1)  + (1/N) x [ log<sub>2</sub> (3<sup>k</sup>-2) - (k x Entropy(S) – k<sub>1</sub> x Entropy(S<sub>1</sub>) – k<sub>2 </sub>x Entropy(S<sub>2</sub>) ]
```

where N is the number of elements in the group to be split, and k the number of Classes in a group. 

The derivation of that stopping criterion is way beyond my level in information theory (look at the Fayyad and Irani article listed below if you are curious about the details, it’s pretty interesting), so I won’t make a fool of myself and attempt to explain it. At a very high-level, though, with heavy hand-waving, the formula appears to make some sense:  

* (1/N) x log<sub>2</sub>(N-1) decreases to 0 as N goes to infinity; this introduces a penalty on splitting smaller datasets (to an extent),  
* (1/N) x [ log<sub>2</sub> (3<sup>k</sup>-2) - (k x Entropy(S) – k<sub>1</sub> x Entropy(S<sub>1</sub>) – k<sub>2 </sub>x Entropy(S<sub>2</sub>) ] favors splits which “cleanly” separate classes (if k > k<sub>1</sub> or k2 , the penalty is reduced),  
* where log<sub>2</sub> (3<sup>k</sup>-2) is coming from is not at all obvious to me. 

## Implementation 

Here is my naïve implementation of the algorithm (available [here on GitHub](https://gist.github.com/mathias-brandewinder/5650553):

``` fsharp
namespace Discretization

// Recursive minimal entropy partitioning,
// based on Fayyad & Irani 1993. 
// See the following article, section 3.3,
// for a description of the algorithm:
// http://www.math.unipd.it/~dulli/corso04/disc.pdf
// Note: this can certainly be optimized.
module MDL =

    open System
    // Logarithm of n in base b
    let logb n b = log n / log b

    let entropy (data: (_ * _) seq) =
        let N = data |> Seq.length |> (float)
        data 
        |> Seq.countBy snd
        |> Seq.sumBy (fun (_,count) -> 
            let p = (float)count/N
            - p * log p)

    // A Block of data to be split, with its
    // relevant characteristics (size, number
    // of classes, entropy)
    type Block (data: (float * int) []) =
        let s = data |> Array.length |> (float)
        let classes = data |> Array.map snd |> Set.ofArray |> Set.count
        let k = classes |> (float)
        let h = entropy (data)
        member this.Data = data
        member this.Classes = classes
        member this.S = s
        member this.K = k
        member this.H = h

    // Entropy gained by splitting "original" block
    // into 2 blocks "left" and "right"
    let private entropyGain (original:Block) (left:Block) (right:Block) =
        original.H - 
        ((left.S / original.S) * left.H + (right.S / original.S) * right.H)

    // Minimum entropy gain required
    // for a split of the "original" block
    // into 2 blocks "left" and "right"
    let private minGain (original:Block) (left:Block) (right:Block) =
        let delta = 
            logb (pown 3. original.Classes - 2.) 2. - 
            (original.K * original.H - left.K * left.H - right.K * right.H)
        ((logb (original.S - 1.) 2.) / original.S) + (delta / original.S)

    // Identify the best acceptable value
    // to split a block of data
    let split (data:Block) =
        // Candidate values to use as split
        // We remove the smallest, because
        // by definition no value is smaller
        let candidates = 
            data.Data 
            |> Array.map fst 
            |> Seq.distinct
            |> Seq.sort
            |> Seq.toList
            |> List.tail

        let walls = seq { 
            for value in candidates do
                // Split the data into 2 groups,
                // below/above the value
                let g1, g2 = 
                    data.Data 
                    |> Array.partition (fun (v,c) -> v < value)

                let block1 = Block(g1)
                let block2 = Block(g2)
                
                let gain = entropyGain data block1 block2
                let threshold = minGain data block1 block2

                // if minimum threshold is met,
                // the value is an acceptable candidate
                if gain >= threshold 
                then yield (value, gain, block1, block2) }

        if (Seq.isEmpty walls) then None
        else 
            // Return the split value that
            // yields the best entropy gain
            walls 
            |> Seq.maxBy (fun (value, gain, b1, b2) -> gain) 
            |> Some

    // Top-down recursive partition of a data block,
    // accumulating the partitioning values into
    // a list of "walls" (splitting values)
    let partition (data:Block) = 
        let rec recursiveSplit (walls:float list) (data:Block) =
            match (split data) with
            | None -> walls // no split found
            | Some(value, gain, b1, b2) ->
                // append new split value
                let walls = value::walls
                // Search for new splits in first group
                let walls = recursiveSplit walls b1
                // Search for new splits in second group
                recursiveSplit walls b2
        // and go search!
        recursiveSplit [] data |> List.sort
``` 

The code appears to work, and is fairly readable / clean. I am not fully pleased with it, though. It’s a bit slow, and I have this nagging feeling that there is a much cleaner way to write that algorithm. I also dislike casting the counts to floats, but that’s the best way I found to avoid a proliferation of casts everywhere in the formulas, which operate mostly on floats (eg. log or proportions).

To avoid re-computing entropies, and counts of elements and classes, I introduced a Block class, which represents a block of data to be split – an array of (float * int), where the float is the continuous value and the int the label / index of the class. The algorithm recursively attempts to break blocks, and accumulates “walls” / split points along the way; it looks up every float value in the current block as a potential split point, generates a sequence of valid candidates, picks the one that generates the largest gain, and keeps searching in the two resulting blocks.

## Results

So… does it work? This is by no means a complete validation (see the References below for some more rigorous analysis), but I thought I would at least try it on some synthetic data. The [test script is on GitHub](https://gist.github.com/mathias-brandewinder/5650553):

``` fsharp
#load "MDL.fs"
open System
open Discretization.MDL

let rng = System.Random()

let tests = [
    // one single class
    "Single",
    [|  for i in 1..100 -> (rng.NextDouble(), 0) |];
    // class 0 from 0 to 1, class 1 from 1 to 2
    "Separate",
    [|  for i in 1..100 -> (rng.NextDouble(), 0)
        for i in 1..100 -> (rng.NextDouble() + 1.0, 1) |];
    // overlapping classes
    "Mixture",
    [|  for i in 1..100 -> (rng.NextDouble(), rng.Next(0,2))
        for i in 1..100 -> (rng.NextDouble() + 0.5, rng.Next(1,3))
        for i in 1..100 -> (rng.NextDouble() + 1.0, rng.Next(2,4))
        for i in 1..100 -> (rng.NextDouble() + 1.5, rng.Next(3,5)) |];
    "Alternating",
    [|  for i in 0 .. 100 -> ((float)i, if i % 2 = 0 then 0 else 1) |]; ]

tests |> List.iter (fun (title, testData) ->
    printfn "Sample: %s" title
    let data = Block(testData)
    let result = partition data
    printfn "[ %s ]" (String.Join(", ", result)))
``` 

“tests” is a list of names + datasets, which we pass through the partition function. 

* “Single” is a trivial single class (we expect no partition),  
*  “Separate” is a 2-class dataset, perfectly separated (0s are in 0 to 1, 1s in 1 to 2) (we expect a partition at 1)  
* “Mixture” is a 5-class dataset, with overlaps; we expect partitions at 0.5, 1, 1.5 and 2.  
* “Alternating” is the degenerate case we described earlier, with a sequence of 0, 1, 0, 1, … – we hope to get no partition.  

Running this in FSI produces the following:

```
Sample: Single
[  ]
Sample: Separate
[ 1.00274506863334 ]
Sample: Mixture
[ 0.520861916486575, 1.00554223847834, 1.55028371561798, 1.97660811872995 ]
Sample: Alternating
[  ]
```

… looks like the algorithm is handling these obvious cases just the way it should.

That’s it for today. I’ll come back to the topic of discretization soon, this time looking at Khiops / Chi-Square based approaches. In the meanwhile, maybe this will come in handy for some of you – and let me know if you have comments or questions!

## References

“[Multi-Interval Discretization of Continuous-Valued Attributes for Classification Learning](http://trs-new.jpl.nasa.gov/dspace/handle/2014/35171): the original Fayyad and Irani article, with a derivation of the stopping criterion.

“[Supervised and Unsupervised Discretization of Continuous Features](http://www.math.unipd.it/~dulli/corso04/disc.pdf)
”: a discussion and comparison of a few discretization approaches.

“[Khiops: A Statistical Discretization Method of Continuous Attributes](http://sci2s.ugr.es/keel/pdf/specific/articulo/bou04.pdf)”: primarily focused on Chi-Square based approaches, a comparison with the MDL model at the end.
