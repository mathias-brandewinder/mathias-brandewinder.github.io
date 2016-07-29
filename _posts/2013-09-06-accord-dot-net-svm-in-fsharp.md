---
layout: post
title: First steps with Accord.NET SVM in F#
tags:
- F#
- Machine-Learning
- SVM
- Algorithms
- Accord
---

Recently, [Cesar De Souza](https://twitter.com/cesarsouza) began moving his .NET machine learning library, Accord.NET, from [Google Code](https://code.google.com/p/accord/) to [GitHub](http://accord-net.github.io/). The move is still in progress, but that motivated me to take a closer look at the library; given that it is built in C#, with an intended C# usage in mind, I wanted to see how usable it is from F#.

There is a lot in the library; as a starting point, I decided I would try out its Support Vector Machine (SVM), a classic machine learning algorithm, and run it on a classic problem, automatically recognizing hand-written digits. The dataset I will be using here is a subset of the [Kaggle Digit Recognizer contest](http://www.kaggle.com/c/digit-recognizer); each example in the dataset is a 28x28 grayscale pixels image, the result of scanning a number written down by a human, and what the actual number is. From that original dataset, I sampled 5,000 examples, which will be used to train the algorithm, and another 500 in a validation set, which we’ll use to evaluate the performance of the model on data it hasn’t “seen before”.

<!--more-->

The full example is available as a [gist on GitHub](https://gist.github.com/mathias-brandewinder/6443302).

I’ll be working in a script file within a Library project, as I typically do when exploring data. First, we need to add references to Accord.NET via NuGet:

``` fsharp
#r @"..\packages\Accord.2.8.1.0\lib\Accord.dll"
#r @"..\packages\Accord.Math.2.8.1.0\lib\Accord.Math.dll"
#r @"..\packages\Accord.Statistics.2.8.1.0\lib\Accord.Statistics.dll"
#r @"..\packages\Accord.MachineLearning.2.8.1.0\lib\Accord.MachineLearning.dll"
 
open System
open System.IO
 
open Accord.MachineLearning
open Accord.MachineLearning.VectorMachines
open Accord.MachineLearning.VectorMachines.Learning
open Accord.Statistics.Kernels
```

Note the added reference to the `Accord.dll` and `Accord.Math.dll` assemblies; while the code presented below doesn’t reference it explicitly, it looks like `Accord.MachineLearning` is trying to load the assembly, which fails miserably if they are not referenced.

Then, we need some data; once the training set and validation set have been downloaded to your local machine (see the gist for the datasets url), that’s fairly easy to do:

``` fsharp
let training = @"C:/users/mathias/desktop/dojosample/trainingsample.csv"
let validation = @"C:/users/mathias/desktop/dojosample/validationsample.csv"
 
let readData filePath =
    File.ReadAllLines filePath
    |> fun lines -> lines.[1..]
    |> Array.map (fun line -> line.Split(','))
    |> Array.map (fun line ->
    (line.[0] |> Convert.ToInt32), (line.[1..] |> Array.map Convert.ToDouble))
    |> Array.unzip
 
let labels, observations = readData training
```

We read every line of the CSV file into an array of strings, drop the headers with array slicing, keeping only items at or after index 1, split each line around commas (so that each line is now an array of strings), retrieve separately the first element of each line (what the number actually is), and all the pixels, which we transform into a float, and finally unzip the result, so that we get an array of integers (the actual numbers), and an array of arrays, the grayscale level of each pixel.

Now that we have data, we can begin the machine learning process. One nice thing about Accord.NET is that out of the box, it includes two implementations for multi-class learning. By default, a SVM is a binary classifier: it separates between two classes only. In our case, we need to separate between 10 classes, because each number could be anything between 0 and 9. Accord.NET has two SVM “extensions” built-in, a multi-label classifier, which constructs a one-versus-all classifier for each class, and a multi-class classifier, which constructs a one-versus-one classifier for every class; in both cases, the library handles determining what is ultimately the most likely class.

I had never used a multi-class SVM, so that’s what I went for. The general library design is object oriented: we create a Support Vector Machine, which will be responsible for classifying, configure it, and pass it to a Learning class, which is responsible for training it using the training data it is given, and a “learning strategy”. In the case of a multi-class learning process, the setup follows two steps: we need to configure the overall multi-class SVM and Learning algorithm (what type of kernel to use, how many classes are involved, and what data to use), but also define how each one-versus-one SVMs should operate.

``` fsharp
let features = 28 * 28
let classes = 10
 
let algorithm =
fun (svm: KernelSupportVectorMachine)
(classInputs: float[][])
(classOutputs: int[]) (i: int) (j: int) ->
let strategy = SequentialMinimalOptimization(svm, classInputs, classOutputs)
strategy :> ISupportVectorMachineLearning
 
let kernel = Linear()
let svm = new MulticlassSupportVectorMachine(features, kernel, classes)
let learner = MulticlassSupportVectorLearning(svm, observations, labels)
let config = SupportVectorMachineLearningConfigurationFunction(algorithm)
learner.Algorithm <- config
 
let error = learner.Run()
 
printfn "Error: %f" error
```

We have 28x28 features (the pixel of each image) and 10 classes (0 to 9, the actual number). The algorithm is a function (a delegate, in Accord.NET), defining how each one-vs-one classifier should be built. It expects a SVM (what SVM will be constructed to classify each pair of numbers), what input to use (the pixels, as a 2D array of floats) and the corresponding expected output (the numbers, an array of ints), and 2 numbers i and j, the specific pair we are building a model for. I haven’t checked, but I assume the “outer” multi-class machine creates a SVM for each case, filtering the training set to keep only the relevant training data for each possible combination of classes i and j. Using that data, we set up the learning strategy to use, in this case a SMO (Sequential Minimal Optimization), and return the corresponding interface.

That’s the painful part – once this is done, we pick a Linear Kernel, the simplest one possible (Accord.NET comes with a battery of built-in Kernels to chose from), create our multi-class SVM, and setup the learner, who will be responsible for training the SVM, pass it the strategy – and the machine can start learning.

If you run this in FSI, after a couple of seconds, you should see the following:

`Error: 0.000000`

The SVM properly classifies every example in the training set. Nice! Let’s see how it does on the validation set:

``` fsharp
let validationLabels, validationObservations = readData validation
 
let correct =
    Array.zip validationLabels validationObservations
    |> Array.map (fun (l, o) -> if l = svm.Compute(o) then 1. else 0.)
    |> Array.average
 
let view =
    Array.zip validationLabels validationObservations
    |> fun x -> x.[..20]
    |> Array.iter (fun (l, o) -> printfn "Real: %i, predicted: %i" l (svm.Compute(o)))
```

We extract the 500 examples from the second data set; for each example, if the SVM predicts the true label, we count it as a 1, otherwise a 0 – and average these out, which produces the percentage of examples correctly predicted by the SVM. For good measure, we also display the 20 first examples, and what was predicted by the SVM, which produces the following result: 90% correct, and

```
Real: 8, predicted: 1
Real: 7, predicted: 7
Real: 2, predicted: 2
Real: 6, predicted: 6
Real: 3, predicted: 3
Real: 1, predicted: 8
Real: 2, predicted: 2
Real: 6, predicted: 6
Real: 6, predicted: 6
Real: 6, predicted: 6
Real: 6, predicted: 6
Real: 4, predicted: 4
Real: 8, predicted: 8
Real: 1, predicted: 1
Real: 0, predicted: 0
Real: 7, predicted: 7
Real: 6, predicted: 5
Real: 2, predicted: 4
Real: 0, predicted: 0
Real: 3, predicted: 3
Real: 6, predicted: 6
```

We see a 1 and 8 being mistaken for each other, and a 6 classified as a 5, which makes some sense. And that’s it – in about 60 lines of code, we got a support vector machine working!

## Conclusion

Getting the code to work was overall fairly simple; the two pain points were first the dynamic loading (I had to run it until I could figure out every dependency that needed referencing), and then setting up the delegate responsible for setting up the 1-vs-1 learning. I kept the code un-necessarily verbose, with type annotations everywhere – these are technically not needed, but they hopefully clarify how the arguments are being used. Also, a point of detail: the `MulticlassSupportVectorMachine` class implements `IDisposable`, and I am not certain why that is.

The resulting classifier is OK, but not great – a trivial KNN classifier has a better accuracy than this. That being said, I can’t blame the library for that, I used the dumbest possible Kernel, and didn’t play with any of the Sequential Minimization parameters. On the plus side, the learning process is pretty fast, and the Supper Vector Machine should be faster than the KNN classifier: without modifying any of the options available or default values, Accord.NET trained a pretty decent model. I tried to run it on the full 50,000 examples Kaggle dataset, and ran into some memory issues there, but it seems there are also options to trade memory and speed, which is nice.

All in all, a good first impression! Now that I got the basics working, I’ll probably revisit this later, and explore the advanced options, as well as some of the other algorithms implemented in the library (in particular, Neural Networks). I also need to think about whether it would make sense to build F# extensions to simplify usage a bit. In the meanwhile, hopefully this post might serve as a handy “quick-start” for someone!

[Full gist on GitHub](https://gist.github.com/mathias-brandewinder/6443302)
