---
layout: post
title: Waggle dances and Promotions
tags:
- F#
- Bee-Colony
- Algorithms
---

In the last post, we ended up defining Bees of 3 types – Scout, Active and Inactive – and a Search function which described how bees search among the space of possible solutions for new “food sources”. The second part of the algorithm deals with how bees returning to the hive share that information with their colleagues, and are promoted from inactive to actively searching.  

Real bees share information with each other using what is known as the [Waggle Dance](http://youtu.be/-7ijI-g4jHg), a pretty amazing process by which bees convey to other bees the direction to food sources. The algorithm is much less poetic: bees who return to the Hive with a new Solution will share that information with all bees that are already inactive, or will just become inactive because they have exhausted their current food source. Inactive bees, when presented with a new solution, may – with a certain probability - adopt it as their new target if it is better than their current target.  

<iframe width="420" height="315" src="https://www.youtube.com/embed/-7ijI-g4jHg" frameborder="0" allowfullscreen></iframe>

We'll represent this with a Waggle function, which will represent how a Bee will update its target Solution when presented with a list of potential new solutions.  

First, we need to filter the bees who pay attention to the dance; we’ll use a simple [**Active Pattern**](http://v2matveev.blogspot.com/2010/05/f-active-patterns.html):  

``` fsharp
let tripsLimit = 100

let (|RequiresUpdate|) bee =
   match bee with 
   | Scout(solution) -> false
   | Inactive(solution) -> true
   | Active(solution, trips) -> trips > tripsLimit
``` 

While a Scout never listens to the Waggle Dance, an Inactive bee always listens to incoming bees, and Active bees who have made multiple trips to the same destination without finding any improved solution will become Inactive, and listen to other bees.

We can now apply that pattern to decide what to do with a bee:

``` fsharp
let Waggle (solutions : List<Solution>) (bee : Bee) (rng : Random) =
   match bee with 
   | RequiresUpdate true -> 
      let currentSolution = Solution bee
      let newSolution = List.fold (fun acc element -> 
         if element.Cost < acc.Cost && rng.NextDouble() < probaConvince 
         then element else acc) currentSolution solutions
      Inactive(newSolution)      
   | _ -> bee
``` 

For bees that require an update, we retrieve their current solution (using a simple function Solution I’ll leave out for the moment), and fold the list of new potential solutions: starting from the bees’ current solution, we examine whether each candidate is an improvement, and pass the new solution to the accumulator if it is selected.

<!--more-->

The next problem is trickier. Starting from our initial list of Bees, after we run a Search and Waggle Dance, we may have promoted some Active bees to Inactive, and we need to promote some randomly selected Inactive bees to Active, so that they start searching.

One possible approach here is to identify the bees that are currently inactive and their indexes in the list, select a random subset of the indexes, and map the list of bees, converting the selected bees to Active. Here is the code I ended up with:

``` fsharp
let Promote bee =
   match bee with
   | Inactive(solution) -> Active(solution, 0)
   | _ -> bee

let Activate inactives bees =
   let inactiveIndexes = 
      List.mapi (fun i b -> match b with 
                            | Inactive(solution) -> Some(i) 
                            | _ -> None) 
                            bees
      |> List.choose (fun e -> e) 
      |> Shuffle

   let promoted = (List.length inactiveIndexes) - inactives
   let promotedIndexes = Seq.take promoted inactiveIndexes |> Seq.toList
   
   bees |> List.mapi (
      fun i b -> if List.exists (fun e -> e = i) promotedIndexes 
                 then Promote b
                 else b)
``` 

Activate takes in an int, inactives, representing the number of inactive bees there should be, and a List<Bee> bees. First, we retrieve the indexes of all Inactive bees: List.mapi allows us to iterate simultaneously over the indexes and elements of the list, and retrieve the indexes for the matching bees, and List.choose to eliminate the None elements. We shuffle that list and pick the indexes of the extra Inactive bees to be promoted. Using List.mapi again, we then map the list of bees, promoting the bees when the Index belongs to the list of promotedIndexes we just constructed.

That’s it for now – we have all the building blocks for the algorithm, next time we will put it all together, and get the search going!
