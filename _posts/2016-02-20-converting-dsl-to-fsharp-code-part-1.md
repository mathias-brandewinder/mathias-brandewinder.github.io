---
layout: post
title: Converting a DSL to Executable F# Code On-the-Fly, Part 1
tags:
- F#
- DSL
- FParsec
---

I have had a fun problem to solve for work recently. Suppose you have an application, happily running in production. Imagine that application is computing some result, based on rules. Perhaps you are computing taxes for customers, or the cost of a type of product. Now, your end-user wants the ability to change the application behavior at run time, without having to stop the application. To spice things up a bit, the end-user is not a developer. He is not particularly interested in learning our favorite programming language, and wants to specify that function in a language close to what he speaks, with no tools beyond Notepad available.

To keep it simple, for illustrations purposes, let's imagine that our application is simply taking a number (a float), and computing something, like f(x) = 2.0 * x + 1.0. What we want is to be able to change what function is used, and replace it with any arbitrary function `f`, like f(x) = x * x + 3.0, or f(x) = 42.0, without modifying the code of the application itself. In this post and the next, I'll explain how I approached it.

<!--more-->

In a nutshell, the approach involves breaking the problem into the following steps:

* Write code using a human-friendly external DSL,
* Parse that code into an intermediate F# representation with FParsec,
* Interpret it to produce a runnable F# function,
* Run it :)

You can find [the code for this post here as a gist][1]

> The approach I will show is not necessarily original, and there might be better ways to do this. This is mostly me learning and documenting a technique new to me, which I found interesting. I hope you find something in there that might be useful to you, or inspire ideas!

## Introduction

We will start with a fake application, where the function is hard-coded, and progressively refactor it towards a model where we can replace the code. Our starting point will be this program, modeled as a class:

``` fsharp
type Program () =

    let f (x:float) = 2.0 * x + 1.0

    member this.Run (x:float) =
        let result = f x
        printfn "Result: %.2f" result
```

We can run this in a script, creating an instance of the Program and calling it:

``` fsharp
let program = Program()
program.Run(10.0)

>
Result: 21.00
```

In the end, what we want to achieve is a modified program, where we can pass the "code" we want to run as a string, and do something along these lines:

``` fsharp
Program.run (10.0, "add(1,mul(2,x))");;

>
Result: 21.00
```

This example is of course slightly simpler that the real one. However, if we get to that point, we have solved the broader problem: the code we are passing in as a raw string could come from anywhere, we could for instance read it from a text file, or a text box on a screen.

Note that the "code" we are passing in, `add(1,mul(2,x))`, is using our own domain specific language, not F#. You could argue that this particular DSL is not the best we could do, and you would be right. Our user would probably prefer to write `2 * x + 1`. The reason we picked the other, more cumbersome syntax, is because it will make coding a bit easier. We could support the second one, but this would require more code, dealing with pesky problems like operator precedence, without adding much to the broader point.

## Refactoring using functions

The first step we will take is to extract out the hard-coded function `f`. If we want to be able to inject different functions into our program, we need to be able to pass that in as an argument. That's fairly straightforward:

``` fsharp
type Program () =

    member this.Run (x:float,f) =
        let result = f x
        printfn "Result: %.2f" result
```

We can now pass in any function `f`, as long as it takes a single float as an input, and returns a single float:

``` fsharp
let program = Program()
program.Run(10.0, fun (x:float) -> 2.0 * x + 1.0)
program.Run(10.0, fun (x:float) -> x * x + 3.0)

>
Result: 21.00
Result: 103.00
```

Progress! Note how we didn't have to specify anything about `f` in the `Run` method. If you inspect `Run`, you will see that it has the following signature: `member Run : x:float * f:(float -> float) -> unit`; `f` is a function that expects a float, and returns a float. As long as we pass a function with a matching signature, we are good to go:

``` fsharp
program.Run(10.0, fun (x:float) -> System.TimeSpan.FromMinutes(x).TotalSeconds)

>
Result: 600.00
```

## Modeling expressions

The next step is where things become a bit trickier. What we need now is to take a string, and convert it into an executable F# function with signature `float -> float`. We will break that into 2 steps: transforming the string into our own F# representation of the language we want to support, and transforming that into an F# function. While this might seem like an un-necessary step, hopefully it will become clear as we go why this is actually a good idea. Let's start with the second step.

