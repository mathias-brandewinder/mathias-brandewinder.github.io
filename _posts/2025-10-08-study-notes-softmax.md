---
layout: post
title: Study notes&#58; Softmax function
tags:
- F#
- Machine-Learning
use_math: true
---

I was thinking recently about ways to combine prediction models, which lead 
me to the [`Softmax`][1] function. This wasn't my first encounter with it (it 
appears regularly in machine learning, neural networks in particular), but I 
never took the time to properly understand how it works. So... let's take a 
look!  

## What is the Softmax function

The `Softmax` function normalizes a set of `N` arbitrary real numbers, and 
converts them into a "probability distribution" over these `N` values. Stated 
differently, given `N` numbers, `Softmax` will return `N` numbers, with the
following properties:  

- Every output value is between `0.0` and `1.0` (a "probability"),  
- The sum of the output values equals `1.0`,  
- The output values ranking is the same as the input values.   

In F#, the standard Softmax function could be implemented like so:  

``` fsharp
let softmax (values: float []) =
    let exponentials = values |> Array.map exp
    let total = exponentials |> Array.sum
    exponentials |> Array.map (fun x -> x / total)
```

We convert all the input values to their exponentials, which guarantees that 
all of them are strictly positive, and we compute their relative weight. Note 
that I used an array here, so we can operate on arbitrary many numbers.  

Let's check how that works out on the [example from the Wikipedia page][2]:  

``` fsharp
let input = [| 1.0; 2.0; 8.0 |]
let output = input |> softmax
val output: float array = [|0.0009088005554; 0.002470376035; 0.9966208234|]
```

The 3 numbers `(1, 2, 8)` have been converted to (approximately) 
`(0.001, 0.002, 0.997)`. The sum of the converted value is `1`, and their 
ranking is the same as the ranking of the original 3 values.  

And, because the exponential function will convert any number to a strictly 
positive value, this would work as well if some or all our inputs were 
negative. As an example:  

``` fsharp
[| -1.0; 1.0; 3.0 |] |> softmax
```

Softmax converts `(-1, 1, 3)` into `(0.016, 0.117, 0.867)`, which are still all 
between 0 and 1, sum to 1, and properly ranked.  

While Softmax preserves the ranking of the input values, it distorts the 
spread between values. A variation of the standard Softmax function exists, 
where a parameter `b` (the base) controls how much the output values should be 
concentrated on the largest inputs, or evened out:  

``` fsharp
let generalSoftmax (b: float) (values: float []) =
    let exponentials =
        values
        |> Array.map (fun x -> exp (b * x))
    let total = exponentials |> Array.sum
    exponentials |> Array.map (fun x -> x / total)
```

Note how instead of  
`values |> Array.map exp`,  
we now use  
`values |> Array.map (fun x -> exp (b * x))`  

Using a value of `b = 1` is equivalent to using the standard Softmax function. 
A value of `b > 1` will amplify the weight of larger values, and a 
value of `b < 1` will soften the difference, with the extreme case `b = 0`, 
which removes any differences:  

``` fsharp
let input = [| 1.0; 2.0; 8.0 |]
input |> generalSoftmax 1.0
// [| 0.001; 0.002; 0.997 |]
input |> generalSoftmax 0.5
// [| 0.028; 0.046; 0.926 |]
input |> generalSoftmax 2.0
// [| 0.000; 0.000; 0.999 |]
input |> generalSoftmax 0.0
// [| 0.333; 0.333; 0.333 |]
```

If you push the idea further, with `b < 0`, the ranking becomes reversed.  

## What is the Softmax function useful for

Being able to reduce a set of numbers to positive values that sum to 1 is very 
convenient. In particular it is very handy for multi-class classification in 
machine learning. A multi-class classification model is a prediction model that 
given an observation, tries to determine which of 3 or more classes the 
observation belongs to.  

This is by contrast to a binary classifier, where the model only has to decide 
between 2 classes, for instance ["is this a hot dog?"][3] (or not). Such a 
model, given a picture, will likely produce a score, indicating how confident 
it is that the picture is of a hot dog. Using Softmax, we could train different 
binary models for different classes (hot dog, pizza, ...), and convert the 
scores across all classes to (pseudo) probabilities using the Softmax 
function.  

