---
layout: post
title: "Study notes: automatic differentiation (part 1)"
tags:
- F#
- Algorithms
- AutoDiff
---

A few months ago, I came across the [microgpt post by Andrej Karpathy][1], 
where he implements a GPT model from scratch, in "a single file of 200 lines of 
pure Python with no dependencies". This is a super nice post, and something I 
was looking for - a bare-bones GPT model where nothing is hidden by libraries. 
My understanding of GPT models is hand-wavy, so I was excited to be able to 
step through everything, and understand the mechanics better.  

Unsurprisingly, a good part of microgpt is dedicated to an implementation of 
autograd, that is, a version of [automatic differentiation][2]. The topic is 
not new to me (I have used the awesome [DiffSharp][3] before), but, as I looked 
through microgpt, I realized that, beyond the fact that it relies on the 
[chain rule][4] to propagate derivatives in composite functions, I was not 
entirely clear on how exactly that worked.  

I also took a look at the nice series [MicroGPT in F#, by Jonas Lara][5]. That 
series starts by mimicking the original Python closely, which from a certain 
angle is great, and helped me some. However, I realized I was more interested 
in understanding automatic differentiation than in how it is implemented in 
microgpt, so I figured it was time for another of my side-quests: taking a stab 
at implementing autodiff from scratch, in F#, as a learning exercise.  

This is, of course, rather pointless. [DiffSharp][3] already exists, and it is 
both very impressive and very complete. My goal here is not to replace it. I 
want to attempt to write a library from zero, try out ideas, see what works and 
what doesn't, and learn from the mistakes as I go, hopefully gaining a better 
understanding of automatic differentiation in the process.  

With that preamble out of the way, let's get this side quest started!  

<!--more-->

## Where to start?

One way I like to approach that type of situation is to start by tackling the 
smallest possible problem that could help me learn something. In this case, the 
key problem is to evaluate the derivative of a function at a value. So let's 
ignore for a moment the larger picture, with things like back-propagation in a 
neural network and all that jazz, and focus on the derivative of a function.  

The narrowest form of that problem would be to compute the derivative of a 
single argument function, a function that takes a float as an input, and 
returns a float. This sounds like a good building block. Once we have that, we 
will assess where we are and take it from there.  

## Derivatives: a quick recap

Let's begin with a quick refresher on derivatives, without getting too formal 
about it, to set the stage for the next steps. We'll go over some examples the 
old fashioned way, by hand.  

Loosely, when we talk about the derivative of a function `f(x)`, we are 
interested in how much the value of `f(x)` changes if we increase `x` by "just 
a little".  

The derivative of `f(x)` is typically written as either `f'(x)` ("f prime"), or 
`df/dx`. Both signify that we are interested in how `f` changes 
_with respect to_ `x`, that is, when the input `x` changes "a little". `f'(x)` 
can be defined as the limit of `(f(x + h) - f(x)) / ((x + h) - x)` when `h` 
tends to zero: `f(x + h) - f(x)` measures the change in the output, while 
`(x + h) - x` (or, more simply, just `h`) measures the change in the input. In 
the `df/dx` notation, `df` and `dx` similarly represent the change in `f` and 
in `x`.  

So `f'(x)` can be thought of as the rate of change of `f`, for various values 
of `x`.  

Let's go over some relevant facts about derivatives that we will need along the 
way.  

The simplest function we could start with is something like this:  

`f(x: float) = 42.0`  

The derivative of that function is `f'(x: float) = 0.0`. What this means in 
practice is that if I take any value for `x`, increasing the value of `x` will 
change the value of `f(x)` by `0.0`, that is, not at all. If the function 
is a constant, there is no change, and the derivative is `0.0`.  

A tad more interesting, `f(x: float) = x` has derivative `f'(x: float) = 1.0`. 
Practically, what this means is that increasing `x` by a small number `h` will 
cause `f(x)` to increase by `1.0 * h`.  

### Operators

Derivatives follow a few simple rules when using common operators such as `+`, 
`-`, `*` and `/`. As an example, for addition:  

if `h(x) = f(x) + g(x)`, then `h'(x) = f'(x) + g'(x)`.  

So, taking our previous example, the derivative of `f(x) = x + 42.0` is 
`f'(x) = 1.0 + 0.0`.  

A more interesting case is the `*` operator, which follows the so-called 
product rule:  

if `h(x) = f(x) * g(x)`, then `h'(x) = f(x) * g'(x) + f'(x) * g(x)`.  

So if `f(x) = x * x`, then `f'(x) = x * 1.0 + 1.0 * x = 2.0 * x`. Note that in 
this case, `f'` depends on `x`. The rate of change of `f` becomes larger as `x` 
increases, indicating that the function increases faster and faster.  

The other operators similarly follow well-established rules, which we will not 
cover here.  

### Function Composition

The other key piece is the so-called **chain rule**, which describes how to 
determine the derivative of functions that are composed:  

if `h(x) = g(f(x))`, then `h'(x) = g'(f(x)) * f'(x)`.  

This, together with the rules around operators, allows us to derive pretty much 
any function. As an example, consider the function `h(x) = g(x + 42.0)`. Naming 
`f(x) = x + 42.0`, we recognize `h(x) = g(f(x))` and can apply the chain rule:  

`h'(x) = g'(f(x)) * f'(x)`.

As `f'(x) = 1.0`, this becomes `h'(x) = g'(x + 42.0)`.  

The nice thing here is that if you know the derivative of `g`, then you are 
done. For instance, it happens that the derivative of `sin(x)` is `cos(x)`, so 
by substitution, if `h(x) = sin(x + 42.0)`, then `h'(x) = cos(x + 42.0)`. All 
you need is pairs of functions and their known derivatives, and you can compose 
and derive arbitrarily deeply nested functions.  

## Take 1: incorrect but instructive

My first attempt took me down a path that I ended up abandoning. It was helpful 
though, so let's talk about it. 

> You can find the [full code of this version here][6].

### Representing functions

Computing derivatives, in particular using the chain rule, involve taking 
"known shapes", and transforming them into other shapes, so I figured I would 
try representing a function of one variable x using discriminated unions, like 
so:  

``` fsharp
type Expr =
    | X
    | Val of float
    | Add of (Expr * Expr)
    | Mul of (Expr * Expr)
    // more operators, omitted for brevity
    | Sin of Expr
    | Cos of Expr
    // more known functions, omitted for brevity
```

`X` and `Val` represent the function variable, and constants. We add operators 
like `Add`, `Mul` and the like, and various functions like `Cos`, `Sin`, which 
allows us to represent a function such as `sin(x + 42.0)` as an expression, 
`Sin(Add(X, Val 42.0))`.  

Because `Add(X, Val 42.0)` is awkward, I also added operators to `Expr`, like 
so, where `lhs` and `rhs` stand for "left-hand side" and "right-hand side":  

``` fsharp
type Expr =
    | X
    // omitted for brevity
    with
    static member (+) (lhs, rhs) =
        Add (lhs, rhs)
    static member (+) (lhs, rhs: float) =
        Add (lhs, Val rhs)
    static member (+) (lhs: float, rhs) =
        Add (Val lhs, rhs)
    // more operators
```

This allows us to seamlessly use `X + 42.0`, converting that in the background 
to `Add(X, Val 42.0)`: `Sin(X + 42.0)` is now a valid expression, and, by using 
the same trick for other operators, we end up with something that isn't looking 
too different from our original function `sin(x + 42.0)`.  

### Evaluation strategy

Can we use these expressions to compute the value of a derivative for some 
value of x? Yes we can.  

One possibility here would be to take the expression, and by applying the rules 
described earlier, compute another expression that is its derivative, and 
evaluate it.  

> If you are interested, I [tried that out here][7].

However, a sentence in the [automatic differentiation Wikipedia page][2] gave 
me pause:  

> Automatic differentiation is distinct from symbolic differentiation and numerical differentiation.

Transforming an expression into another one and evaluating it is more or less 
symbolic differentiation, so it sounded like I was missing something. After 
much reading and re-reading, I realized where the subtle distinction was, in 
part thanks to the section on dual numbers.  

As I understand it, the subtlety is that you can directly evaluate the 
derivative for a value `x`, by directly bubbling up the value of `x` and the 
value of its derivative, without needing an explicit expression for the 
derivative.  

The chain rule `h'(x) = g'(f(x)) * f'(x)` helps see why. If we know what 
both the _value_ of `f(x)` and `f'(x)` are for some value of `x`, then we can 
directly _calculate the value_ `g'(f(x)) * f'(x)`, that is, `h'(x)`. We won't 
know what the expression representing `h'(x)` is, but we can evaluate it.  

Let's take our earlier example of `g(x) = sin(x + 42.0)`. The process of 
evaluating `g'(10.0)` would work this way:  

```
element         value       derivative
x               10.0        1.0
42.0            42.0        0.0
x + 42.0        52.0        1.0 + 0.0
sin(x + 42.0)   sin(52.0)   cos(52.0) * 1.0
```

We start from `x = 10.0`, which has a derivative of `1.0`, and the constant 
`42.0`, which has a derivative of `0.0`, and bubble up, substituting the values 
along the way, always carrying along 2 values.  

That strategy can be directly implemented, along these lines:  

``` fsharp
let rec diff (expr: Expr) (x: float): (float * float) =
    match expr with
    | X -> x, 1.0
    | Val v -> v, 0.0
    | Add (lhs, rhs) ->
        let (valueLhs, diffLhs) = diff lhs x
        let (valueRhs, diffRhs) = diff rhs x
        (valueLhs + valueRhs), (diffLhs + diffRhs)
    // omitted for brevity
    | Sin expr ->
        let valueExpr, diffExpr = diff expr x
        sin valueExpr, (cos valueExpr) * diffExpr
    | Cos expr ->
        let valueExpr, diffExpr = diff expr x
        cos valueExpr, -sin(valueExpr) * diffExpr
    // omitted for brevity
```

`diff` takes in  
- an expression (the function we want to differentiate) and  
- a value `x` (the value where we want to evaluate the derivative),  

and returns a tuple, where the first value is `f(x)` and the second `f'(x)`.  

Does it work? It does:  

``` fsharp
let f = Sin(X + 42.0)
let f' = diff f

let expected = sin(52.0), cos(52.0)
let actual = f'(10.0)

val expected: float * float = (0.986627592, -0.1629907808)
val actual: float * float = (0.986627592, -0.1629907808)
```

## Parting thoughts

That's where I will leave things for part 1! In the next installment, I will go 
over my second attempt, which I liked much better.  

Until then, I mentioned that I considered take 1 "incorrect, but instructive". 
So what did I learn in the process?  

My biggest mental block here was to get over Symbolic Differentiation. Even 
though my approach bubbles up evaluations, as opposed to creating a new 
symbolic expression and then evaluating it, the code begs to be converted to 
symbolic differentiation, and would look much cleaner that way.  

The key insight was the realization that ultimately, what we care about is the 
value of the derivative, and not its expression. By bubbling up pairs of values 
(`f(x)` and `f'(x)`) we can efficiently compute the overall derivative, without 
knowing the explicit expression of the derivative.  

Otherwise, this made me realize there are a few issues that I will need to 
think about down the road. In its current form, the code has 2 composability 
problems:  

- I would like to be able to compute the derivative of a derivative. But as it 
stands, this is not possible. `diff` expects an `Expr` as an input, so to be 
able to differentiate again I would need to return an `Expr`. I could do that 
by separating converting an expression into the expression of its derivative, 
but then what we would have is Symbolic differentiation. This would also lead 
to less efficient code, because it would require multiple passes through the 
expression tree. In general, I need `diff` to return something I can apply 
`diff` to again.  

- I would like to extend the approach from `float -> float` functions, to 
handle functions of many arguments, something like `float [] -> float`, or some 
form of vector. However, the partial derivative of such a function will not 
return a single value, but a vector, with as many values as there are inputs. 
As a result, if I want to support either function composition, or repeated 
differentiation, I will likely need some more general type for the function 
inputs and outputs (something like a tensor?).  

One thing I don't like about this approach is that it's not extensible. If you 
wanted to add a function as a primitive block, you would have to change the 
`Expr` type itself. That being said, fundamentally all you would need to add a 
new block is to supply 2 things: the function and its derivative. It is likely 
possible to do, but the `Expr` route does not make it easy.  

Finally, while writing functions as `Expr` is reasonably close to "normal 
functions", it does require re-writing a function using a DSL. Rather than 
`let expr = Sin(X + 42.0)`, I would like to write `f(x) = sin(x + 42.0)`, and 
be able to derive `f`.  

That's what I have for now! Next time I will still stick to simple functions, 
but try out a different direction.  

[1]: https://karpathy.github.io/2026/02/12/microgpt/
[2]: https://en.wikipedia.org/wiki/Automatic_differentiation
[3]: https://diffsharp.github.io/
[4]: https://en.wikipedia.org/wiki/Chain_rule
[5]: https://jonas1ara.github.io/posts/microgpt-in-fsharp/
[6]: https://codeberg.org/mathias-brandewinder/Galet/src/commit/eeae516577cb25c3b2ff62f2579f2b0fe1adc69e/src/Galet/Galet.fs
[7]: https://codeberg.org/mathias-brandewinder/Galet/src/commit/8323619c3e8d2f285c56349931ea2239b10ecf98/src/Galet/Galet.fs#L3-L65