---
layout: post
title: First look at the new DiffSharp
tags:
- F#
- Algorithms
- Optimization
- Machine-Learning
- AutoDiff
- Maximum-Likelihood
---

This post is intended as an exploration of [DiffSharp][1], an [Automatic Differentiation, or autodiff][2] 
F# library. In a nutshell, autodiff allows you to take a function expressed in code - in our case, in F# - 
and convert it in an F# function that can be differentiated with respect to some parameters.  

For a certain niche population, people who care about computing gradients, this is very powerful. Basically, 
you get gradient descent, a cornerstone of machine learning, for free.

DiffSharp has been around for a while, but has undergone a major overhaul in the recent months. I hadn't had 
time to check it out until now, but a project I am currently working on gave me a great excuse to look into these 
changes. This post will likely expand into more, and is intended as an exploration, trying to figure out 
how to use the library. As such, my code samples will likely be flawed, and should not be taken as guidance. 
This is me, getting my hands on a powerful and complex tool and playing with it!

With that disclaimer out of the way, let's dig into it. In this installment, I will take a toy problem, 
a much simpler version of the real problem I am after, and try to work my way through it. Using DiffSharp for 
that specific problem will be total overkill, but will help us introduce some ideas which we will re-use 
later, for the actual problem I am interested in, estimating the parameters of competing random processes 
using [Maximum Likelihood Estimation][3].

```
Environment: dotnet 6.0.302 / Windows 10, DiffSharp 1.0.7
```

## An unfair coin

Let's consider a coin, which, when tossed in the air, will land sometimes Heads, sometimes Tails. Imagine 
that our coin is unbalanced, and tends to land more often than not on Heads, 65% of the time:  

``` fsharp
type Coin = {
    ProbabilityHeads: float
    }

let coin = { ProbabilityHeads = 0.65 }
```

Supposed now that we tossed that coin in the air 20 times. What should we expect?  

<!--more-->

Well, it depends. We could observe 12 heads, or 15, or even 20 or 0. Let's simulate such a run, representing 
Heads as 1, and Tails as 0:  

``` fsharp
open System

let simulate (rng: Random, n: int) (coin: Coin) =
    Array.init n (fun _ ->
        if rng.NextDouble() <= coin.ProbabilityHeads
        then 1
        else 0
        )

let seed = 1
let rng = seed |> Random

let sample = coin |> simulate (rng, 20)
```

... which gives us a particular sequence we might observe:

``` fsharp
val sample: int[] =
  [|1; 1; 1; 0; 0; 1; 1; 0; 1; 1; 1; 1; 1; 0; 0; 0; 1; 1; 0; 0|]
```

For that particular example, we observe 12 Heads and 8 Tails:

``` fsharp
> sample |> Array.countBy id;;
val it: (int * int)[] = [|(1, 12); (0, 8)|]
```

Nothing earth shattering so far. Now let's consider this question: if all you saw was the 
sample we generated, should you believe that the coin is fair, or unbalanced?  

That question can be restated slightly differently: based on the sample you are observing, 
what is the most likely value for `p`, the probability that the coin we used lands Heads? Is it 
`50%` (a fair coin), or something else?

> Note: we will ignore anything like prior beliefs you might have about that coin.

Your guess for that value is probably `60%`, 12 Heads / (12 Heads + 8 Tails), and it would 
be a pretty good guess, which happens to be well founded theoretically. A more interesting 
question perhaps then is, why would this be a good guess?

## Maximum Likelihood Estimation

There is more that one way you could arrive to that value of `60%`. Let's start from a few 
considerations. First, any coin could have given that specific sequence, but some coins are 
much less likely to generate it.

Given a particular coin with a probability `p` of landing Heads, what is the probability of 
observing a particular sequence of Heads and Tails? For an isolated coin toss, the probability 
of observing Heads is `p`, and Tails is `1.0 - p`.  

