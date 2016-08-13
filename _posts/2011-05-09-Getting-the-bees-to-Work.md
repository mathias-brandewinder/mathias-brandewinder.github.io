---
layout: post
title: Getting the bees to Work
tags:
- Bee-Colony
- Traveling-Salesman
- F#
- Simulation
- Optimization
- Algorithms
---

This is our third episode in attempting to convert a C# bee colony algorithm into an F# equivalent. In our previous posts, we created functions to [randomly shuffle lists of cities]({{ site.url }}/2011/04/24/Simulated-Bee-Colony-in-F/), and to [measure the length of the corresponding path]({{ site.url }}/2011/04/28/Length-of-a-closed-path/). Today, it’s time to get the bees to work, bringing us new solutions to the hive.  

The algorithm distinguishes 3 types of bees: Scout, Active and Inactive. Each bee type has a different role in the algorithms: Scouts keep searching for new solutions, Active bees explore around known solutions for improvements until their potential is exhausted, and Inactive bees wait for new information, and replace Active bees when they turn Inactive.  

Let’s start there, and define a Bee [**discriminated union**](http://msdn.microsoft.com/en-us/library/dd233226.aspx):  

``` fsharp
type Bee = Scout | Active | Inactive
``` 

In the original C# implementation I am starting from, the algorithm works by iteration: each bee of the hive is processed and its state in the Hive updated (see [“The Solve Method” in the article](http://msdn.microsoft.com/en-us/magazine/gg983491.aspx)), with 3 steps: the bee

* finds a new solution and evaluates its quality, 

* shares that information with the inactive bees of the Hive by performing a Waggle Dance, 

* becomes re-allocated as Active or Inactive for the next iteration. 

Rather than follow strictly the existing implementation, where all three steps are happening in one single method for a bee, I decided to re-organize it a bit, and separate each of these operations, in part to make the code easier to follow, and in part with an eye to making it run in parallel later. 

In that frame, let’s begin with the first step, where bee searches for a new solution. Every bee has a current solution in memory, and after searching, they will come up with a new target solution if it is an improvement. Let’s first define for convenience what a Solution will be:

``` fsharp
type Solution = { Route: List<City>; Cost: float }
let Evaluate (route: List<City>) = { Route = route; Cost = CircuitCost route }
``` 

A Solution wraps in a [**Record**](http://msdn.microsoft.com/en-us/library/dd233184.aspx) the `Route` – the ordered list of Cities travelled – and its `Cost`, measured by its length. We also define a convenience function `Evaluate`, which takes in a Route and returns the corresponding solution, with the original Route and its Cost, computed using the function we wrote in our last post.

<!--more-->

The result of a Bee search depends on two factors: the type of Bee, and the Solution it currently has in memory. In addition to that, Active bees keep track of how many trips they have taken without finding a better solution. Let’s modify our Bee type, to allow it to store a Solution, and the count of Trips taken for Active bees:

``` fsharp
type Bee = 
   | Scout of Solution
   | Active of Solution * int
   | Inactive of Solution
``` 

We are now armed to write a Search function, which will produce the result of a Bee search. Let’s ignore first the fact that Active bees sometimes make mistakes (by design!)&#160; in recognizing whether a new solution is an improvement:

``` fsharp
let Search bee = 
   match bee with
   | Scout solution -> 
      let newSolution = Evaluate (Shuffle solution.Route)
      if newSolution.Cost < solution.Cost
      then (Scout(newSolution), Some(newSolution))
      else (bee, None)
   | Active (solution, visits) ->
      let newSolution = Evaluate (SwapRandomNeighbors solution.Route)
      if newSolution.Cost < solution.Cost
      then (Active(newSolution, 0), Some(newSolution))
      else (Active(solution, (visits + 1)), None)
   | Inactive solution -> (bee, None)
``` 

The search returns a tuple, containing a Bee with an up-to-date target Solution, and an [**Option**](http://msdn.microsoft.com/en-us/library/dd233245.aspx), with either a new Solution if it has changed, or None.

*Quick aside: I forgot to post the SwapRandomNeighbors function in the first cost of the series. It simply calls SwapWithNext on a randomly selected index of the list, permuting two neighbor elements in the list.*

The only thing we are left with is the Active bees selection mistakes, a fairly straightforward problem:

``` fsharp
let probaFalsePositive = 0.1
let probaFalseNegative = 0.1

let Search bee (random:Random) =
   match bee with
   | Scout solution -> 
      let newSolution = Evaluate (Shuffle solution.Route)
      if newSolution.Cost < solution.Cost
      then (Scout(newSolution), Some(newSolution))
      else (bee, None)
   | Active (solution, visits) ->
      let newSolution = Evaluate (SwapRandomNeighbors solution.Route)
      let proba = random.NextDouble()
      if newSolution.Cost < solution.Cost
      then 
         if proba < probaFalseNegative 
         then (Active(solution, (visits + 1)), None)
         else (Active(newSolution, 0), Some(newSolution))      
      else
         if proba < probaFalsePositive
         then (Active(newSolution, 0), Some(newSolution))
         else (Active(solution, (visits + 1)), None)
   | Inactive solution -> (bee, None)
``` 

We now have a Search function which we can apply to any type of Bee, to gather the results of the exploration. As an illustration, we could create a fake test route like this one:

``` fsharp
let a1 = { X = 2.0; Y = -1.0}
let a2 = { X = 2.0; Y = 1.0}
let a3 = { X = 1.0; Y = 3.0}
let a4 = { X = -1.0; Y = 3.0}
let a5 = { X = -2.0; Y = 1.0}
let a6 = { X = -2.0; Y = -1.0}
let a7 = { X = -1.0; Y = -2.0}
let a8 = { X = 1.0; Y = -2.0}
let testRoute = [ a1; a2; a3; a4; a5; a6; a7; a8 ]
let initialRoute = Shuffle testRoute
let scout = Scout(Evaluate initialRoute)
let active = Active(Evaluate initialRoute, 0)
let inactive = Inactive (Evaluate initialRoute)
let bees = [ scout; active; inactive]
let rng = new Random()
let search = List.map (fun bee -> Search bee rng) bees;;
``` 

We create a list of cities, which we shuffle, and 3 bees, all starting at the initial route – and we apply the search function to each bee from the list. Running this in the interactive window should generate a list of Bees, with their “bounty” – pretty much what the first half of the algorithm is supposed to do.

Next time, we’ll look at the remaining part – sharing the new information with the other bees with a Waggle Dance, and re-allocating which bees are Active and Inactive. Maybe I’ll also look at whether I can clean up a bit the Search function code – it’s readable, but it isn’t very pretty.

As usual, a friendly disclaimer that I am no expert at F# – I am an average C# developer, sharing his journey to F#, and I welcome criticisms and suggestions!
