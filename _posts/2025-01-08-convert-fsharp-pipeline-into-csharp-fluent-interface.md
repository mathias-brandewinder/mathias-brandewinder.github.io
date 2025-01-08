---
layout: post
title: Converting an F# pipeline into a C# fluent interface
tags:
- F#
- C#
- Design
---

In my [previous post][1], I went over one of the changes I made to  my library, 
[Quipu][2], to make it more C# friendly. In this installment, I will go over 
another design change, turning the initial F# version, which used a classic 
pipeline, into a Fluent Interface.  

For reference, here is how the original F# pipeline looks like:  

``` fsharp
let f (x, y) = pown (x - 1.0) 2 + pown (y - 2.0) 2 + 42.0
let solverResult =
    NelderMead.objective f
    |> NelderMead.withTolerance 0.000_0001
    |> NelderMead.startFrom (Start.around (100.0; 100.0))
    |> NelderMead.minimize
```

This _looks_ pretty similar to a Fluent Interface. It is not, though: it is a 
classic F# pipeline, chaining functions using the pipe-forward operator. From 
the F# side, this feels like a fluent interface, but for a C# consumer, it is 
more or less unusable.  

Can we turn this into an actual C# friendly Fluent Interface? Yes we can, and 
this is what I will go over in this post.  

<!--more-->

## Fluent Interface, Take One

First, if we mimicked what the F# code does, how would a C# Fluent Interface 
look like? Probably something along these lines:  

``` csharp
Func<Double,Double,Double> f =
    (x, y) => Math.Pow(x - 1.0, 2) + Math.Pow(y - 2.0, 2) + 42.0;
var solverResult =
    NelderMead
        .Objective(f)
        .WithTolerance(0.0000001)
        .StartFrom(Start.Around(100.0, 100.0))
        .Minimize();
```

As it turns out, this _is_ exactly the current C# Quipu API. So how did we go 
from an F# pipeline to this?  

Let's start from the F# side, taking one of the pipeline steps for 
illustration:  

``` fsharp
type NelderMead () =
    static member withTolerance (tolerance: float) (problem: Problem) =
        { problem with
            Configuration = {
                problem.Configuration with
                    Termination = Termination.tolerance tolerance
                }
        }
```