What are we trying to do here? We are trying to model the body of a function, where we can find 4 different things: a variable X, constant values, and 2 operations, add and multiply. We can add 2 terms together; on the other hand, these terms could be anything: the variable, a constant, or the result of an addition or multiplication, as in add(mul(1,2),3).

There is a convenient way to model this in F#: discriminated unions. I can unify all these cases in a simple type, `Expression`:

``` fsharp
type Expression =
    | X
    | Constant of float
    | Add of Expression * Expression
    | Mul of Expression * Expression
```

This is quite nice. We can now express the body of a function as an expression, like this:

``` fsharp
let expression = Add(Constant(1.0),Mul(Constant(2.0),X))
```

Besides the conciseness and clarity, the beauty here is that we can directly use the domain we modeled, in a type safe manner. We can express arbitrarily complex expressions, using an internal DSL, written in F#. If we try to construct invalid expressions, such as `Add(X,X,X)`, our code won't compile, and we will get hints from the compiler.

## Extracting an executable function from an Expression

We now have a way to represent the body of any function, using a very precise language. In our next post, we will leverage that, and see how we can convert a raw string written by a human into that form. In the meanwhile, we still have a problem: we cannot run these expressions. What we need is to transform such an `Expression` into a function `f`, with the signature `float -> float`.

How can we do that? Let the types guide us. If we encounter a constant, such as `Constant(10.0)`, what should f(x) do? It should return 10.0. In other words, when we encounter an expression `Constant(value)`, we want to return a function `fun (x:float) -> value` (which has the proper signature, `float -> float`). Similarly, if we encounter `X`, our variable, we should return a function `fun (x:float) -> x`.

How about addition? By construction, we know that an expression will be converted to a function of type `float -> float`. All we need to do here is to convert both left and right side arguments of the addition into a function, and return the function that adds their results.

We can wrap this up into a reasonably simple recursive pattern matching:

``` fsharp
let rec interpret (ex:Expression) =
    match ex with
    | X -> fun (x:float) -> x
    | Constant(value) -> fun (x:float) -> value
    | Add(leftExpression,rightExpression) ->
        let left = interpret leftExpression
        let right = interpret rightExpression
        fun (x:float) -> left x + right x
    | Mul(leftExpression,rightExpression) ->
        let left = interpret leftExpression
        let right = interpret rightExpression
        fun (x:float) -> left x * right x
```

And... that's pretty much it. If you check the signature of `interpret`, it has the expected signature, `Expression -> (float -> float)`. Let's check that out, and interpret the expression we defined a bit earlier:

``` fsharp
let expression = Add(Constant(1.0),Mul(Constant(2.0),X))
let f = interpret expression
f(10.)

>
val expression : Expression = Add (Constant 1.0,Mul (Constant 2.0,X))
val f : (float -> float)
val it : float = 21.0
```

## Refactoring using Expression

We can refactor our `Program` now: instead of an F# function, it can accept an `Expression`, and convert it on-the-fly to a function:

``` fsharp
type Program () =

    member this.Run (x:float,expression:Expression) =
        let f = interpret expression
        let result = f x
        printfn "Result: %.2f" result

let program = Program()

let expression = Add(Constant(1.0),Mul(Constant(2.0),X))
program.Run(10.0,expression)

>
Result: 21.00
```

How is this helpful? At first sight, we are further away from our goal than initially: we don't have a simple F# function any more, we don't have raw strings either, but instead, we got this new `Expression` thing, which is neither of the things we want.

We will see in our next post why this might be a helpful idea after all. As a hint of things to come, we replaced our original problem (convert text to an F# function) with a much simpler one: we only have to worry about mapping the user input to 4 simple and well-defined shapes, the 4 cases of our discriminated union that constitute our internal DSL.

So stay tuned for more, and [see you next week](http://brandewinder.com/2016/02/20/converting-dsl-to-fsharp-code-part-2/)! In the meanwhile, I hope you found something interesting in this post already...

[1]: https://gist.github.com/mathias-brandewinder/4c6fb72748becf2e930b
