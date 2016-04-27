---
layout: post
title: Amoeba optimization method using F#
tags:
- F#
- Machine-Learning
- Algorithms
- Optimization
---

My favorite column in MSDN Magazine is Test Run; it was originally focused on testing, but the author, James McCaffrey, has been focusing lately on topics revolving around numeric optimization and machine learning, presenting a variety of methods and approaches. I quite enjoy his work, with one minor gripe –his examples are all coded in C#, which in my opinion is really too bad, because the algorithms would gain much clarity if written in F# instead.

Back in June 2013, he published a piece on [Amoeba Method Optimization using C#](http://msdn.microsoft.com/en-us/magazine/dn201752.aspx). I hadn’t seen that approach before, and found it intriguing. I also found the C# code a bit too hairy for my feeble brain to follow, so I decided to rewrite it in F#.

<!--more-->

In a nutshell, the Amoeba approach is a heuristic to find the minimum of a function. Its proper respectable name is the [Nelder-Nead method](http://en.wikipedia.org/wiki/Nelder%E2%80%93Mead_method). The reason it is also called the Amoeba method is because of the way the algorithm works: in its simple form, it starts from a triangle, the “Amoeba”; at each step, the Amoeba “probes” the value of 3 points in its neighborhood, and moves based on how much better the new points are. As a result, the triangle is iteratively updated, and behaves a bit like an Amoeba moving on a surface.

Before going into the actual details of the algorithm, here is how my final result looks like. You can find the entire code [here on GitHub](https://github.com/mathias-brandewinder/Amoeba), with some usage examples in the Sample.fsx script file. Let’s demo the code in action: in a script file, we load the Amoeba code, and use the same function the article does, the [Rosenbrock function](http://mathworld.wolfram.com/RosenbrockFunction.html). We transform the function a bit, so that it takes a `Point` (an alias for an Array of floats, essentially a vector) as an input, and pass it to the solve function, with the domain where we want to search, in that case, `[ –10.0; 10.0 ]` for both x and y:

``` fsharp
#load "Amoeba.fs"
 
open Amoeba
open Amoeba.Solver
 
let g (x:float) y =
100. * pown (y - x * x) 2 + pown (1. - x) 2
 
let testFunction (x:Point) =
g x.[0] x.[1]
 
solve Default [| (-10.,10.); (-10.,10.) |] testFunction 1000
```

Running this in the F# interactive window should produce the following:

```
val it : Solution = (0.0, [|1.0; 1.0|]) 
>
```

The algorithm properly identified that the minimum is 0, for a value of x = 1.0 and y = 1.0. Note that results may vary: this is a heuristic, which starts with a random initial amoeba, so each run could produce slightly different results, and might at times epically fail.

So how does the algorithm work?

I won’t go into full detail on the implementation, but here are some points of interest. At each iteration, the Amoeba has a collection of candidate solutions, Points that could be a Solution, with their value (the value of the function to be minimized at that point). These points can be ordered by value, and as such, always have a best and worst point. The following picture, which I lifted from the article, shows what points the Amoeba is probing:

![Amoeba]({{ site.url }}/assets/amoeba.png)

Source: [“Amoeba Optimization Method in C#”](http://msdn.microsoft.com/en-us/magazine/dn201752.aspx)

The algorithm constructs a Centroid, the average of all current solutions except the worst one, and attempts to replace the Worst with 3 candidates: a Contracted, Reflected and Expanded solution. If none of these is satisfactory (the rules are pretty straightforward in the code), the Amoeba shrinks towards the Best solution. In other words, first the Amoeba searches for new directions to explore by trying to replace its current Worst solution, and if no good change is found, it shrinks on itself, narrowing down around its current search zone towards its current Best  candidate.

If you consider the diagram, clearly all transformations are a variation on the same theme: take the Worst solution and the Centroid, and compute a new point by stretching it by different values: –50% for contraction, +100% for reflection, and +200% for expansion. For that matter, the shrinkage can also be represented as a stretch of –50% towards the Best point.

This is what I ended up with:

``` fsharp
type Point = float []
type Settings = { Alpha:float; Sigma:float; Gamma:float; Rho:float; Size:int }
 
let stretch ((X,Y):Point*Point) (s:float) =
Array.map2 (fun x y -> x + s * (x - y)) X Y
 
let reflected V s = stretch V s.Alpha
let expanded V s = stretch V s.Gamma
let contracted V s = stretch V s.Rho
```

I defined `Point` as an alias for an array of floats, and a Record type `Settings` to hold the parameters that describe the transformation. The function stretch takes a pair of points and a float (by how much to stretch), and computes the resulting `Point` by taking every coordinate, and going by a ratio s from x towards y. From then on, defining the 3 transforms is trivial; they just use different values from the settings.

Now that we have the Points represented, the other part of the algorithm requires evaluating a function at each of these points. That part was done with a couple types:

``` fsharp
type Solution = float * Point
type Objective = Point -> float
 
type Amoeba =
{ Dim:int; Solutions:Solution [] } // assumed to be sorted by fst value
member this.Size = this.Solutions.Length
member this.Best = this.Solutions.[0]
member this.Worst = this.Solutions.[this.Size - 1]
 
let evaluate (f:Objective) (x:Point) = f x, x
let valueOf (s:Solution) = fst s
```

A Solution is a tuple, a pair associating a Point and the value of the function at that point. The function we are trying to minimize, the `Objective`, takes in a point, and returns a float. We can then define an `Amoeba` as an array of Solutions, which is assumed to be sorted. Nothing guarantees that the Solutions are ordered, which bugged me for a while; I was tempted to make that type private or internal, but this would have caused some extra hassle for testing, so I decided not to bother with it. I added a few convenience methods on the Amoeba, to directly extract the Best and Worst solutions, and two utility functions, evaluate, which associates a Point with its value, and its counter-part, valueOf, which extracts the value part of a `Solution`.

The rest of the code is really mechanics; I followed the algorithm notation from the Wikipedia page, rather than the MSDN article, because it was actually a bit easier to transcribe, built the search as a recursion (of course), which iteratively transforms an Amoeba for a given number of iterations. For good measure, I introduced another type, Domain, describing where the Amoeba should begin searching, and voila! We are done. In 91 lines of F#, we got a full implementation.

## Conclusion

What I find nice about the algorithm is its relative simplicity. One nice benefit is that it doesn’t require a derivative. Quite often, search algorithms use a gradient to evaluate the slope and decide what direction to explore. The drawback is that first, computing gradients is not always fun, and second, there might not even be a properly defined gradient in the first place. By contrast, the Amoeba doesn’t require anything – just give it a function, and let it probe. In some respects, the algorithm looks to me like a very simple genetic algorithm, maintaining a population of solutions, breeding new ones and letting a form of natural selection operate.

Of course, the price to pay for this simplicity is that it is a heuristic, that is, there is no guarantee that the algorithm will find a good solution. From my limited experimentations with it, even in simple cases, failures were not that unusual. If I get time for this, I think it would be fun to try launching multiple searches, and stopping when, say, the algorithm has found the same Best solution a given number of times.

Also, note that in this implementation, 2 cases are not covered: the case where the function is not defined everywhere (some Points might throw an exception), and the case where the function doesn’t have a minimum. I will let the enterprising reader think about how that could be handled!
