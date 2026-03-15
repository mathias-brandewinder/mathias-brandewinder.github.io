---
layout: post
title: Baby steps with CNTK and F#
tags:
- F#
- Machine-Learning
- Deep-Learning
- CNTK
- Scripting
---

So what have I been up to lately? Obsessing over [CNTK, the Microsoft deep-learning library][1]. Specifically, the team released a [.NET API][2], which got me interested in exploring how usable this would be from the F# scripting environment. I started a [repository to try out some ideas already][3], but, before diving into that in later posts, I figure I could start by a simple introduction, to set some context.

First, what problem does CNTK solve?

Imagine that you are interested in predicting something.  You have some data available, both inputs you can observe (the `features`), and the values you are trying to predict (the `labels`). 

For example, consider this data frame:

| Years  | Engine Size | Price |
| ------ | ----------- | ----- |
| 2007   | 350         | $10,000 |
| 2015   | 150         | $30,000 |
| 2010   | 325         | $15,000 |

The "Years" and "Engine Size" are the `features`.  "Price" is the `label`.

Next you are given some new data where you only have the `features` and you want to predict the `label`

| Years  | Engine Size | Price |
| ------ | ----------- | ----- |
| 2014   | 275         |  ???  |


Imagine now that you have an idea of the type of relationship between the input and the output.  For each "Engine Size" and "Price", there is a `parameter` that you can use to adjust the value to give you the best predicted value of the `label`.

In an function, it might look like this:
`labels ≈ function(features, parameters)`.

<!--more-->

To make this more concrete, that function could be quite complex, and involve multiple layers of input transformation into the final output ("deep learning"), or it could be quite simple, for instance a traditional linear regression, something along the lines of:

`car price ≈ car years * coefficient1 + car engine size * coefficient2 + constant`.

In this particular case, we have 2 features (`car years` and `car engine size`), 1 label (`car price`), and 3 parameters (`coefficient1`, `coefficient2` and `constant`) - and we would like to find "good" values for the 3 parameters so that the predicted value is in general close to the correct value.

The purpose of CNTK is to:

- let you specify a function connecting input and output,
- let you specify how to read example data to learn from,
- learn good parameter values from the example data,
- let you learn parameters on CPU or GPU, for large datasets and complex functions.

With that in mind, let's take a look at a very basic example, a simple linear regression. Using CNTK here is complete overkill, and not worth the overhead; I would not use it for something that simple. Our goal here is simply to illustrate the basics of how CNTK works, from F#. In future posts, we will look into scenarios where CNTK is actually useful. As a secondary goal, I want to discuss some of the aspects that make building a nice F# API on top of the current .NET one tricky.

## Loading CNTK into the F# scripting environment

First order of business: let's load this thing into VS Code.

CNTK has a few packages on Nuget, based on what environment you want to run on. In our case, we will focus on a [CPU-only scenario, using the CNTK.CPUOnly 2.3.1 package][4].

We assume that the [Ionide-fsharp][5] and [Ionide-Paket][6] extensions are installed in VS Code. Open the Folder where you want to work, and run the `Paket: Init` command (<kbd>CTRL</kbd>+<kbd>SHIFT</kbd>+<kbd>P</kbd> reveals the available commands). This will create a `paket.dependencies` file in the folder, where you can now specify what packages are needed, like this:

```
framework:net46
source https://www.nuget.org/api/v2
nuget CNTK.CPUOnly
```

Run `Paket: Install` next, and let Paket do its magic, and download the required packages. Once the operation completes, you should see a new folder, `packages`, with the following structure:

```
packages
  CNTK.CPUOnly
    lib
      net45
        x64
          Cntk.Core.Managed-2.3.1.dll
    support
      x64
        Debug
        Dependency
        Release
```

