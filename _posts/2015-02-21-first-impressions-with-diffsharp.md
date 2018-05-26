---
layout: post
title: First impressions with DiffSharp, an F# autodiff library
tags:
- F#
- AutoDiff
- Optimization
- Gradient
---

A few weeks ago, I came across [DiffSharp, an automatic differentiation library in F#][1]. As someone whose calculus skills have always been rather mediocre (thanks Wolfram Alpha!), but who needs to deal with gradients and the like on a regular basis because they are quite useful in machine learning and numerical methods, the project looked pretty interesting: who wouldn’t want exact and efficient calculations of derivatives? So I figured I would take a couple of hours to experiment with the library. This post is by no means an in-depth evaluation, but rather intended as “notes from the road” from someone entirely new to DiffSharp.

<!--more-->

## Basics

Suppose I want to compute the derivative of _f(x) = √ x_ at, say, 42.0. Double-checking Wolfram Alpha confirms that f has derivative _f’(x) = 1 / (2 x √ x)_.

Once DiffSharp is installed via Nuget, we can automatically evaluate f’(x) :

``` fsharp
#r @"..\packages\DiffSharp.0.5.7\lib\DiffSharp.dll"
open DiffSharp.AD.Forward

let f x = sqrt x
diff f 42. |> printfn "Evaluated: %f"
1. / (2. * sqrt 42.)  |> printfn "Actual: %f"

Evaluated: 0.077152
Actual: 0.077152

val f : x:Dual -> Dual
val it : unit = ()
```

First off, obviously, it worked. Without any need for us to perform anything, DiffSharp took in our implementation of _f_, and computed the correct value. This is really nifty.

The piece which is interesting here is the inferred signature of _f_. If I were to remove the line that immediately follows the function declaration, _f_ would have the following signature:

``` fsharp
val f : x:float –> float
```

The moment you include the line `diff f 42. `, the inferred type changes drastically, and becomes

``` fsharp
val f : x:Dual –> Dual
```

This is pretty interesting. Because we call diff on _f_, which expects a `Dual` (a type that is defined in DiffSharp), our function isn’t what we originally defined it to be – and calling _f 42.0_ at that point (for instance) will fail, because 42.0 is a float, and not a Dual. In other words, DiffSharp leverages type inference pretty aggressively, to convert functions into the form it needs to perform its magic.

>Edit: Atilim Gunes Baydin suggested another way around that issue, which is inlining f. The following works perfectly well, and allows to both differentiate f, and use this against floats - Thanks for the input!

``` fsharp
let inline f x = sqrt x
let f' = diff f
f 42.
```

This has a couple of implications. First, if you work in a script, you need to be careful about how you send your code to the F# interactive for execution. If you process the sample code above line by line in FSI, the evaluation will fail, because f will be inferred to be float –> float. Then, you will potentially need to annotate your functions with type hints, to help inference. As an example, the following doesn’t work:

``` fsharp
let g x = 3. * x
diff g 42.
```

As is, _g_ is still inferred to be of type `float –> float`, because of the presence of the constant term, which is by default inferred as a float. That issue can be addressed at least two ways – by explicitly marking x or 3. as dual in g, like this:

``` fsharp
let g x = (dual 3.) * x
let h (x:Dual) = 3. * x
```

That’s how far we will go on this – if you want to dive in deeper, the [Type Inference][2] page discusses the topic in much greater detail

## A tiny example

So why is this interesting? As I mentioned earlier, differentiation is used heavily in numeric algorithms to identify values that minimize a function, a prime example being the [gradient descent algorithm][3]. The simplest example possible would be finding a (local) minimum of a single-argument function: starting from an arbitrary value _x_, we can iteratively follow the direction of steepest descent, until no significant change is observed.

Here is a quick-and-dirty implementation, using DiffSharp:

``` fsharp
let minimize f x0 alpha epsilon =
  let rec search x =
  let fx' = diff f x
  if abs fx' < epsilon
  then x
  else
    let x = x - alpha * fx'
    search x
  search x0
```

> Edit, 3/4/2015: fixed issue in code, using abs fx’ instead of fx’

Because DiffSharp handles the differentiation part automatically for us, with only 10 lines of code, we can now pass in arbitrary functions we want to minimize, and (with a few caveats…), and get a local minimum, no calculus needed:

``` fsharp
let epsilon = 0.000001

let g (x:Dual) = 3. * pown x 2 + 2. * x + 1.
minimize g 0. 0.1 epsilon |> printfn "Min of g at x = %f"

let h (x:Dual) = x + x * sin(x) + cos(x) * (3. * x  - 7.)
minimize h 0. 0.1 epsilon |> printfn "Min of h at x = %f"
```
```
>
Min of g at x = -0.333333
Min of h at x = -0.383727
```

Let’s make sure this is reasonable. _g_ is a quadratic function, which has a minimum or maximum at _–b/2*a_, that is, _–2 / 2 x 3_ - this checks out. As for _h_, inspecting the function plot confirms that it has a minimum around the identified value:

![Wavy function plot]({{ site.url }}/assets/wavy-function-plot.png)

> Edit, 3/4/2015: changed function _h_ to a simpler shape.

## Conclusion

I have barely started to scratch the surface of DiffSharp in this post, but so far, I really, really like its promise. While I limited my examples to single-variable functions, DiffSharp supports multivariate functions, and vector operations as well. The way it uses type inference is a bit challenging at first, but seems a reasonable price to pay for the resulting magic. My next step will probably be a less tiny example, perhaps a logistic regression against realistic data. I am very curious to try out the algebra bits – and also wondering in the back of my head how to best use the library in general. For instance, how easy is it to construct a function from external data, and turn it into the appropriate types for DiffSharp to work its magic? How well does this integrate with other libraries, say, Math.NET? We’ll see!

In the meanwhile, I’d recommend checking out the [project page][1], which happens to also be beautifully documented!

[1]: http://gbaydin.github.io/DiffSharp/
[2]: http://gbaydin.github.io/DiffSharp/gettingstarted-typeinference.html
[3]: http://en.wikipedia.org/wiki/Gradient_descent
