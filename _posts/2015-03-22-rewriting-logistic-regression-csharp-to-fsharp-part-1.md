---
layout: post
title: Rewriting a Logistic Regression from C# to F#, part 1
tags:
- F#
- C#
- Algorithm
- Logistic-Regression
- Design
- Machine-Learning
---

I will admit it, I got a bit upset by James McCaffrey’s column in MSDN magazine this month, [“Gradient Descent Training Using C#”][1]. While the algorithm explanations are quite good, I was disappointed by the C# sample code, and kept thinking to myself “why oh why isn’t this written in F#”. This is by no means intended as a criticism of C#; it’s a great language, but some problems are just better suited for different languages, and in this case, I couldn’t fathom why F# wasn’t used.

<!--more-->

Long story short, I just couldn’t let it go, and thought it would be interesting to take that C# code, and do a commented rewrite in F#. I won’t even go into why the code does what it does – the article explains it quite well – but will instead purely focus on the implementation, and will try to keep it reasonably close to the original, at the expense of some additional nifty things that could be done.

The general outline of the code follows two parts:

- Create a synthetic dataset, creating random input examples, and computing the expected result using a known function,
- Use gradient descent to learn the model parameters, and compare them to the true value to check whether the method is working.

You can download the original C# code here. Today we’ll focus only on the first part, which is mainly contained in two methods, `MakeAllData` and `MakeTrainTest`:

``` csharp
static double[][] MakeAllData(int numFeatures, int numRows, int seed)
{
  Random rnd = new Random(seed);
  double[] weights = new double[numFeatures + 1]; // inc. b0
  for (int i = 0; i < weights.Length; ++i)
    weights[i] = 20.0 * rnd.NextDouble() - 10.0; // [-10.0 to +10.0]

  double[][] result = new double[numRows][]; // allocate matrix
  for (int i = 0; i < numRows; ++i)
    result[i] = new double[numFeatures + 1]; // Y in last column

  for (int i = 0; i < numRows; ++i) // for each row
  {
    double z = weights[0]; // the b0
    for (int j = 0; j < numFeatures; ++j) // each feature / column except last
    {
      double x = 20.0 * rnd.NextDouble() - 10.0; // random X in [10.0, +10.0]
      result[i][j] = x; // store x
      double wx = x * weights[j + 1]; // weight * x
      z += wx; // accumulate to get Y
    }
    double y = 1.0 / (1.0 + Math.Exp(-z));
    if (y > 0.55)  // slight bias towards 0
      result[i][numFeatures] = 1.0; // store y in last column
    else
      result[i][numFeatures] = 0.0;
  }
  Console.WriteLine("Data generation weights:");
  ShowVector(weights, 4, true);

  return result;
}
```

MakeAllData takes a number of features and rows, and a seed for the random number generator so that we can replicate the same dataset repeatedly. The dataset is represented as an array of array of doubles. The first columns, from 0 to numFeatures – 1, contain random numbers between –10 and 10. The last column contains a 0 or a 1. What we are after here is a classification model: each row can take two states (1 or 0), and we are trying to predict them from observing the features. In our case, that value is computed using a logistic model: we have a set of weights (which we also generate randomly), corresponding to each feature, and the output is

`logistic [ x1; x2; … xn ] = 1.0 / (1.0 + exp ( - (w0 * 1.0 + w1 * x1 + w2 * x2 + … + wn * xn))`

Note that w0 plays the role of a constant term in the equation, and is multiplied by 1.0 all the time. This is adding some complications to a code where indices are already flying left and right, because now elements in the weights array are mis-aligned by one element with the elements in the features array. Personally, I also don’t like adding another column to contain the predicted value, because that’s another implicit piece of information we have to remember.

In that frame, I will make two minor changes here, just to keep my sanity. First, as is often done, we will insert a column containing just 1.0 in each observation, so that the weights and features are now aligned. Then, we will move the 0s and 1s outside of the features array, to avoid any ambiguity.

Good. Instead of creating a Console application, I’ll simply go for a script. That way, I can just edit my code and check live whether it does what I want, rather than recompile and run every time.

Let’s start with the weights. What we are doing here is simply creating an array of numFeatures + 1 elements, populated by random values between –10.0 and 10.0. We’ll go a bit fancy here: given that we are also generating random numbers the same way a bit further down, let’s extract a function that generates numbers uniformly between a low and high value:

``` fsharp
let rnd = Random(seed)
let generate (low,high) = low + (high-low) * rnd.NextDouble()
let weights = Array.init (numFeatures + 1) (fun _ -> generate(-10.0,10.0))
```

The next section is where things get a bit thornier. The C# code creates an array, then populates it row by row, first filling in the columns with random numbers, and then applying the logistic function to compute the value that goes in the last column. We can make that much clearer, by extracting that function out. The logistic function is really doing 2 things:

- first, the sumproduct of 2 arrays,
- and then, 1.0/(1.0 + exp ( – z ).

That is easy enough to implement:

``` fsharp
let sumprod (v1:float[]) (v2:float[]) =
  Seq.zip v1 v2 |> Seq.sumBy (fun (x,y) -> x * y)

let sigmoid z = 1.0 / (1.0 + exp (- z))

let logistic (weights:float[]) (features:float[]) =
  sumprod weights features |> sigmoid
```

We can now use all this, and generate a dataset by simply first creating rows of random values (with a 1.0 in the first column for the constant term), applying the logistic function to compute the value for that row, and return them as a tuple:

``` fsharp
open System

let sumprod (v1:float[]) (v2:float[]) =
  Seq.zip v1 v2 |> Seq.sumBy (fun (x,y) -> x * y)

let sigmoid z = 1.0 / (1.0 + exp (- z))

let logistic (weights:float[]) (features:float[]) =
  sumprod weights features |> sigmoid

let makeAllData (numFeatures, numRows, seed) =

  let rnd = Random(seed)
  let generate (low,high) = low + (high-low) * rnd.NextDouble()
  let weights = Array.init (numFeatures + 1) (fun _ -> generate(-10.0,10.0))

  let dataset =
    [| for row in 1 .. numRows ->
      let features =
        [|
          yield 1.0
          for feat in 1 .. numFeatures -> generate(-10.0,10.0)
        |]
      let value =
        if logistic weights features > 0.55
        then 1.0
        else 0.0
      (features, value)
    |]

  weights, dataset
```

Done. Let’s move to the second part of the data generation, with the `MakeTrainTest` method. Basically, what this does is take a dataset, shuffle it, and split it in two parts, 80% which we will use for training, and 20% we leave out for validation.

``` csharp
static void MakeTrainTest(double[][] allData, int seed,
out double[][] trainData, out double[][] testData)
{
  Random rnd = new Random(seed);
  int totRows = allData.Length;
  int numTrainRows = (int)(totRows * 0.80); // 80% hard-coded
  int numTestRows = totRows - numTrainRows;
  trainData = new double[numTrainRows][];
  testData = new double[numTestRows][];

  double[][] copy = new double[allData.Length][]; // ref copy of all data
  for (int i = 0; i < copy.Length; ++i)
    copy[i] = allData[i];

  for (int i = 0; i < copy.Length; ++i) // scramble order
  {
    int r = rnd.Next(i, copy.Length); // use Fisher-Yates
    double[] tmp = copy[r];
    copy[r] = copy[i];
    copy[i] = tmp;
  }
  for (int i = 0; i < numTrainRows; ++i)
    trainData[i] = copy[i];

  for (int i = 0; i < numTestRows; ++i)
    testData[i] = copy[i + numTrainRows];
}
```

Again, there is a ton of indexing going on, which in my old age I find very hard to follow. Upon closer inspection, really, the only thing complicated here is the Fischer-Yates shuffle, which takes an array and randomly shuffles the order. The rest is pretty simply – we just want to shuffle, and then split into two arrays. Let’s extract the shuffle code (which happens to also be used and re-implemented later on):

``` fsharp
let shuffle (rng:Random) (data:_[]) =
  let copy = Array.copy data
  for i in 0 .. (copy.Length - 1) do
    let r = rng.Next(i, copy.Length)
    let tmp = copy.[r]
    copy.[r] <- copy.[i]
    copy.[i] <- tmp
  copy
```

We went a tiny bit fancy again here, and made the shuffle work on generic arrays; we also pass in the Random instance we want to use, so that we can control / repeat shuffles if we want, by passing a seeded Random. Does this work? Let’s check in FSI:

```
> [| 1 .. 10 |] |> shuffle (Random ());;
val it : int [] = [|6; 7; 2; 10; 8; 5; 4; 9; 3; 1|]
```

Looks reasonable. Let’s move on – we can now implement the `makeTrainTest` function.

``` fsharp
let makeTrainTest (allData:_[], seed) =

  let rnd = Random(seed)
  let totRows = allData.Length
  let numTrainRows = int (float totRows * 0.80) // 80% hard-coded

  let copy = shuffle rnd allData
  copy.[.. numTrainRows-1], copy.[numTrainRows ..]
```

Done. A couple of remarks here. First, F# is a bit less lenient than C# around types, so we have to be explicit when converting the number of rows to 80%, first to float, then back to int. As an aside, this used to annoy me a bit in the beginning, but I have come to really like having F# as this slightly psycho-rigid friend who nags me when I am taking a dangerous path (for instance, dividing two integers and hoping for a percentage).

Besides that, I think the code is markedly clearer. The complexity of the shuffle has been nicely contained, and we just have to slice the array to get a training and test sets. As an added bonus, we got rid of the out parameters, and that always feels nice and fuzzy.

I’ll leave it at for today; next time we’ll look at the second part, the learning algorithm itself. Before closing shop, let me make a couple of comments. First, the code is a tad shorter, but not by much. I haven’t really tried, and deliberately made only the changes I thought were needed. What I like about it, though, is that all the indexes are gone, except for the shuffle. In my opinion, this is a good thing. I find it difficult to keep it all in my head when more than one index is involved; when I need to also remember what columns contain special values, I get worried – and just find it hard to figure out what is going on. By contrast, I think makeTrainTest, for instance, conveys pretty directly what it does. makeAllData, in spite of some complexity, also maps closely the way I think about my goal: “I want to generate rows of inputs” – this is precisely what the code does. There is probably an element of culture to it, though; looping over arrays has a long history, and is familiar to every developer, and what looks readable to me might look entirely weird to some.

Easier, or more complicated than before? Anything you like or don’t like – or find unclear? Always interested to hear your opinion! Ping me if you have comments.

[1]: https://msdn.microsoft.com/en-us/magazine/dn913188.aspx