Let's start creating the script we will be working with now, by adding an F# script file `CNTK.fsx` to our folder. Unfortunately, CNTK depends on a few native libraries to run properly. As a result, the setup is a bit more involved than the usual `#r "path/to/library.dll`. We'll follow [@cdrnet](https://twitter.com/cdrnet) [approach to load native libraries described here][7], and add to the `PATH` every folder that contains the dlls we need, so `Cntk.Core.Managed-2.3.1.dll` can find them:

> Note: I put the [full code used in the post on a gist here](https://gist.github.com/mathias-brandewinder/d48abe4a571c53a4a70c709c3121a566)

``` fsharp
open System
open System.IO

Environment.SetEnvironmentVariable("Path",
    Environment.GetEnvironmentVariable("Path") + ";" + __SOURCE_DIRECTORY__)

let dependencies = [
        "./packages/CNTK.CPUOnly/lib/net45/x64/"
        "./packages/CNTK.CPUOnly/support/x64/Dependency/"
        "./packages/CNTK.CPUOnly/support/x64/Dependency/Release/"
        "./packages/CNTK.CPUOnly/support/x64/Release/"    
    ]

dependencies 
|> Seq.iter (fun dep -> 
    let path = Path.Combine(__SOURCE_DIRECTORY__,dep)
    Environment.SetEnvironmentVariable("Path",
        Environment.GetEnvironmentVariable("Path") + ";" + path)
    )    

#I "./packages/CNTK.CPUOnly/lib/net45/x64/"
#I "./packages/CNTK.CPUOnly/support/x64/Dependency/"
#I "./packages/CNTK.CPUOnly/support/x64/Dependency/Release/"
#I "./packages/CNTK.CPUOnly/support/x64/Release/"

#r "./packages/CNTK.CPUOnly/lib/net45/x64/Cntk.Core.Managed-2.3.1.dll"
open CNTK
```

## Creating a Function

We can now start using CNTK in our script. Let's build a function that takes 2 floats as input, and returns a float as an output, multiplying each of the inputs by a parameter.

A core element in CNTK is the `NDShape`, for n-dimensional shape. Think of an `NDShape` as an n-dimensional array. A vector of size 5 would be an NDShape of dimension [ 5 ] (rank 1), a 12x18 image a NDShape [ 12; 18 ] (rank 2), a 10 x 10 RGB image a NDShape [ 10; 10; 3 channels ] (rank 3), and so on. In our case, the input is an array of size 2, and the output an array of size 1:

``` fsharp
let inputDim = 2
let outputDim = 1
let input = Variable.InputVariable(NDShape.CreateNDShape [inputDim], DataType.Double, "input")
let output = Variable.InputVariable(NDShape.CreateNDShape [outputDim], DataType.Double, "output")
```

Which produces the following output:

``` fsharp
val inputDim : int = 2
val outputDim : int = 1
val input = Variable
val output = Variable
```

Note how the numeric type of the `Variable`, `DataType.Double`, is passed in as a argument, and not generic. Note also how the numeric types are aligned with the C# convention; that is, a `DataType.Double` is an F# `float`, and a `DataType.Float` is an F# `single`.

We can ask a `Variable` about its shape, for instance `input.Shape`:

``` fsharp
val it : NDShape = CNTK.NDShape { Dimensions = seq [2]; (* more stuff *) Rank = 1; }
```

Let's create our `Function` now:

``` fsharp
let device = DeviceDescriptor.CPUDevice

let predictor =
    let dim = input.Shape.[0]
    let weights = new Parameter(NDShape.CreateNDShape [dim], DataType.Double, 0.0, device, "weights")
    // create an intermediate Function
    let product = CNTKLib.TransposeTimes(input, weights)    
    let constant = new Parameter(NDShape.CreateNDShape [ outputDim ], DataType.Double, 0.0, device, "constant") 
    CNTKLib.Plus(new Variable(product), constant)
```

``` fsharp
val device : DeviceDescriptor
val predictor : Function
```

A couple of comments here. Our `predictor` creates a named `Parameter` weights of dimension and type matching the input `Variable`, with values initialized at `0.0`. We multiply the two shapes together, by calling `CNTKLib.TransposeTimes`, computing `x1 * w1 + x2 * w2`, which returns a `Function`. We then create another `Parameter` for our constant, and sum them up, using `CNTKLib.Plus`.

Note how we have to explicitly convert `product` into a `Variable` in the final step, using `new Variable(product)`. `CNTKLib.Plus` (and the other functions built in `CNTKLib`) expects 2 `Variable` arguments. Unfortunately, a `Function` is not a `Variable`, and they do not derive from a common class or interface. The .NET API supports implicit conversion between these 2 types, which works well in C#, where you could just sum these up directly, like this: `CNTKLib.Plus(product, constant)`. F# doesn't support implicit conversion, and as a result, this requires an annoying amount of explicit manual conversion to combine operations together.

Note also how we passed in `device`, a `DeviceDescriptor`, to the `Parameter` constructor. A CNTK `Function` is intended to run on a device, which must be specified. In this case, we could have omitted the device, in what case it would have picked up by default `CPU`.

## Working with CNTK Functions

Now that we have a `Function` - what can we do with it?

Unsuprisingly, we can pass input to a function, and compute the resulting value. We will do that next. However, before doing that, it's perhaps useful to put things in perspective, to understand why this isn't as straightforward as you might expect from something named a function. Once an F# function has been instantiated, its whole purpose is to transform an input value into an output value. The intent of a CNTK `Function` is subtly different: the objective here is to take a function, and modify its `Parameters` so that when passed in some input, the output it produces is close to some desired output, the `Labels`. In other words, we want a `Function` to be "trainable": we want to be able to pass it known input/output pairs, and adjust the function parameters to fit the data better.

With that said, let's evaluate our `predictor` function. To do that, we will need to do 3 things:

- Supply values to fill in the "input" placeholder shape,
- Specify what values we want to observe - we might be interested in the output, but also the weights, for instance,
- Specify what device we want the function to run on.

Let's do that:

``` fsharp
open System.Collections.Generic

let inputValue = Value.CreateBatch(NDShape.CreateNDShape [inputDim], [| 3.0; 5.0 |], device)
let inputMap = 
    let map = Dictionary<Variable,Value>()
    map.Add(input, inputValue)
    map

let predictedOutput = predictor.Output
let weights = 
    predictor.Parameters () 
    |> Seq.find (fun p -> p.Name = "weights")
let constant = 
    predictor.Parameters () 
    |> Seq.find (fun p -> p.Name = "constant")
let outputMap =
    let map = Dictionary<Variable,Value>()
    map.Add(predictedOutput, null)
    map.Add(weights, null)
    map.Add(constant, null)
    map

predictor.Evaluate(inputMap,outputMap,device)
```

To evaluate a `Function`, we pass it the input we care about, a `Dictionary<Variable,Value>`, which we fill in with `input`, the `Variable` we defined earlier. We provide (completely arbitrarily) a value of `[3.0;5.0]` as an input value. In a similar fashion, we specify what we want to observe: the predicted value, `predictor.Output`, as well as the 2 named parameters we created, "weights" and "constant", which we also retrieve from the `Function` itself. In this case, we set the `Value` to `null`, because we have no input to supply. Finally, we run `predictor.Evaluate`, which will take the `inputMap` and fill in the missing values in the `outputMap`.

We can now review the outputs:

``` fsharp
let currentPrediction = 
    outputMap.[predictedOutput].GetDenseData<float>(predictedOutput) 
    |> Seq.map (fun x -> x |> Seq.toArray)
    |> Seq.toArray

let currentWeights = 
    outputMap.[weights].GetDenseData<float>(weights) 
    |> Seq.map (fun x -> x |> Seq.toArray)
    |> Seq.toArray

let currentConstant = 
    outputMap.[constant].GetDenseData<float>(constant) 
    |> Seq.map (fun x -> x |> Seq.toArray)
    |> Seq.toArray
```

This is not pretty, but... we have values.

``` fsharp
val currentPrediction : float [] [] = [| [| 0.0 |] |]
val currentWeights : float [] [] = [| [| 0.0; 0.0 |] |] 
val currentConstant : float [] [] = [| [| 0.0 |] |] 
```

The values we get back are pretty unexciting, but at least they are what we would expect to see. Given that both weights and constant were initialized at 0.0, the function should produce a `currentPrediction` of `0.0 * 3.0 + 0.0 * 5.0 + 0.0`, which is indeed `0.0`.

Two quick notes here. First, because a value could be of any `DataType`, we have to manually specify a type when retrieving the values, as in `GetDenseData<float>`. Then, this is a very stateful model: when we fill in values for the input in the `inputMap`, we pass in the `input` instance we initially created to construct the `Function`. In a similar fashion, we are retrieving values from the instances we passed into the `outputMap`.

## Training a model

This was pretty painful. So what is our reward for that pain?

As I stated earlier, one defining feature of a `Function` is that it can be trained. What we mean by that is the following: we can take a `Function`, supply it batches of input and desired output pairs, and progressively adjust the internal `Parameter`(s) of the `Function` so that the values computed by the `Function` become close(r) to the desired output.

Let's start with a simple illustration. Suppose for a minute that, for our input `[ 3.0; 5.0 ]`, we expected a result of `10.0`. Currently, our weights and constant are set to `0.0`. By modifying these 3 values, we should be able to tune our `predictor` to get an answer of `10.0`.

This is, of course, a silly example. There are many ways I could change the parameters to produce `10.0` - I could set the constant to `10.0`, or the second weight to `2.0`, or infinitely many other combinations. To get something meaningful, I would need many different input/output pairs. However, we'll start with this, strictly to illustrate the mechanics involved.

Training a `Function` involves 3 elements:

- Supplying a batch of input / output pairs (features and labels),
- Defining a measure of fit, that is, how to measure if a value is close to the desired value,
- Specifying how parameters should be adjusted to improve the function.

``` fsharp
let batchInputValue = Value.CreateBatch(NDShape.CreateNDShape [inputDim], [| 3.0; 5.0 |], device)
let batchOutputValue = Value.CreateBatch(NDShape.CreateNDShape [outputDim], [| 10.0 |], device)

let batch =
    [
        input,batchInputValue
        output,batchOutputValue
    ]
    |> dict

let loss = CNTKLib.SquaredError(new Variable(predictor), output, "loss")
let evaluation = CNTKLib.SquaredError(new Variable(predictor), output, "evaluation")

let learningRatePerSample = new TrainingParameterScheduleDouble(0.01, uint32 1)
let learners = 
    ResizeArray<Learner>(
        [
            Learner.SGDLearner(predictor.Parameters(), learningRatePerSample)
        ]
        )

let trainer = Trainer.CreateTrainer(predictor, loss, evaluation, learners)

for i in 0 .. 10 do
    let _ = trainer.TrainMinibatch(batch, true, device)
    trainer.PreviousMinibatchLossAverage () |> printfn "Loss: %f"
    trainer.PreviousMinibatchEvaluationAverage () |> printfn "Eval: %f"
```

First, we create a batch of input/output values (`[ 3.0; 5.0 ]` and `[ 10.0 ]`), and link them to the `input` and `output` `Variable`(s) we created. Then we define what measure we want to use to determine if a prediction is close or not from the target value. In this case, we use the built-in `CNTKLib.SquaredError`, which computes the square difference between the predicted value (`new Variable(predictor)`) and the target value (`output`). For instance, with the initial weights and constant, the predicted value will be `0.0`, and we specified that the desired value was `10.0`, so the `loss` function will evaluate to `(0.0 - 10.0)^2`, that is, `100.0` - and a perfect prediction of `10.0` would result in a loss of `0.0`. Finally, without going into much detail, we specify in learners which strategy to apply when updating the function parameters. In this case, we use the built-in Stochastic Gradient Descent (SGD) strategy, with a learning rate of `0.01` (how aggressively to update the parameters) and a batch size of 1, using only one input/output pair at a time when performing adjustments. 

We feed all that into a `Trainer`, and perform 10 updates (`trainer.TrainMinibatch`), using the same example input/output each time, and writing out the current value of the loss function:

``` fsharp
Loss: 100.000000
Eval: 100.000000
Loss: 9.000000
Eval: 9.000000
// omitted intermediate results for brevity 
Loss: 0.000000
Eval: 0.000000
Loss: 0.000000
Eval: 0.000000
```

As you can observe, the prediction error decreases rapidly, from `100.0` initially (as expected), to basically `0.0` after only 10 steps.

Let's make this a bit more interesting, by feeding different examples to the model:

``` fsharp
let realModel (features:float[]) =
    3.0 * features.[0] - 2.0 * features.[1] + 5.0

let rng = Random(123456)
let batch () =        
    let batchSize = 32        
    let features = [| rng.NextDouble(); rng.NextDouble() |]
    let labels = [| realModel features |]
    let inputValues = Value.CreateBatch(NDShape.CreateNDShape [inputDim], features, device)
    let outputValues = Value.CreateBatch(NDShape.CreateNDShape [outputDim], labels, device)
    [
        input,inputValues
        output,outputValues
    ]
    |> dict
```

Here we simply create a "true" function, `realModel`, which we use to generate synthetic data. We then modify our previous example, to feed 1,000 different examples for training:

``` fsharp
#time "on"

for _ in 1 .. 1000 do
    
    let example = batch ()
    trainer.TrainMinibatch(example,true,device) |> ignore
    trainer.PreviousMinibatchLossAverage () |> printfn "Loss: %f"
```

On my machine, extracting the weights and constant from the `Function` after training yields `3.0019`, `-1.9978` and `4.9975` - pretty close to the correct values of `3.0`, `-2.0` and `5.0` that we used in `realModel`.

> Note: I put the [full code used in the post on a gist here](https://gist.github.com/mathias-brandewinder/d48abe4a571c53a4a70c709c3121a566)

## Parting thoughts

First, I want to re-iterate that the example we went through is not showcasing a good example of where and how to use CNTK. It is intended primarily as an illustration of CNTK's building blocks and how they work together. For a trivial linear regression example like this one (shallow learning, if you will), you would be better served with a standard library such as [Accord.NET](http://accord-framework.net/). CNTK becomes interesting if you have a deeper, more complex model, and a larger dataset - we'll explore this in later posts.

> As a side-note, my initial intent was to use real batches for the final example, passing in multiple examples at once, but for reasons I couldn't figure out yet, the code kept crashing.

My second goal was to explore the design of the current .NET API, as a preliminary step before trying to build an F#-scripting friendly layer on top of it.

In its current state, the CNTK .NET library is fairly low-level, and rather unpleasant to work with from F#. Ideally, one would like to be able to create re-usable blocks and compose them easily, along the lines of the Keras model, using a DSL to, for instance, define a network by stacking standard transformation layers on top of each other.

Such a DSL seems quite possible to achieve in F#, but requires taking into account a few design considerations. First, the choice to use implicit conversion between `Variable` and `Function` makes composition of functions in F# painful. This choice is reasonable for C#, but requires re-wrapping every `Function` into a `Variable` to string operations together on the F# side.

One aspect I am not a fan of in the library is how the `DeviceDescriptor` leaks all the way down. With the current model, I could create 2 parameters, one on CPU, one on GPU, and combine them together, which doesn't make a lot of sense. In an ideal world, I would like to define a `Function` independently of any device, and only then decide whether I want to train that model on a CPU or a GPU.

Finally, the fact that a `Variable` or a `Function` cannot be named after it was instantiated, as far as I can tell, introduces complications in composing blocks together. If naming was separate from instantiation, we could create a function like `named : string -> Function -> Function`, which could be inserted anywhere.

I haven't had much time yet to dig into the data readers; so far, most of my efforts have gone into exploring possible directions to address the questions above. If you are interested, the [master branch of my repository][3] contains working, straight conversions of the [C# examples published by the CNTK team][8]; the results of my explorations can be found in the 3 branches [experiment-varorfun](https://github.com/mathias-brandewinder/CNTK.FSharp/tree/experiment-varorfun), [experiment-interpreter](https://github.com/mathias-brandewinder/CNTK.FSharp/tree/experiment-interpreter) and [experiment-stacking](https://github.com/mathias-brandewinder/CNTK.FSharp/tree/experiment-stacking).

I hope you found something of interest in this post! If you have feedback or suggestions, I would be quite interested to hear about them :) In the meanwhile, I will keep exploring - expect more on the topic in the near future!


[1]: https://www.microsoft.com/en-us/cognitive-toolkit/
[2]: https://docs.microsoft.com/en-us/cognitive-toolkit/cntk-library-managed-api
[3]: https://github.com/mathias-brandewinder/CNTK.FSharp
[4]: https://www.nuget.org/packages/CNTK.CPUOnly/
[5]: https://marketplace.visualstudio.com/items?itemName=Ionide.Ionide-fsharp
[6]: https://marketplace.visualstudio.com/items?itemName=Ionide.Ionide-Paket
[7]: http://christoph.ruegg.name/blog/loading-native-dlls-in-fsharp-interactive.html
[8]: https://github.com/Microsoft/CNTK/tree/master/Examples/TrainingCSharp/Common