Now, quick recap: the probability of 2 independent events is the product of their 
probabilities, so for instance the probability of observing `Heads, Tails` with that coin 
would be `P(Heads) * P(Tails)`, that is, `p * (1.0 - p)`. By extension, assuming that each 
coin toss in the sequence is independent from the others, the probability of the whole 
sequence (the joint probability) becomes the product of the probabilities of each individual result.  

So, given a particular sequence, and a possible coin, we can compute the probability to 
observe that sequence, like so:  

``` fsharp
let probabilityOfOutcome outcome coin =
    if outcome = 1
    then coin.ProbabilityHeads
    else 1.0 - coin.ProbabilityHeads

let probabilityOfSequence sample coin =
    sample
    |> Array.map (fun outcome ->
        probabilityOfOutcome outcome coin
        )
    |> Array.reduce (*)
```

We can now answer the question: given any possible coin that we could find in the universe, 
how likely is it that this particular coin would have generated the sample we observed:  

``` fsharp
{ ProbabilityHeads = 0.5 } |> probabilityOfSequence sample
val it: float = 9.536743164e-07

{ ProbabilityHeads = 0.6 } |> probabilityOfSequence sample
val it: float = 1.426576072e-06
```

It is more likely that a coin with `p = 0.6` generated our sample, than a coin with `p = 0.5`. 
This leads to an approach: out of all the values of `p` that could have generated our sample, 
our **parameter**, pick the one that is the most likely to have generated the sample. This is, in 
essence, Maximum Likelihood Estimation.  

Numerically, how could we go about this? As a first pass, we could perform a grid search. 
Try out many possible coins that could have generated that sample, and pick the one that gives 
us the highest likelihood, like so:

``` fsharp
[ 0.05 .. 0.05 .. 0.95 ]
|> List.map (fun p ->
    let coin = { ProbabilityHeads = p }
    p, probabilityOfSequence sample coin
    )

val it: (float * float) list =
  [(0.05, 1.619678787e-16); (0.1, 4.3046721e-13); (0.15, 3.535464773e-11);
   (0.2, 6.871947674e-10); (0.25, 5.967194738e-09); (0.3, 3.063651608e-08);
   (0.35, 1.076771087e-07); (0.4, 2.817928043e-07); (0.45, 5.773666325e-07);
   (0.5, 9.536743164e-07); (0.55, 1.288404948e-06); (0.6, 1.426576072e-06);
   (0.65, 1.280868763e-06); (0.7, 9.081268533e-07); (0.75, 4.833427738e-07);
   (0.8, 1.759218604e-07); (0.85, 3.645500658e-08); (0.9, 2.824295365e-09)]
```

Based on this analysis, trying out a subset of all the coins of the universe, we see that the 
most likely candidate is a coin with `p = 0.6`, which gives us a likelihood of `1.426576072e-06`.

Before going further, let's look at a small technical issue. Our sample here has only 20
observations, and yet the probabilities we computed are already vanishingly small. This should 
not come as a surprise: we are multiplying together probabilities, which by definition are 
smaller than `1.0`, so their product will becoming smaller and smaller as the sample size 
increases. It is not a problem just yet in our small example, but if we were to run the same 
calculation on large samples, we are going to run into precision errors, fast. Can we avoid this? 

We can, with a small trick. The `log` of a product is the sum of the individual logs, that is, 

```log(p1 * p2 * ... pn) = log(p1) + log(p2) + ... + log(pn)```

Why is this useful? First, we are dealing with probabilities, which are positive, so we can 
safely compute their `log`. Then, what we are interested here is the parameter `p` that gives us 
the largest likelihood, and, as the `log` function is increasing, it will not change their ranking.  

So, instead of computing the likelihood of a sample given parameters, we will transform it into 
its **log-likelihood**, which will turn everything into a sum instead of a product:  

``` fsharp
let logLikelihood sample coin =
    sample
    |> Array.sumBy (fun outcome ->
        probabilityOfOutcome outcome coin
        |> log
        )
```

