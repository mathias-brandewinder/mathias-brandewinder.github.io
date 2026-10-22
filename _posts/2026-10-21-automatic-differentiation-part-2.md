---
layout: post
title: "Study notes: automatic differentiation (part 2)"
tags:
- F#
- Algorithms
- AutoDiff
---

In my last post, I began my side quest into [automatic differentiation][1], 
trying to implement it from scratch as a learning exercise, in F#, to 
understand how it works.  

In [part 1][2], I decided to start with the smallest relevant problem I could 
think of, computing the derivative of a function of a single value. Once we get 
that figured out, we will move to bigger functions.  

My first take was to model functions as expressions, using an F# discriminated 
union. This was a useful exercises. First, it worked! I ended up with a 
function `diff` that correctly evaluated the derivative of a function. Then, 
implementing it gave me a chance to refresh my mind on the mechanics of 
derivatives.  

There are a few things I didn't like about that take. First, it requires 
writing functions as expressions, essentially using a DSL, which is a bit 
awkward to use, and not ideal for extensibility. Then, it does not handle 
composition very well. Ideally, I would like to be able to compute the 
derivative of a derivative, and so on. I can achieve that by modifying my 
initial code a little, but that modification is essentially symbolic 
derivation, which is, as I understand it, not automatic differentiation.  

So let's go back to the drawing board, with take 2.  

<!--more-->

## Forward differentiation: bubbling up values  

One insight I gained from take 1 was that by "augmenting" variables to also 
carry the value of their derivatives, you can efficiently compute the 
derivative of chains of functions, by applying the chain rule.  

The chain rule tells us that the derivative of a function  
`h(x) = g(f(x))` is  
`h'(x) = g'(f(x)) * f'(x)`.  

As a result, all you need to compute `h'(x)` for some value `x` is:
- `f(x)` and `f'(x)`,  
- what the derivative of `g` is.  

And because the function variable `x` in `h(x)` has derivative `1` and 
constants have derivative `0`, you can simply _evaluate_ `h'(x)` by bubbling up 
values and their derivatives.  

What you won't have is an explicit expression for `h'`, but you will have a 
function that computes `h'(x)`, presumably fast.  

## Take 2: forward accumulation

The approach I took here is to follow directly the 
[Wikipedia forward accumulation example][3]. We will start by creating a type 
`V`, a struct, to represent a value and its derivative:  

``` fsharp
[<IsReadOnly; Struct>]
type V (x: float, dx: float) =
    member this.X = x
    member this.DX = dx
```

> You can find the corresponding [finished code here on Codeberg][4].  

First, we need to express functions, so we can write something like 
`f(x) = sin (x + 42.0)`, operating on `V` instead of `float`. To do that, we 
need operators and "standard" real functions.  

Let's start with operators, so we can add, multiply and the like. As an example 
below, when we add 2 values `v1` and `v2`, we return a value where `X` is 
`v1.X + v2.X` (the result of the addition itself), and `DX`, the derivative 
part, is `v1.DX + v2.DX`, the sum of the derivatives (if `h = f + g`, then 
`h' = f' + g'`). The other operators follow the same pattern, using the 
corresponding rules for the derivative part (product rule, quotient rule, ...):  

``` fsharp
type V (x: float, dx: float) =
    // omitted for brevity
    static member (+) (v1: V, v2: V) =
        V (v1.X + v2.X, v1.DX + v2.DX)
    static member (*) (v1: V, v2: V) =
        V (v1.X * v2.X, v1.X * v2.DX + v2.X * v1.DX)
    // etc...
```

We use the same trick as last time, adding overloads for constants, so we can 
write directly `f (x: V) = x + 42.0`. Because constants have a derivative of 
`0` with respect to `x`, this leads to:  

``` fsharp
type V (x: float, dx: float) =
    // omitted for brevity
    static member (+) (v1: V, v2: float) =
        V (v1.X + v2, v1.DX)
    static member (+) (v1: float, v2: V) =
        V (v1 + v2.X, v2.DX)
    // etc...
```

Next, let's add the functions we want to support. The value `X` is simply the 
result of the operation itself, whereas the derivative part `DX` comes from 
applying the chain rule:  

``` fsharp
type V (x: float, dx: float) =
    // omitted for brevity
    static member Cos (v: V) =
        V (System.Math.Cos v.X, - System.Math.Sin(v.X) * v.DX)
    static member Sin(v: V) =
        V (System.Math.Sin v.X, System.Math.Cos(v.X) * v.DX)
    // etc...
```

At that point, we can write functions that "understand derivatives". Taking the 
same example we used in the previous post, we get the following:  

``` fsharp
let f (x: V) = sin (x + 42.0)
```

How do we get a derivative out of this? The derivative of `x` is `1`, so we 
just need to plug in that value, and let it bubble up. Let's write a `diff` 
function that does just that:  

``` fsharp
let diff (f: V -> V) (x: float): float =
    f (V (x, 1.0))
    |> fun v -> v.DX
```

We can now evaluate the derivative `f'` for `x = 10`:  

``` fsharp
let f (x: V) = sin (x + 42.0)
let f' = diff f
f' 10.0

> val it: float = -0.1629907808
```

This matches the result we expect, `cos (10.0 + 42.0)`. Success!  

## Comparison with the first attempt

The goal here was to try a different direction from take 1, and see where that 
lead us. From my standpoint, "take 2" looks much better than "take 1".  

Functions now look like functions, and don't require using a custom DSL. The 
only requirement is to annotate `x` as `V` in the function, and everything 
works as it would for a regular function over floating point values. Evaluation 
is about twice as fast as it was before. And adding your own functions is 
fairly easy: you can just write your own, like 
`let myFunction (v: V) = V(v.X, 42.0)`, plug that into functions and it just 
works.  

On the downside, we cannot compute the derivative of a derivative. This is 
pretty obvious from the signature of `diff`: `(V -> V) -> (float -> float)`. 
Once we differentiate, we are back to functions that only understand floats. 
This is a major problem - what we would need is something that looks like this: 
`diff: (V -> V) -> (V -> V)`.  

Another downside is that, while `f (x: V) = x + 1.0` looks like a normal 
function, using it as a "plain" function is very awkward. I would like to be 
able to just ask for the value of `f(1.0)`, but I can't. To do that, I need to 
pass in a `V`, with some value for `dx` - and I will get back `f(1.0)`, as well 
as a derivative value computed using the `dx` value we passed in, which could 
be entirely wrong. This is also not ideal.  

## Parting thoughts

We are clearly not done here; in particular, not being able to differentiate 
repeatedly is a big issue. However, Rome wasn't built in a day, and this has 
been a long week for me, so this is where I will stop for today.  

In general, this approach seems much more promising than my first take. At the 
very least, this is not symbolic differentiation anymore. While it feels like I 
am on the right path, I am getting this nagging feeling that I am still missing 
something, related to the repeated differentiation problem.  

But this can wait until next episode! In the meantime, happy coding, everyone.  

> You can find the corresponding [finished code here on Codeberg][4].  

[1]: https://en.wikipedia.org/wiki/Automatic_differentiation
[2]: https://brandewinder.com/2026/10/07/automatic-differentiation-part-1/
[3]: https://en.wikipedia.org/w/index.php?title=Automatic_differentiation&oldid=1373407057#Forward_accumulation
[4]: https://codeberg.org/mathias-brandewinder/Galet/src/branch/main/src/Galet/Galet.fs#L3-L50
