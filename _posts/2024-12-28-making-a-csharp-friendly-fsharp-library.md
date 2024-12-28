---
layout: post
title: Making a F# library C# friendly
tags:
- F#
- C#
- Design
---

During December, I have been aggressively redesigning my library, [Quipu][1]. I 
initially wrote Quipu because I needed a [Nelder-Mead solver][2] in .NET, and 
could not find one ready to use. And, because I intended to use it from F#, 
I wrote Quipu in a style that wasn't particularly C# friendly.

As I was going through the code base with my chainsaw, I thought it would be an 
interesting exercise to try and make it pleasant to use from C# as well. This 
post will go through some of the process.  

First, what is Quipu about? Quipu is an implementation of the Nelder-Mead 
algorithm, and searches for arguments that minimize a function. As an example, 
suppose you were given the function `f(x,y) = (x-1)^2 + (y-2)^2 + 42`, and 
wanted to know what values of `x` and `y` give you the lowest possible value 
for `f`. With Quipu, now in C#, this is how you would go about it:  

``` csharp
#r "nuget: Quipu, 0.5.2"
using Quipu.CSharp;
using System;

Func<Double,Double,Double> f =
    (x, y) => Math.Pow(x - 1.0, 2) + Math.Pow(y - 2.0, 2) + 42.0;

var solverResult =
    NelderMead
        .Objective(f)
        .Minimize();

if (solverResult.HasSolution)
{
    var solution = solverResult.Solution;
    Console.WriteLine($"Solution: {solution.Status}");
    var candidate = solution.Candidate;
    var args = candidate.Arguments;
    var value = candidate.Value;
    Console.WriteLine($"f({args[0]:N3}, {args[1]:N3}) = {value:N3}");
}
```

This produces the following result, which happens to be correct:

```
Solution: Optimal
f(1.000, 2.000) = 42.000
```

I would also like to think that this C# code looks reasonably pleasant, whereas 
the original version (pre version 0.5.*) definitely was not. Let's go over some 
of the changes I made to the original code!

> Side note: my C# is pretty rusty at that point, if you have any thoughts or 
feedback on how to make this better, I am all ears!

<!--more-->

## The original version

The original F# version looked along these lines:  

``` fsharp
let f (x, y) = pown x 2 + pown y 2

let solution =
    NelderMead.objective f
    |> NelderMead.withTolerance 0.001
    |> NelderMead.startFrom (Start.around [ 100.0; 100.0 ])
    |> NelderMead.solve
```

The solver returned a `Solution`, a discriminated union shaped like this:  

``` fsharp
type Solution =
    | Optimal of (float * float [])
    | SubOptimal of (float * float [])
    | Unbounded
    | Abnormal of (float [][])
```

The intent of these 4 cases was to capture 4 possible outcomes: the solver  

- found an Optimal solution, with the corresponding value and arguments,
- found a SubOptimal solution, with the corresponding value and arguments,
- found the solution is Unbounded,
- encountered a problem along the way, returning the latest state of the solver.