We can now re-do our grid search:

``` fsharp
[ 0.05 .. 0.05 .. 0.95 ]
|> List.map (fun p ->
    let coin = { ProbabilityHeads = p }
    p, logLikelihood sample coin
    )

val it: (float * float) list =
  [(0.05, -36.35913364); (0.1, -28.47390524); (0.15, -24.06559125);
   (0.2, -21.09840336); (0.25, -18.93698891); (0.3, -17.3010732);
   (0.35, -16.04412882); (0.4, -15.08209377); (0.45, -14.36478836);
   (0.5, -13.86294361); (0.55, -13.56210558); (0.6, -13.46023334);
   (0.65, -13.56797199); (0.7, -13.91188176); (0.75, -14.54253976);
   (0.8, -15.55322592); (0.85, -17.12718703); (0.9, -19.68500693)]
```

The conclusion remains the same, but we got rid of the vanishingly small numbers problem.  

Now what?

First, let's be clear: what I will do next is overkill and a bit silly. The correct estimator 
**is** the number of Heads divided by the number of coin tosses. We could attempt to prove it 
and be done with this problem, with an efficient algorithm, just dividing 2 numbers.  

Indead, what I will do is, in the immortal words of my high school math teacher, use a Jackhammer 
to push in a thumbtack. My motivation here is two-fold. I want to build up towards an approach 
that will work for more complex situations than "just coin tosses". The approach will be absurd 
for the problem at hand, but will help prepare the ground for more general problems, where the 
maximum likelihood **is** hard to work with, and does not have a neat, obvious solution. Then, 
by doing so, I will have a great excuse to apply DiffSharp.  

With that out of the way, let's grab that Jackhammer and get to work :)  

## Implementing Maximum Likelihood Estimation

The grid search approach has the benefit of being simple, and pretty effective in this case. 
However, it has limitations. First, we are testing a small subset for the values of our 
parameter `p`. What if the best value was `0.6238432`? Then, this will not scale well for more 
complex problems, which might have more than just one parameter. The space of values we would 
have to explore will increase as a power of the number of parameters, making our search very 
inefficient.  

As an alternative, we could use Gradient Descent, or, rather, Gradient Ascent.

What we are trying to do here is to find the value of the parameter `p` which gives us the 
largest log-likelihood value for the sample. We have a function `log likelihood(p, sample)`, and 
we want to maximize it. One way of doing that is gradient ascent:

- Take a starting value of `p`, perhaps `p_0 = 0.5`
- Compute the derivative of `log likelihood(p_0, sample)`, with respect to `p`
- If the derivative is positive, increasing `p` from `p_0` will increase the log likelihood
- If the derivative is negative, decreasing `p` from `p_0` will increase the log likelihood
- Update `p` to `p_1 = p_0 + small constant * derivative(p_0)`, i.e. take a small step to increase 
the log likelihood
- rinse & repeat, starting from `p_1`

The only difficulty here is the step "Compute the derivative of `log likelihood(p_0, sample)`, with respect to `p`". 
This is where DiffSharp comes in.

Let's do this, and use DiffSharp at last. All we need to do here is express the log likelihood 
function in a way that DiffSharp can work with. If we have that, then we can let it do the heavy 
lifting and compute the derivatives for us.

> Note: this part is mostly lifted from the [differentiable programming DiffSharp code sample][4]. 
I took the sample, and tried to remove as much as I could to figure out what was happening.  

First, let's load DiffSharp in our scripting environment:

``` fsharp
#r "nuget: DiffSharp-cpu"
open DiffSharp
open DiffSharp.Model
```

The first element will be to create a function that we can differentiate, and use to compute 
a log likelihood. This is what I ended up doing:

``` fsharp
let differentiable 
    (parameters: seq<Parameter>)
    (f: 'Input -> 'Output) =
        Model<'Input, 'Output>.create [] parameters [] f

let probabilityModel () =
    let init = { ProbabilityHeads = 0.5 }
    let parameter =
        init.ProbabilityHeads
        |> dsharp.scalar
        |> Parameter
    differentiable
        [ parameter ]
        (fun outcome ->
            if outcome = 1
            then parameter.value
            else 1.0 - parameter.value
            )
```

The `differentiable` function is a small utility wrapper. Its purpose is to take a function `f`, 
and connect it to a list of `Parameter`, returning a `Model`, which wraps the original function, 
but also knows which parameters DiffSharp can use for differentiation.  

The `probabilityModel ()` function illustrates this, creating the core model we will use. We start 
with an initial value, a fair coin that has a `50%` probability of landing Heads. That probability 
is the `Parameter` we want to "manipulate", so we create a `Parameter` from it, using its 
constructor.  

Note how we convert the probability, a `float`, using `dsharp.scalar`. The core data model for 
DiffSharp is tensors. As a first approximation, think of a `Tensor` as an `Array`, but an array that 
could be a regular Array, or an Array2D, or an array of any dimension. The `Parameter` constructor 
expects a `Tensor`, which is what we do: `dsharp.scalar` creates a `Tensor` of dimension 0, a 
single value.

We instantiate a `Model` next: we pass in our single `Parameter`, and create on the fly a function 
that takes an integer, the coin toss outcome we observed. If that outcome is `1`, we return `p`, 
the current probability parameter in our model, otherwise we return `1.0 - p`. In other words, we 
more or less replicated our earlier function `probabilityOfOutcome`, with one nuance: we declared 
that there was one `Parameter`, the probability, that could be changed and used for differentiation.  

Now let's write a function to maximize the log likelihood of a model! That part is more or less 
directly lifted up from the DiffSharp code sample, with minor modifications:

``` fsharp
type Config = {
    LearningRate: float
    MaximumIterations: int
    Tolerance: float
    }

let maximizeLikelihood (config: Config) sample (density: Model<_,_>) =

    let logLikelihood (density: Model<_,_>) =
        sample
        |> Array.sumBy (fun outcome ->
            density.forward outcome
            |> dsharp.log
            )

    let tolerance =
        config.Tolerance
        |> dsharp.scalar

    let rec learn iteration =
        // evaluate the log likelihood and propagate back to density
        density.reverseDiff()
        let evaluation: Tensor = logLikelihood density
        evaluation.reverse()
        // update the parameters of density
        let p = density.parametersVector
        density.parametersVector 
            <- p.primal + config.LearningRate * p.derivative
        printfn $"Iteration {iteration}: Log Likelihood {evaluation}, Parameters {p}, Updated: {density.parametersVector}"
        // stop iterating, or keep going
        if 
            dsharp.norm p.derivative < tolerance 
            || 
            iteration >= config.MaximumIterations
        then density.parametersVector
        else learn (iteration + 1)
    learn 1
```

The `Config` type is simply a record storing configuration parameters tidily in one place.  

The interesting part is what happens in the `maximizeLikelihood` function. That function expects 
3 arguments: the configuration, a sample (in our case, an array of 0s and 1s), and `density`, a DiffSharp `Model` 
that will return the probability density of observing a particular individual outcome in the sample, 
given its current parameters.  

First, we create the `logLikelihood` function: given a `Model`, we iterate over the sample, and 
for each observation / outcome, we use `density.forward` to compute the probability of observing 
that outcome. The result is a tensor, which we convert to a log using `dsharp.log` - and we sum all 
that together: we have the log-likelihood of observing our sample, given a `Model`.

The recursive `learn` function is where Dark Magic happens. What I _think_ is happening here goes 
along these lines. `density.reverseDiff()` declares that the `density` model is now open 
to accept updates. We compute `evaluation` using `logLikelihood` and the current model, 
and (with a lot of hand-waving), `evaluation.reverse()` propagates back the relevant partial 
derivatives information to the parameters of `density`, our model.

