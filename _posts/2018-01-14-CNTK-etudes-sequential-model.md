---
layout: post
title: CNTK&#58; &#233;tudes in F# (sequential models)
tags:
- F#
- Machine-Learning
- Deep-Learning
- CNTK
---

In my previous post, I [introduced CNTK and how to use it from F#][1], with some comments on how the .Net API design makes it unpleasant to work with. In this post, I'll present one direction I have been exploring to address these, to build models by stacking up layers into sequential models.

Let's start by taking a step back, and briefly explaining what a sequential model is. In our previous post, we stated that the purpose of CNTK was to learn parameters of a `Function`, to minimize the error observed between known input and output data. That `Function` is a model, which transforms an input (what we observe) into a output (what we want to predict). The example we used was a simple linear combination, but CNTK supports arbitrarily complex models, created by combining together multiple functions into a single one.

[Sequential models][2] are one specific way of combining functions into a model, and are particularly interesting in machine learning. Imagine that you are trying to recognize some pattern in an image, say, a cat. You will probably end up with a pipeline of transformations of filters, along the lines of:

Original Image: pixels -> Gray Scale -> Normalize -> Filter -> ... ->  0 or 1: is it a Cat?

As an F# developer, this probably looks eerily familiar, reminescent of pipelining with the `|>` operator:

``` fsharp
[ 1; 2; 3; 4; 5 ] 
|> List.map grayScale 
|> List.map normalize 
|> List.map someOtherOperation
...
```

Can we achieve something similar with CNTK, to make the creation of models by stacking transformation layers on top of each other? Let's give it a try.

<!--more-->

## Composing Functions

Let's look into how CNTK works, to understand better where the analogy works, and where it breaks down.

First, what we are after is the creation of a model, a CNTK `Function` that operates on a `Variable` input of a specific shape. So a model should be of type `Variable -> Function`.

In a perfect world, if functions in CNTK behaved the way they behave in F#, we could simply bolt them together by direct composition, as in `function1 >> function2`. However, the world is not perfect, and CNTK functions do not "return" anything, so that won't do. However, CNTK lets us convert a `Function` to its output `Variable`, by explicitly creating a new variable, like so: `new Variable(myFunction)`. In that frame, if we had two models `foo : Variable -> Function` and `bar : Variable -> Function`, we could compose them together along these lines:

``` fsharp
let baz : Variable -> Function =
    fun input ->
        let valueOfFoo = new Variable(foo value)
        bar valueOfFoo
```

In other words, assuming that the shape of what `foo` computes is compatible with the shape `bar` expects as an input, we can compose them into a bigger model, which will take in the original input, and pass it through both functions. Progress.

> Note: one difference with F# composition is that we have no type-checking on whether or not the functions can be composed. We are operating on one type, `Variable`, so as long as blocks conform to the signature `Variable -> Function`, they will compose. If the shapes happen to not match, we will get a runtime exception. 

We are not entirely done, however. In my previous post, I voiced some gripes about the design choice to have `DeviceDescriptor` (what device the computation should run on) leaking everywhere. Any time you need to create a new `Parameter` for the model, a `DeviceDescriptor` that is consistent with the rest of the computation needs to be supplied.

For the sake of clarity, let's consider an example model, slightly simplified from our previous post, where, given an input `Variable` that is expected to be a simple vector, we create a `Parameter` vector of same size, and return the product of the two: 

``` fsharp
let device = DeviceDescriptor.CPUDevice

let predictor (input:Variable) =
    let dim = input.Shape.[0]
    let weights = new Parameter(NDShape.CreateNDShape [dim], DataType.Double, 0.0, device, "weights")
    let product = CNTKLib.TransposeTimes(input, weights)
```

`predictor` is a model as previously defined - it takes a `Variable` and returns a `Function`. The issue here is that `device` is embedded in the `weights`. As a result, if we were to create and combine multiple models, we would have no guarantee that they use compatible devices. Furthermore, if we decided to run on a GPU instead of a CPU, we would have now to change the construction of our model. This is not satisfying: the model is just the specification of a mathematical computation, and should not care about devices. What I would like is a computation, which I can then direct to run on whichever device I please. 

Can we solve that? We certainly can. In this case, I want a computation that, when directed to a device, will provide a function that can be run. All we need is a function that, given a device, will return a model. In other words, we can define a type `Computation`:

``` fsharp
type Computation = DeviceDescriptor -> Variable -> Function
```

We can now define blocks of computations, which can be sequentially combined:

``` fsharp
[<RequireQualifiedAccess>]
module Layer = 

    let stack (next:Computation) (curr:Computation) : Computation =
        fun device ->
            fun variable ->
                // compute output of current computation...
                let intermediate = new Variable(curr device variable)
                // ... and feed it to the next computation
                next device intermediate
```

What this allows us to do now is to define "standard computations" - common layers one would want to combine in a linear/sequential fashion - and stack then into a model, which, once provided a specific device, will be runnable:

``` fsharp
let model : Computation = 
    computation1
    |> Layer.stack computation2
    |> Layer.stack computation3
    ...
```

> Note: one issue with this approach is that we cannot optionally name the composed blocks. Unfortunately, things must be named at the moment they are instantiated in CNTK (as far as I can tell, you cannot rename a `Function`, `Variable` or `Parameter` once it exists). I couldn't find a good solution for this yet.

> Note: `stack` might not be the best choice of name, because it has a very specific meaning in machine learning. At the same time, `compose` seems overly generic - suggestions welcome.

> Note: instead of `|> Layer.stack`, I could also create a custom operator. I have stayed away from that for a few reasons. First, if that function fits an existing operator, I would like to use the right one - but I don't know if that is the case. Then, in general, my experience has been that operators tend to be initimidating. And finally, creating that operator should be a straightforward addition. 

## Illustration: MNIST Convolutional Neural Network

Let's make this less abstract, by applying it to one concrete example, the [C# example CNN model on the MNIST digit recognition problem][3].

I won't attempt to explain in detail what each layer does, because this isn't the main point here (see [this page for a good overview][4]). I will also leave some code details out, for the same reason. The entire code is available [here][5], in the `CNTK.Sequential.fsx` and `examples/MNIST-CNN.Seq.fsx` files.

If you inspect the C# sample, you'll notice that the prediction model combines a few operations:

- Input scaling,
- Convolution, using a Kernel and a number of output features,
- Activation (ReLU),
- Pooling, computing the Max value over a Window, using a Stride,
- Dense layer, with a given number of neurons.

What we need then is to express each of these as a `Computation`, which is not overly complicated. Here are 2 examples, one trivial, one slightly less so:

``` fsharp
[<RequireQualifiedAccess>]
module Activation = 

    let ReLU : Computation = 
        fun device ->
            fun input ->
                CNTKLib.ReLU(input)

[<RequireQualifiedAccess>]
module Conv2D = 
    
    type Kernel = {
        Width: int
        Height: int
        }

    type Conv2D = {
        Kernel: Kernel 
        InputChannels: int
        OutputFeatures: int
        Initializer: Initializer
        }

    let convolution (args:Conv2D) : Computation = 
        fun device ->
            fun input ->
                let kernel = args.Kernel
                let convParams = 
                    device
                    |> Param.init (
                        [ kernel.Width; kernel.Height; args.InputChannels; args.OutputFeatures ], 
                        DataType.Float,
                        args.Initializer)

                CNTKLib.Convolution(
                    convParams, 
                    input, 
                    shape [ 1; 1; args.InputChannels ]
                    )           
```

I can then use these "blocks" to define my model:

``` fsharp
let network : Computation =
    Layer.scale (float32 (1./255.))
    |> Layer.stack (Conv2D.convolution 
        {    
            Kernel = { Width = 3; Height = 3 } 
            InputChannels = 1
            OutputFeatures = 4
            Initializer = Custom(CNTKLib.GlorotUniformInitializer(0.26, -1, 2))
        }
        )
    |> Layer.stack Activation.ReLU
    |> Layer.stack (Conv2D.pooling
        {
            PoolingType = PoolingType.Max
            Window = { Width = 3; Height = 3 }
            Stride = { Horizontal = 2; Vertical = 2 }
        }
        )
    |> Layer.stack (Conv2D.convolution
        {    
            Kernel = { Width = 3; Height = 3 } 
            InputChannels = 4 // matches previous conv output
            OutputFeatures = 8
            Initializer = Custom(CNTKLib.GlorotUniformInitializer(0.26, -1, 2))
        }
        )
    |> Layer.stack Activation.ReLU
    |> Layer.stack (Conv2D.pooling
        {
            PoolingType = PoolingType.Max
            Window = { Width = 3; Height = 3 }
            Stride = { Horizontal = 2; Vertical = 2 }
        }
        )
    |> Layer.stack (Layer.dense numClasses)
``` 

The syntax could be made even lighter, by supplying good default values for the parameter records. For instance, using:

> Note: the syntax could be made a bit lighter, by supplying good default parameter records, and doing something like `Layer.stack (Conv2D.convolution { defaultConv with OutputFeatures = 4 })`.

I also made some other changes to the original example, to separate more cleanly between model specification and training, and hide some of the gory details. First, I define a specification:

``` fsharp
let imageSize = 28 * 28
let numClasses = 10
let input = CNTKLib.InputVariable(shape [ 28; 28; 1 ], DataType.Float)
let labels = CNTKLib.InputVariable(shape [ numClasses ], DataType.Float)

let network : Computation =
    // omitted for brevity

let spec = {
    Features = input
    Labels = labels
    Model = network
    Loss = CrossEntropyWithSoftmax
    Eval = ClassificationError
    }
```

... and then I configure how to train that particular model on a dataset, specifying what device I want to use for training:

``` fsharp
let ImageDataFolder = Path.Combine(__SOURCE_DIRECTORY__, "../data/")
let featureStreamName = "features"
let labelsStreamName = "labels"

let learningSource: DataSource = {
    SourcePath = Path.Combine(ImageDataFolder, "Train_cntk_text.txt")
    Streams = [
        featureStreamName, imageSize
        labelsStreamName, numClasses
        ]
    }

let config = {
    MinibatchSize = 64
    Epochs = 5
    Device = DeviceDescriptor.CPUDevice
    Schedule = { Rate = 0.003125; MinibatchSize = 1 }
    }

let minibatchSource = textSource learningSource InfinitelyRepeat

let trainer = Learner ()
trainer.MinibatchProgress.Add(basicMinibatchSummary)

let predictor = trainer.learn minibatchSource (featureStreamName,labelsStreamName) config spec
let modelFile = Path.Combine(__SOURCE_DIRECTORY__,"MNISTConvolution.model")

predictor.Save(modelFile)
```

Running that code will go through the entire process of creating a model, training it, and saving it. It works completely from the scripting environment in VS Code, takes less than 100 lines of code, and is, in my opinion, quite readable. 

## Parting notes

Some of the issues I voiced about the current design of the C# / .Net CNTK API (version 2.3.1) were that it was very low-level, didn't make composition easy, and leaked low-level details such as what device to run on. In this post, I presented one of the directions I have been exploring, to 

- Compose layers / computation blocks into a sequential model, and 
- Separate model specification and training, deferring the decision of what device to target.

I consider the code a good sketch - some details need to be refined or improved still, and there are quite possibly some bugs. However, in its current state, it works, and is fairly usable, which is why I added it to `master` in the [`CNTK.FSharp` repository][6]. You can find the [complete code here][5]; the plumbing is in `CNTK.Sequential.fsx`, and the illustration example is in `examples/MNIST-CNN.Seq.fsx`.

What are the limits of this approach? As I see it, the main one is that not every model is sequential. For instance, the LSTM example is not going to fit. This approach does one thing nicely, but doesn't help with composing more complex expressions.

In future posts, I will explore other potential directions. In the meanwhile, I'd love to hear your comments on this. Happy coding :)


[1]: http://brandewinder.com/2017/12/23/baby-steps-with-cntk-and-fsharp/
[2]: https://keras.io/getting-started/sequential-model-guide/
[3]: https://github.com/Microsoft/CNTK/blob/master/Examples/TrainingCSharp/Common/MNISTClassifier.cs
[4]: http://cs231n.github.io/convolutional-networks/
[5]: https://github.com/mathias-brandewinder/CNTK.FSharp/tree/7a2bc73b9c062605f6a91434ad1e56febe2ad9bb
[6]: https://github.com/mathias-brandewinder/CNTK.FSharp
