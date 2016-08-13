---
layout: post
title: Fair split into 3 groups using Bumblebee
tags:
- Bumblebee
- F#
- Optimization
- Algorithms
- Partition
---

I just came across this [interesting homework problem](http://stackoverflow.com/q/8762230/114519) on StackOverflow:  

> Given a group of n items, each with a distinct value V(i), what is the best way to divide the items into 3 groups so the group with the highest value is minimized? Give the value of this largest group. 

This looks like one of these combinatorial problems where a deterministic algorithm exists, and will be guaranteed to identify the optimal solution, with the small caveat that larger problem may take an extremely long time to resolve.  

<em>Note that as [ccoakley](http://stackoverflow.com/users/717457/ccoakley) points out in his comment to the StackOverflow question, there is no reason for a greedy approach to produce the optimal answer.*  

I figured this would be a good test for Bumblebee, my Artificial Bee Colony algorithm, which can produce a good solution in reasonable time, at the cost of not being guaranteed to find the actual optimum solution.  While we are at it, I figured we could also relax the constraints, and break the group into an arbitrary number of groups, and have possible duplicates rather than unique values.  

<!--more-->

How are we going to approach the problem formulation? Given a list of integers, the solution we expect is an allocation of each of the list elements to one group. We could make that work with a Tuple, but for the sake of readability we’ll define a record type Allocation, which will store the original list Element, as well as the Group it is allocated to:  

``` fsharp
type Allocation = { Element: int; Group: int }
``` 

Now we need to supply the bee hive with 3 functions to enable search. Generating random new solutions is fairly straightforward: we simply need to allocate elements of the original list to a random group:

``` fsharp
let groups = 3
let rng = new Random()
let root = [ for i in 0 .. 1000 -> rng.Next(0, 100000) ]
         
let generate = fun (rng: Random) ->
   List.map (fun e -> { Element = e; Group = rng.Next(0, groups) }) root
``` 

We map the “root” list of integers we are attempting to allocate so that each element of the list gets a random group.

Defining a solution in the neighborhood of an existing solution is equally straightforward: simply pick an element, and re-allocate it to any random group:

``` fsharp
let mutate = fun (rng: Random, solution: Allocation list) -> 
   let count = List.length solution
   let changed = rng.Next(0, count)      
   solution |> List.mapi (fun i e -> 
      if i = changed then 
         { Element = e.Element; Group = rng.Next(0, groups) } 
      else e)
``` 

Finally, given that we are trying to minimize the value of the highest group, we could directly use that metric for quality. Instead, we will measure the difference between the total in the smallest and largest group, simply because this gives us a good sense for how good a solution is: a difference of zero indicates that all groups are equal, and we therefore know that the closer to zero we are, the better the solution:

``` fsharp
let evaluate = fun (solution: Allocation list) -> 
   let groupValues =
      [
         for g in 0 .. (groups - 1) -> 
         List.filter (fun e -> e.Group = g) solution 
         |> List.sumBy (fun e -> e.Element);
      ]
   List.min (groupValues) - List.max (groupValues) |> (float)
``` 

We create a list of the totals of each group using a list comprehension: for each group, we filter the current solution to retain only integers that have been allocated to the group, and populate the list with the sum of each group – and we then compute the difference between the min and max of that list.

We can now state the problem we want to solve, and instantiate the solver:

``` fsharp
let problem = new Problem<Allocation list>(generate, mutate, evaluate)
let solver = new Solver<Allocation list>()
``` 

The rest follows the same patterns as the other examples presented in the Bumblebee documentation: hook up an event handler to receive notifications when better allocations have been found, and start the solver. (see the [entire code on the Bumblebee documentation](http://bumblebee.codeplex.com/wikipage?title=Fair%20partition%20in%20n%20groups))

Running the algorithm on a list of 1,000 integers between 0 and 100,000 produces stable answers close to the optimum within seconds:

![image]({{ site.url }}/assets/2012-01-06-image_thumb_9.png)

It may even be the optimum solution, for all I know. If I am patient enough, I’ll try out later to generate lists with known optimal solutions, to see whether / how fast the algorithm finds them. In any case, not too shabby for 30 minutes of work…

If you are interested, you can find the [entire code on the Bumblebee documentation](http://bumblebee.codeplex.com/wikipage?title=Fair%20partition%20in%20n%20groups). As always, questions and comments highly welcome!