[Source code](https://github.com/mathias-brandewinder/Quipu/blob/ee0c5be2815ac9131e57f7629cb2d891d76d2cb1/src/Quipu/NelderMead.fs#L79-L85)

> Sidebar: Why is `NelderMead` a class and not a module? And why is 
`withTolerance` a static method, and not a function on a module? I ended up 
using a class because, for other functions, I needed overloads.  

The signature of the `withTolerance` function is  

``` fsharp
withTolerance: float -> Problem -> Problem
```

If we already had an instance of a `Problem`, say, `initialProblem`, we could apply 
`withTolerance` using the [pipe-forward operator][3], which will return a new, 
updated `Problem`:  

``` fsharp
initialProblem
|> NelderMead.withTolerance 0.000_001
```

As long as we have functions that look along these lines:  

``` fsharp
someProblemTransformation: argument1 -> ... -> Problem -> Problem
```

... we can keep chaining them together, passing an initial `Problem` through a 
series of transformations that will eventually give us a `Problem`.  

Stated differently, our original pipeline can be rewritten in the following 
equivalent code, fully expanding each step:  

``` fsharp
let f (x, y) = pown (x - 1.0) 2 + pown (y - 2.0) 2 + 42.0
let problem0 = NelderMead.objective f
let problem1 = NelderMead.withTolerance 0.000_0001 problem0
let problem2 = NelderMead.startFrom (Start.around [ 100.0; 100.0]) problem1
let solverResult = NelderMead.minimize problem2
```

All we are doing is passing around a `Problem` and transforming it.  

Can we do the same with C#? We can, by using essentially the same idea. All we 
need is a method on an instance, which returns a new instance of the same type. 
We could for instance add a method on the `Problem` type, and do something like 
this:  

``` fsharp
type Problem = {
    // omitted for readability
    }
    with
    member this.WithTolerance (tolerance: float): Problem =
        { this with
            // slightly simplified for readability
            Tolerance = tolerance
        }
```

`WithTolerance` returns a `Problem`, so we can now chain the calls like so:  

``` csharp
var problem1 = problem0.WithTolerance(0.001);
var problem2 = problem1.WithTolerance(0.01);
var problem3 = problem2.WithTolerance(0.1);
```

Or, omitting the intermediate variables, and calling `WithTolerance` directly 
on the `Problem` that the previous step returned:  

``` csharp
var problem3 =
    problem0
        .WithTolerance(0.001)
        .WithTolerance(0.01)
        .WithTolerance(0.1);
```

Of course, this example is a little absurd (you would not set the tolerance 
three times in a row, to three different values), but it illustrates the point. 
If we have methods on an instance that return an instance of the same type, we 
have a Fluent Interface.  

## Fluent Interface, Take Two

While the general idea works, I wasn't entirely satisfied with it. My issue was 
that the `Problem` type is not meant to be front-and-center. Leaving the type 
public is fine, so you can directly manipulate it in case you want to do 
something unusual, but by default you should not have to touch it.  

In addition to this, `Problem` is a record which contains "non-obvious" types 
(`IVectorFunction`, `IStartingPoint`). Instantiating a `Problem` manually 
requires understanding how all these types work, and will be at best error 
prone and unpleasant (in particular for C#).  

The F# pipeline completely hides `Problem` from the user, can we do something 
similar for C# consumers?  

Ignoring for now how to instantiate a `Problem`, one approach would be to do 
something like this. Remove the `WithTolerance` method from `Problem`, and move 
it to the `NelderMead` class instead:  

``` fsharp
// the constructor expects an instance of Problem
type NelderMead(problem: Problem) =
    member this.WithTolerance(tolerance: float) =
        // we update the Problem, using the existing F# method
        let updatedProblem =
            problem
            |> NelderMead.withTolerance tolerance
        // and instantiate a new NelderMead, re-wrapping the updated Problem
        NelderMead(updatedProblem)
```

Instead of an empty constructor earlier, we expose a single constructor that 
expects an instance of a `Problem`. Because we want to chain method calls, we 
return a `NelderMead` from the `WithTolerance` method, so we can do the 
following:  

``` csharp
NelderMead(problem0)
    .WithTolerance(0.001)
    .WithTolerance(...)
```

We are still left with one problem, though. We need to pass a well-formed 
`Problem` in the constructor. How can we avoid that?  

The F# pipeline gets around this by using factory methods. The first call in 
our original pipeline creates a `Problem`, using a static method `objective`: 

``` fsharp
let f (x, y) = pown (x - 1.0) 2 + pown (y - 2.0) 2 + 42.0
let solverResult =
    NelderMead.objective f
    |> NelderMead.withTolerance 0.000_0001
    // more steps omitted
```

We can easily achieve the same effect from the C# side, by hiding the default 
constructor, and exposing a similar factory method:  

``` fsharp
type NelderMead private (problem: Problem) =

    static member Objective(f: System.Func<float,float,float>) =
        NelderMead.objective f.Invoke
        |> NelderMead

    member this.WithTolerance(tolerance: float) =
        problem
        |> NelderMead.withTolerance tolerance
        |> NelderMead
```

Applying the same trick to the other steps of the pipeline leads to the 
following API:  

``` csharp
Func<Double,Double,Double> f =
    (x, y) => Math.Pow(x - 1.0, 2) + Math.Pow(y - 2.0, 2) + 42.0;
var solverResult =
    NelderMead
        .Objective(f)
        .WithTolerance(0.0000001)
        .StartFrom(Start.Around(100.0, 100.0))
        .Minimize();
```

... which is a Fluent Interface that mimicks the original pipeline, but is 
also usable from the C# side.  

## Parting thoughts

A couple of final comments before closing shop!

First, as of the [latest version (0.5.2)][4], the F# and C# APIs are separated 
in 2 different namespaces, `Quipu` for F#, `Quipu.CSharp` for C#. I initially 
used a single class, as in this post, but as a result, the `NelderMead` type 
had a _lot_ of methods, mixing code formatting conventions (`withTolerance` and 
`WithTolerance` for example). I can see only one drawback to introducing this 
separation: you need to open the correct namespace depending on your preferred 
language. This seemed like an acceptable price to pay for the benefit of an 
uncluttered API.  

Speaking of formatting, I also wanted the code to follow the expected standards 
for both F# and C#. I ended up using the `[<CompiledName>]` attribute on the 
`Start` type, like so:  

``` fsharp
type Start =
    [<CompiledName("Around")>]
    static member around (startingPoint: seq<float>) =
        // omitted code
```

As a result, the code looks as you would expect in both languages:  

``` fsharp
NelderMead.objective f
|> NelderMead.startFrom (Start.around (100.0; 100.0))
```

``` csharp
NelderMead
    .Objective(f)
    .StartFrom(Start.Around(100.0, 100.0))
```

Finally, the goal was to design a C#-friendly API, and the best way to check if 
that goal is achieved is to experience potential painpoints yourself, by using 
your own code (aka dog-fooding). I ended up writing a battery of unit tests in 
C#, which is a simple but effective way to do that.  

One thing I was wondering about is how I could also confirm API parity between 
the two versions. The thought here is that if I write a unit test in F#, it 
would be nice to automatically also run the same test, using the equivalent C# 
code. I am still mulling over that one, it is an interesting problem, but one I 
can leave to think about later :)  

That's what I got for today! I am still planning to make some changes to the 
library, but I expect these to be much less drastic than the recent ones. 
Anyways, [Quipu is usable as-is today][2] - if you have questions, feedback or 
requests, let me know! And in the meantime, I hope you found something of 
interest in this post.  

[1]: https://brandewinder.com/2024/12/28/making-a-csharp-friendly-fsharp-library/
[2]: https://www.nuget.org/packages/Quipu
[3]: https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/functions/#pipelines
[4]: https://github.com/mathias-brandewinder/Quipu/releases/tag/0.5.2