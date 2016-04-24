---
layout: post
title: Rewriting a Logistic Regression from C# to F#, part 2
tags:
- F#
- C#
- Algorithms
- Logistic-Regression
- Design
- Machine-Learning
---

In our previous post, we looked at James McCaffrey’s code, [“Gradient Descent Training Using C#”][1] from MSDN magazine, and [took a stab at rewriting the first part in F#](http://brandewinder.com/2015/03/22/rewriting-logistic-regression-csharp-to-fsharp-part-1/), to clarify a bit the way the dataset was created. Today, we’ll dive in the second block, which implements the logistic regression using gradient descent. Again, we won’t discuss why the algorithm works – the article does a pretty good job at that – and focus instead purely on the F# / C# conversion part.

<!--more-->

Let’s begin by taking a look at the core of the C# code, which lives in the `LogisticClassifier` class. I took the liberty to do some minor cleanup, and remove some parts which were un-necessary, so as to make it a bit easier to see what is going on:

``` csharp
public class LogisticClassifier
{
  private int numFeatures; // number of x variables aka features
  private double[] weights; // b0 = constant
  private Random rnd;

  public LogisticClassifier(int numFeatures)
  {
    this.numFeatures = numFeatures;
    this.weights = new double[numFeatures + 1]; // [0] = b0 constant
    this.rnd = new Random(0);
  }

  public double[] Train(double[][] trainData, int maxEpochs, double alpha)
  {
    // alpha is the learning rate
    int epoch = 0;
    int[] sequence = new int[trainData.Length]; // random order
    for (int i = 0; i < sequence.Length; ++i)
      sequence[i] = i;

    while (epoch < maxEpochs)
    {
      ++epoch;

      if (epoch % 100 == 0 && epoch != maxEpochs)
      {
        double mse = Error(trainData, weights);
        Console.Write("epoch = " + epoch);
        Console.WriteLine("  error = " + mse.ToString("F4"));
      }

      Shuffle(sequence); // process data in random order

      // stochastic/online/incremental approach
      for (int ti = 0; ti < trainData.Length; ++ti)
      {
        int i = sequence[ti];
        double computed = ComputeOutput(trainData[i], weights);
        int targetIndex = trainData[i].Length - 1;
        double target = trainData[i][targetIndex];

        weights[0] += alpha * (target - computed) * 1; // the b0 weight has a dummy 1 input
        for (int j = 1; j < weights.Length; ++j)
          weights[j] += alpha * (target - computed) * trainData[i][j - 1];            
      }
    } // while
    return this.weights; // by ref is somewhat risky
  } // Train

  private void Shuffle(int[] sequence)
  {
    for (int i = 0; i < sequence.Length; ++i)
    {
      int r = rnd.Next(i, sequence.Length);
      int tmp = sequence[r];
      sequence[r] = sequence[i];
      sequence[i] = tmp;
    }
  }

  private double Error(double[][] trainData, double[] weights)
  {
    // mean squared error using supplied weights
    int yIndex = trainData[0].Length - 1; // y-value (0/1) is last column
    double sumSquaredError = 0.0;
    for (int i = 0; i < trainData.Length; ++i) // each data
    {
      double computed = ComputeOutput(trainData[i], weights);
      double desired = trainData[i][yIndex]; // ex: 0.0 or 1.0
      sumSquaredError += (computed - desired) * (computed - desired);
    }
    return sumSquaredError / trainData.Length;
  }

  private double ComputeOutput(double[] dataItem, double[] weights)
  {
    double z = 0.0;
    z += weights[0]; // the b0 constant
    for (int i = 0; i < weights.Length - 1; ++i) // data might include Y
    z += (weights[i + 1] * dataItem[i]); // skip first weight
    return 1.0 / (1.0 + Math.Exp(-z));
  }
} // LogisticClassifier
```

Just from the length of it, you can tell that most of the action is taking place in the Train method, so let’s start there. What we have here is two nested loops. The outer one runs maxEpoch times, a user defined parameter. Inside that loop, we randomly shuffle the input dataset, and then loop over each training example, computing the predicted output of the logistic function for that example, comparing it to a target, the actual  label of the example, which can be 0 or 1, and adjusting the weights so as to reduce the error. We also have a bit of logging going on, displaying the prediction error every hundred outer iteration. Once the two loops are over, we return the weights.

Two things strike me here. First, a ton of indexes are involved, and this tends to obfuscate what is going on; as a symptom, a few comments are needed, to clarify how the indexes work, and what piece of the data is organized. Then, there is a lot of mutation going on. It’s not necessarily a bad thing, but I tend to avoid it as much as possible, simply because it requires keeping more moving parts in my head when I try to follow the code, and also, as McCaffrey himself points out in a comment, because “by ref is somewhat risky”.

As a warm up, let’s begin with the error computation, which is displayed every 100 iterations.  Rather than having to remember in what column the actual expected value is stored, let’s make our life easier, and use a type alias, Example, so that the features are neatly tucked in an array, and the value is clearly separated. We need to compute the average square difference between the expected value, and the output of the logistic function for each example. As it turns out, we have already implemented the logistic function in the first part in the code, so re-implementing it as in ComputeOutput seems like un-necessary work – we can get rid of that part entirely, and simply map every example to the square error, and compute the average, using pattern matching on the examples to separate clearly the features and the expected value:

``` fsharp
type Example = float [] * float

let Error (trainData:Example[], weights:float[]) =
  // mean squared error using supplied weights
  trainData
  |> Array.map (fun (features,value) ->
  let computed = logistic weights features
  let desired = value
  (computed - desired) * (computed - desired))
  |> Array.average
```

Some of you might argue that this could be made tighter – I can think of at least two possibilities. First, using a Tuple might not be the most expressive approach; replacing it with a Record instead could improve readability. Then, we could also skip the map + average part, and directly ask F# to compute the average on the fly:

``` fsharp
type Example = { Features:float[]; Label:float }

let Error (trainData:Example[], weights:float[]) =
  trainData
  |> Array.averageBy (fun example ->
    let computed = logistic weights example.Features
    let desired = example.Label
    (computed - desired) * (computed - desired))
```

I will keep my original version the way it is, mostly because we created a dataset based on tuples last times.

We are now ready to hit the center piece of the algorithm. Just like we would probably try to extract a method in C#, we will start extracting some of the gnarly code that lies in the middle:

``` csharp
for (int ti = 0; ti < trainData.Length; ++ti)
{
  int i = sequence[ti];
  double computed = ComputeOutput(trainData[i], weights);
  int targetIndex = trainData[i].Length - 1;
  double target = trainData[i][targetIndex];

  weights[0] += alpha * (target - computed) * 1; // the b0 weight has a dummy 1 input
  for (int j = 1; j < weights.Length; ++j)
    weights[j] += alpha * (target - computed) * trainData[i][j - 1];            
}
```

Rather than modify the weights values, it seems safer to compute new weights. And because we opted last week to insert a column with ones for the constant feature, we won’t have to deal with the index misalignment, which requires separate handling for b0 and the rest. Instead, we can write an update operation that takes in an example and weights, and returns new weights:

``` fsharp
let update (example:Example) (weights:float[]) =
  let features,target = example
  let computed = logistic weights features
  weights
  |> Array.mapi (fun i w ->
    w + alpha * (target - computed) * features.[i])
```

`Array.mapi` allows us to iterate over the weights, while maintaining the index we are currently at, which we use to grab the feature value at the corresponding index. Alternatively, you could go all verbose and zip the arrays together – or all fancy with a double-pipe and map2 to map the two arrays in one go. Your pick:

``` fsharp
Array.zip weights features
|> Array.map (fun (weight,feat) ->
  weight + alpha * (target - computed) * feat)

(weights,features)
||> Array.map2 (fun weight feat ->
  weight + alpha * (target - computed) * feat)
```

We are now in a very good place; the only thing left to do is to plug that into the two loops. The inner loop is a perfect case for a fold (the Aggregate method in LINQ): given a starting value for weights, we want to go over every example in our training set, and, for each of them, run the update function to compute new weights. For the while loop, we’ll take a different approach, and use recursion: when the epoch reaches maxEpoch, you are done, return the weights, otherwise, keep shuffling the data and updating weights. Let’s put that all together:

``` fsharp
let Train (trainData:Example[], numFeatures, maxEpochs, alpha, seed) =

  let rng = Random(seed)
  let epoch = 0

  let update (example:Example) (weights:float[]) =
    let features,target = example
    let computed = logistic weights features
    weights
    |> Array.mapi (fun i w ->
      w + alpha * (target - computed) * features.[i])

  let rec updateWeights (data:Example[]) epoch weights =

    if epoch % 100 = 0
    then printfn "Epoch: %i, Error: %.2f" epoch (Error (data,weights))

    if epoch = maxEpochs then weights
    else
      let data = shuffle rng data
      let weights =
        data
        |> Array.fold (fun w example -> update example w) weights
      updateWeights data (epoch + 1) weights
  // initialize the weights and start the recursive update
  let initialWeights = [| for _ in 1 .. numFeatures + 1 -> 0. |]
  updateWeights trainData 0 initialWeights
```

And that’s pretty much it. We replaced the whole class by a couple of functions, and all the indexes are gone. This is probably a matter of taste and comfort with functional concepts, but in my opinion, this is much easier to follow.

Before trying it out, to make sure it works, I’ll take a small liberty, and modify the `Train` function. As it stands right now, it returns the final weights, but really, we don’t care about the weights, what we want is a classifier, which is a function that, given an array, will predict a one or a zero. That’s easy enough, let’s return a function at the end instead of weights:

``` fsharp
// initialize the weights and start the recursive update
let initialWeights = [| for _ in 1 .. numFeatures + 1 -> 0. |]
let finalWeights = updateWeights trainData 0 initialWeights
let classifier (features:float[]) =
  if logistic finalWeights features > 0.5 then 1. else 0.
classifier
```

We can now wrap it up, and see our code in action:

``` fsharp
printfn "Begin Logistic Regression (binary) Classification demo"
printfn "Goal is to demonstrate training using gradient descent"

let numFeatures = 8 // synthetic data
let numRows = 10000
let seed = 1

printfn "Generating %i artificial data items with %i features" numRows numFeatures   
let trueWeights, allData = makeAllData(numFeatures, numRows, seed)

printfn "Data generation weights:"
trueWeights |> Array.iter (printf "%.2f ")
printfn ""

printfn "Creating train (80%%) and test (20%%) matrices"

let trainData, testData = makeTrainTest(allData, 0)
printfn "Done"

let maxEpochs = 1000
let alpha = 0.01

let classifier = Train (trainData,numFeatures,maxEpochs,alpha,0)

let accuracy (examples:Example[]) =
  examples
  |> Array.averageBy (fun (feat,value) ->
    if classifier feat = value then 1. else 0.)

accuracy trainData |> printfn "Prediction accuracy on train data: %.4f"
accuracy testData |> printfn "Prediction accuracy on test data: %.4f"
```

We used a small trick to compute the accuracy – we mark every correct call as a one, every incorrect one as a zero, which, when we compute the average, gives us directly the proportion of cases that were called correctly. On my machine, I get the following output:

```
>
Prediction accuracy on train data: 0.9988
Prediction accuracy on test data: 0.9980
```

Looks good enough to me, the implementation seems to be working. The whole code presented here is [available as a gist here][2]. I’ll leave it at that for now (I might revisit it later, and try to make this work with [DiffSharp][3] at some point, if anyone is interested).

[1]: https://msdn.microsoft.com/en-us/magazine/dn913188.aspx
[2]: https://gist.github.com/mathias-brandewinder/d3daebd687f2095de1b1
[3]: http://gbaydin.github.io/DiffSharp/