This isn't perfect, but from an F# standpoint, it was decently usable (I built 
it for myself after all). However, from a C# standpoint, this is more or less 
unusable, and checks every "don't do this" box in the 
[F# component design guidelines][3] for libraries for use from other .NET 
languages. Specifically, for your public-facing API:  

- Don't return naked Discriminated Unions,  
- Don't return naked Tuples,  
- Don't use currying,  
- Use .NET naming conventions.

Let's see how we can fix that, starting with the biggest culprit, `Solution`.

## Reshaping the Solution

If you have ever tried to work with an F# discriminated union from the C# side, 
you know that the `Solution` type will be super unpleasant to work with. 
However, arguably, this design is also not great from an F# standpoint.  

First, in `Optimal of (float * float [])`, what is this tuple supposed to 
represent? Using a tuple there is not very clear: Let's clarify, using a record 
instead:  

``` fsharp
type Evaluation = {
    Arguments: float []
    Value: float
    }

type Solution =
    | Optimal of Evaluation
    | SubOptimal of Evaluation
    | Unbounded
    | Abnormal of (float [][])
```

Much better. However, as it turns out, this representation in 4 flat cases, 
while not wrong, is a little misleading. There are really 2 cases here: either 
the solver reached a "usable" conclusion, or something went off the rails 
(`Abnormal`). `Optimal`, `SubOptimal` and `Unbounded` all describe the best 
solution the solver found, after completing its search. In the `Unbounded` 
case, we omitted the `Evaluation` because you would typically not be interested 
in it, but we could provide one in all three cases, and re-structure the 
`Solution` along these lines:  

``` fsharp
type Evaluation = {
    Arguments: float []
    Value: float
    }

type Status =
    | Optimal
    | Suboptimal
    | Unbounded

type Solution =
    | Successful of (Status * Evaluation)
    | Abnormal of (float [][])
```

> Note: I initially did not include the `Evaluation` in the `Unbounded` case, 
I think because my thinking was biased by linear programming. In linear 
programming, an unbounded solution implies unbounded arguments, which is not 
necessarily the case for non-linear functions. As an example, `log(x)` is 
unbounded, but the arguments are finite: `log(0) = -infinity`.  

We still have a tuple in `Successful`, let's clean that up:  

``` fsharp
type Solution = {
    Status: Status
    Candidate: Evaluation
    }

type SolverResult =
    | Successful of Solution
    | Abnormal of (float [][])
```

Much better. The `Abnormal` case is still a bit gross, but I need to think 
about it some more, so I'll leave it as-is for the time being.  

We are still returning a naked Discriminated Union, though, which was what we 
wanted to avoid in the first place. Well, we can give it some clothing, by 
adding a couple of methods to our `SolverResult`, for instance:  

``` fsharp
type SolverResult =
    | Successful of Solution
    | Abnormal of (float [][])
    with
    member this.HasSolution =
        match this with
        | Successful _ -> true
        | Abnormal _ -> false
    member this.Solution =
        match this with
        | Successful solution -> solution
        | Abnormal _ -> failwith "No solution found."
```

Which will give us the ability to work with it fairly comfortably from the C# 
side of the house:  

``` csharp
if (solverResult.HasSolution)
{
    var solution = solverResult.Solution;
    Console.WriteLine($"Solution: {solution.Status}");
    var candidate = solution.Candidate;
    var args = candidate.Arguments;
    var value = candidate.Value;
    Console.WriteLine($"f({args[0]:N3}, {args[1]:N3}) = {value:N3}");
}
```

From the F# side, we can still use pattern-matching, like so:

``` fsharp
match solverResult with
| Successful solution ->
    printfn $"Solution: {solution.Status}"
    let candidate = solution.Candidate
    let args = candidate.Arguments
    let value = candidate.Value
    printfn $"f(%.3f{args[0]}, %.3f{args[1]}) = %.3f{value}"
| Abnormal _ ->
    printfn "Something went wrong here..."
```

## Parting thoughts

I'll stop here for today, and go over turning the F# pipeline into a C# fluent 
interface in another post.  

I found the exercise of looking at my F# code from a C# usability perspective 
very valuable. Arguably, the result is better overall, including for F#.  

Essentially, the whole exercise consisted of 2 operations:  
- Replacing tuples by records,  
- Adding properties or methods on discriminated unions to make their contents 
accessible without pattern matching.  

I was unsure about whether I should use the `Try...` pattern on `SolverResult`, 
to indicate that the result may or may not have a solution. In the end, I found 
using a pair of properties `HasSolution` and `Solution` was pretty clear, but 
perhaps `TryGetSolution` would be safer?  

Another thing I was unsure about is whether to entirely hide the discrimated 
union, by doing something like  

``` fsharp
type SolverResult =
    private
    | Successful of Solution
    | Abnormal of (float [][])
```

Keeping the discriminated union public gives me the ability to pattern match in 
F#, however it also creates some light cruft on the C# side.  

In a similar vein, the `SolverResult` type looks awfully close to a `Result`. 
Without the constraint of C# friendliness, we might as well just use a 
`Result<Solution, ...>`. This would also give us useful functions like 
`Result.map`, `Result.bind` and friends for free. I am not sure if I can get 
the best of both worlds, thoughm because returning a plain `Result` is 
unacceptable from a C# usability standpoint.  

Finally, this wasn't too hard, because fundamentally the `SolverResult` can be 
reduced to just 2 cases. The `Abnormal` branch, which I am still thinking 
about, should be trickier. Currently, `Abnormal` returns a `float [][]`, the 
current candidates the solver was evaluating when it encountered an issue. 
However, the solver could fail in situations where there isn't even a candidate 
yet. As an example, consider this:  

``` fsharp
let f (x, y) = pown (x - 1.0) 2 + pown (y - 2.0) 2 + 42.0
let solverResult =
    NelderMead.objective f
    |> NelderMead.startFrom (Start.around 10.0)
    |> NelderMead.minimize
```

In the current version, this will throw, because the objective function is in
2 dimensions, whereas the requested starting point is in 1 dimension:  

```
System.Exception: Invalid starting point dimension: 1, expected 2.
```

I would much prefer to capture that issue in the `Abnormal` branch of the 
`SolverResult`, and will likely do so in upcoming iterations. However, this 
means that the data in the `Abnormal` case will need to cover cases with 
potentially very different shapes and data. This is a great fit for a 
discriminated union, but won't work that well for something C# friendly.  

Anyways, that's it for today!  

[1]: https://www.nuget.org/packages/Quipu
[2]: https://en.wikipedia.org/wiki/Nelder%E2%80%93Mead_method
[3]: https://learn.microsoft.com/en-us/dotnet/fsharp/style-guide/component-design-guidelines