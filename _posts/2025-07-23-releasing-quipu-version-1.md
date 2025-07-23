---
layout: post
title: Releasing Quipu version 1.0.0, a .NET Nelder-Mead solver
tags:
- F#
- C#
- Algorithm
- Optimization
---

On February 25, 2023, I made the initial commit to Quipu. I needed a 
[Nelder-Mead solver][1] in .NET, and couldn't find one, so I started writing my 
own. Today, I am happy to announce [version 1.0.0 of Quipu][2]!  

## What does it do?

Quipu takes in a function, and searches for the arguments that minimize (or 
maximize) the value of that function. This is a problem that arises in many 
areas (curve fitting, machine learning, finance, optimization, ...).  

Let's demonstrate on a simple example, rather than go into a lengthy 
explanation. Imagine that we have a fictional factory, where we produce 
Widgets:  

- We sell Widgets for $12 per unit
- Producing a Widget costs $5 per unit
- Shipping widgets: the more Widgets we produce on a day, the further we have 
to ship to reach customers and sell them. Shipping `n` Widgets costs us 
$`0.5 * n * n`. Shipping 1 Widget would cost us $0.5, shipping 2 would cost $2, 
and 10 would cost us a total of $50.

We could represent this fictional model in C# like so:  

``` csharp
public class ProfitModel
{
    public static double ProductionCost(double volume)
    {
        return 5 * volume;
    }
    public static double TransportationCost(double volume)
    {
        return 0.5 * (volume * volume);
    }
    public static double Revenue(double volume)
    {
        return 12 * volume;
    }
    public static double Profit(double volume)
    {
        return
            Revenue(volume)
            - ProductionCost(volume)
            - TransportationCost(volume);
    }
}
```

How many widgets should we produce, if we wanted to maximize our daily profit?  

Let's ask Quipu:  

``` csharp
using Quipu.CSharp;

var solverResult =
    NelderMead
        .Objective(ProfitModel.Profit)
        .Maximize();

if (solverResult.HasSolution)
{
    var solution = solverResult.Solution;
    Console.WriteLine($"Solution: {solution.Status}");
    var candidate = solution.Candidate;
    var args = candidate.Arguments;
    var value = candidate.Value;
    Console.WriteLine($"Profit({args[0]:N3}) = {value:N3}");
}
```

The answer we get from Quipu is:  

```
Solution: Optimal
Profit(7.000) = 24.500
```

<!--more-->

If you lean more towards F#, you could solve the same problem using a pipeline, 
like so:  

``` fsharp
let profit (production: float) =
    let productionCost = 5.0 * production
    let transportCost = 0.5 * (production ** 2.0)
    let revenue = 12.0 * production
    revenue - productionCost - transportCost

profit
|> NelderMead.objective
|> NelderMead.maximize
```

While not particularly realistic, this problem hopefully gives a sense for 
where Quipu can be useful. And, a word of caution, Quipu is not a magic 
silver bullet. It only handles functions that take in one or more floating 
point arguments, and return a floating point value. It is also not guaranteed to 
find the best solution: it could potentially return a good solution that is not 
the absolute best (the global optimum), or even occasionally fail to find a 
solution.  

## What's next?

Getting a working version of the algorithm was fairly quick. Putting together 
an API that was reasonably pleasant to use, from F# and C#, took some effort. 
Making it robust and reasonably fast also took some iterations.  

But I think it's good enough to ship now! I am sure it can be improved, 
but I have been using it quite a bit now, and it works reasonably well, at 
least for my purposes.  

If you are interested in trying it out, it's [available on Nuget][2]. Just 
run `dotnet add package Quipu --version 1.0.0`, and give it a spin! And let me 
know if you find bugs (the code is on [GitHub][3]), or have thoughts on how to 
make it better. I built it to solve a problem I had, and so unsurprisingly it 
works pretty well for me, but I would love to hear if there is something I 
could do to make it more convenient for you or others!

[1]: https://en.wikipedia.org/wiki/Nelder%E2%80%93Mead_method
[2]: https://www.nuget.org/packages/Quipu
[3]: https://github.com/mathias-brandewinder/Quipu