A similar approach appears in neural networks classifiers, where the last 
layer will be a Softmax function, converting the output values of perceptrons 
into a (pseudo) distribution over classes.  

Beyond machine learning, the Softmax function solves an interesting problem: 
converting any set of numbers into proportions. Apportioning a quantity based 
on a (positive) measure is easy, because we can directly compute proportions. 
As a contrived example, if we wanted to split profits between people based on 
hours worked, we could simply allocate based on hours worked / total hours 
worked. However, allocating based on some value that is not necessarily 
positive or doesn't have a lower bound doesn't work, because some proportions 
will be negative, and some might be greater than 1. That being said, I can't 
think of a practical case where I would use Softmax to address that issue!  

## Interesting properties and semi-random thoughts

The Softmax function has a few interesting mathematical properties, which are 
important in understanding how it transforms its input numbers.  

The Softmax function is invariant under translation, but not invariant under 
scaling. In less pompous terms, this means that  

- shifting all the inputs by the same value produces the same result,  
- how spread out the numbers are matters, or, stated differently, units matter.  

As an example, the inputs `(0,1)`, `(1,2)`, or `(100,101)` produce the same 
output through Softmax (invariant under translation):  

``` fsharp
softmax [| 0.; 1. |]
// [| 0.269; 0.731 |]
softmax [| 100.; 101. |]
// [| 0.269; 0.731 |]
```

Conversely, the inputs `(0.0, 0.1, 0.2)` and `(0.0, 1.0, 2.0)` do not produce 
the same output through Softmax, even though the second one has the same 
proportions, just scaled up a factor 10:  

``` fsharp
softmax [| 0.0; 0.1; 0.2 |]
// [| 0.301; 0.332; 0.367 |]
softmax [| 0.0; 1.0; 2.0 |]
// [| 0.090; 0.245; 0.665 |]
```

What drives how evenly the outputs of Softmax are spread out is mainly the 
absolute difference between the smallest and largest input values, not how 
large or small these values are. This means that using Softmax requires picking 
consistent units, and that equivalent units (ex: kilogram vs pound) will not 
produce identical results.  

One thing that bugged me in the [Wikipedia entry for Softmax][1] was the 
statement "the Softmax function converts real numbers into a probability 
distribution". In my view, the Softmax function is a very useful normalization 
technique, which produces numbers that happen to look like a probability 
distribution, but have no reason to correspond to the probability of events 
occurring.  

As an obvious example, if we start from a well-formed, valid distribution, 
Softmax will produce a different set of values:  

``` fsharp
[| 0.2; 0.3; 0.5 |] |> softmax
// [| 0.289; 0.320; 0.390 |]
```

I haven't checked if this is always true, but applying Softmax repeatedly to a 
distribution appears to converge to an even distribution, where each class 
gets the same weight:  

``` fsharp
[| 0.1; 0.2; 0.7 |]
|> Seq.unfold (fun probas -> Some (probas, softmax probas))
|> Seq.take 10
|> Seq.toArray
|> Array.iter (fun probas ->
    printfn $"%.3f{probas[0]}, %.3f{probas[1]}, %.3f{probas[2]}")
```

```
0.100, 0.200, 0.700
0.255, 0.281, 0.464
0.307, 0.315, 0.378
0.324, 0.327, 0.348
0.330, 0.331, 0.338
0.332, 0.333, 0.335
0.333, 0.333, 0.334
0.333, 0.333, 0.334
0.333, 0.333, 0.333
0.333, 0.333, 0.333
```

One way to look at this is that Softmax will first take any numbers and 
normalize them into proportions, respecting the original input ranking. 
Applying Softmax again will progressively smooth out the differences, and 
converge to an uninformative distribution. Whether this is of any practical use
or not I don't know, but I found it interesting.  


[1]: https://en.wikipedia.org/wiki/Softmax_function
[2]: https://en.wikipedia.org/wiki/Softmax_function#Definition
[3]: https://youtu.be/ACmydtFDTGs