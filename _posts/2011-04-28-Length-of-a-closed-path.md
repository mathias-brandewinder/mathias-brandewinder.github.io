---
layout: post
title: Length of a closed path
tags:
- Bee-Colony
- Traveling-Salesman
- Optimization
- Simulation
- Sequence
- F#
- Algorithms
---

In my last post, I began my attempt at replicating a Bee Colony implementation from C# to F#, generating random solutions by permuting Cities in the Traveling Salesman circuit. Today, we’ll look at another ingredient of the problem: the evaluation of solutions. We need to be able to compare the quality of solutions to determine whether they constitute an improvement.   In our case, we will represent each City by 2 coordinates in the plane, and simply use the [Euclidean distance](http://en.wikipedia.org/wiki/Euclidean_distance) as our cost measure – so our goal is to minimize the total distance travelled.  

Let’s model a City as a [**record**](http://msdn.microsoft.com/en-us/library/dd233184.aspx):  

``` fsharp
type City = { X: float; Y: float; }
``` 

We can now create list of cities, which will represent solutions:

``` fsharp
> type City = { X: float; Y: float; }
let c1 = { X = 0.0; Y = 0.0}
let c2 = { X = 3.0; Y = 0.0}
let c3 = { X = 0.0; Y = 4.0};;

type City =
  {X: float;
   Y: float;}
val c1 : City = {X = 0.0;
                 Y = 0.0;}
val c2 : City = {X = 3.0;
                 Y = 0.0;}
val c3 : City = {X = 0.0;
                 Y = 4.0;}

> let cities = [c1; c2; c3];;

val cities : City list = [{X = 0.0;
                           Y = 0.0;}; {X = 3.0;
                                       Y = 0.0;}; {X = 0.0;
                                                   Y = 4.0;}]
``` 

<!--more-->

The distance between 2 cities is then easily defined as:

``` fsharp
let Distance (city1, city2) = 
    ((city1.X - city2.X) ** 2.0 
    + (city1.Y - city2.Y) ** 2.0) ** 0.5
``` 

How can we now compute the total length of a solution? If this wasn’t a closed circuit (i.e. if the salesman didn’t have to end up in the same city he started from), this would be fairly straightforward: travel along the sequence of cities, map each pair to its distance, and sum them up:

``` fsharp
> let cities = [c1; c2; c3]
let dist = cities |> List.toSeq |> Seq.pairwise |> Seq.map Distance |> Seq.sum;;

val cities : City list = [{X = 0.0;
                           Y = 0.0;}; {X = 3.0;
                                       Y = 0.0;}; {X = 0.0;
                                                   Y = 4.0;}]
val dist : float = 8.0
``` 

However, because we have to end up in the same place we started from, we’ll need to be a bit more subtle than that. My first take looked like this:

``` fsharp
let RouteCost list =
   let length = List.length list   
   seq { for i in 0 .. length - 1 
   do yield list.[i], list.[(i + 1) % length]}
   |> Seq.map Distance |> Seq.sum
``` 

We create a sequence on the fly, by iterating over the indexes of the list, and for each index, we return the Tuple of cities at position index and index + 1, modulo the length, so that the last index falls back on index 0, that is the first City. We then map each pair of city to a Distance, like before, and we are done.

Just for kicks, I tried another version, still creating a sequence on the fly, but starting with generating the sequence of indexes from 0 to the last, and then 0 – and then applying the same process as initially, grouping the sequence elements by pairs, and mapping them:

``` fsharp
let CircuitCost list =
      seq {
         for i in 0 .. (List.length list - 1) -> list.[i]
         yield List.head list
      }
      |> Seq.pairwise 
      |> Seq.map Distance 
      |> Seq.sum
``` 

I suspect there isn’t much of a difference between the two methods (would love to hear if there is!), but I found the second one slightly more pleasing to the eye. In any case, now that we have our core building blocks – random shuffles of cities, and distances – we can now move to the next part, getting the bees busy to work!