The next line is a direct implementation of gradient update: we replace the values of the model parameters, 
by their current value (primal), plus a small step (the learning rate) towards the derivatives:

``` fsharp
density.parametersVector <- p.primal + config.LearningRate * p.derivative
```

And that's pretty much it - the rest of the function either terminates if the maximum number of 
iterations has been reached or the change is smaller than some tolerance threshold, or repeats the update.

Does it work? Let's try it out. All we need at that point is to bolt the pieces together:

``` fsharp
let config = {
    LearningRate = 0.01
    MaximumIterations = 50
    Tolerance = 0.01
    }

probabilityModel ()
|> maximizeLikelihood config sample
```

... which will result in the following:

```
Binding session to 'C:/Users/mathias/.nuget/packages/diffsharp.backends.reference/1.0.7/lib/netstandard2.1/DiffSharp.Backends.Reference.dll'...
Iteration 1: Log Likelihood tensor(-13.8629):rev, Parameters tensor([0.5000]):rev, Updated: tensor([0.5800])
Iteration 2: Log Likelihood tensor(-13.4767):rev, Parameters tensor([0.5800]):rev, Updated: tensor([0.5964])
Iteration 3: Log Likelihood tensor(-13.4608):rev, Parameters tensor([0.5964]):rev, Updated: tensor([0.5994])
Iteration 4: Log Likelihood tensor(-13.4602):rev, Parameters tensor([0.5994]):rev, Updated: tensor([0.5999])
Iteration 5: Log Likelihood tensor(-13.4602):rev, Parameters tensor([0.5999]):rev, Updated: tensor([0.6000])
```

The gradient update stops after 5 iterations, with an estimate of `p = tensor([0.6000])`.

## Conclusion and Parting Notes

This is where I will stop for today. As is probably clear from my comments in the DiffSharp part, 
I will need to do some more digging. However, with some heavy hand-waving... we did a thing! 
And the thing worked! And all in all, it was fairly easy to get it working.

For the next installment, I plan to expand on what we did here, but on a "real" problem, survival 
analysis, where computing the log likelihood and its gradient are much trickier.

In the meantime, here are a few thoughts early in this journey:

Pretty Printer bug? I strongly suspect that there is a bug somewhere around pretty-printers in the version 
of DiffSharp I am using here, version `1.0.7`. I haven't had time to look at the source code yet, but I 
experienced multiple exceptions that took down the entire F# scripting environment / process. These seem 
to occur around displaying a Model. As a workaround, I avoided returning models in scripts, which is why 
`probabilityModel ()` takes a `unit` argument in the code above :)

Tensors: I suspect it will take a bit for me to get used to Tensors everywhere. On one hand, using 
tensors makes a lot of practical sense in this domain. Tensors provide a flexible abstraction for representing 
things like vectors, matrices, numbers, and more - and this the bread-and-butter of numeric analysis. 
On the other hand, as a result, everything takes a Tensor and returns a Tensor, without much hinting at what 
tensor shape might actually work. The flexibility seems to come at the expense of some clarity, and some 
runtime errors.  

Along similar lines, I don't have a good grasp yet of what behaviors I should expect from Tensors. 
As a small example, as far as I can tell, `tensor |> dsharp.log` will apply the log function to 
every element of the tensor, but `tensor |> dsharp.map (dsharp.log)` appears to do the same. It's not difficult 
to figure out what is going on here, and I suspect the first version is "better", but this also hints at 
how tensors and arrays are different. Maybe I will do a post just on tensors and what I understand 
about them at some point.

Anyways, hope you found this post interesting! [Ping me on Twitter][4] if you have comments 
or questions, and... happy coding!

[1]: https://diffsharp.github.io/
[2]: https://en.wikipedia.org/wiki/Automatic_differentiation
[3]: https://en.wikipedia.org/wiki/Maximum_likelihood_estimation
[4]: https://github.com/DiffSharp/DiffSharp/blob/dev/examples/differentiable_programming.fsx