---
layout: post
title: Simulated Bee Colony in F#
tags:
- Bee-Colony
- Heuristic
- Traveling-Salesman
- Optimization
- Simulation
---

April 2011’s issue of MSDN Magazine had an interesting piece on [**Bee Colony Algorithms**](http://msdn.microsoft.com/en-us/magazine/gg983491.aspx) by **Dr. James McCaffrey,**, explaining the concepts and providing an example, applying the algorithm to the Traveling Salesman Problem. In a nutshell, the algorithm is a [meta-heuristic](http://en.wikipedia.org/wiki/Metaheuristic), that is, a method that is not guaranteed to produce an optimal solution, but will search for “decent” solutions in a large space. In a real-life bee hive,&#160; bees scout for areas rich with food, keep visiting them until they are exhausted, and tell other bees about good spots so that more bees come search that area. By analogy, the algorithm uses scout bees, which search for new random solutions, and recruit inactive bees which become active and start searching for improved solutions around their current solution.  

I found the algorithm intriguing, and thought it would be a good learning exercise to try and adapt it to F#. 

*Disclaimer: I am still learning the ropes in F#, so take the code that follows with a grain of salt. I’ll gladly take advice and criticism to make this better – my intent is to share my learning experience with the language, not to teach you best practices.*  

In the case of the [Traveling Salesman Problem](http://en.wikipedia.org/wiki/Travelling_salesman_problem), the goal is to find the shortest (or some other cost measure) closed route connecting a list of cities. In order to do this, we need to be able to create random solutions, as well as solutions in the neighborhood of an existing solution.  

Assuming we begin with an initial list of Cities (the cities our salesman needs to visit), we can generate random solutions by shuffling that list, using the [Fisher-Yates shuffle](http://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle) algorithm. We can generate the sequence of index pairs that need to be swapped with the following  

``` fsharp
let SwapIndexPairs list =  
   let random = new Random()
   seq { 
      for i in (List.length list - 1) .. -1 .. 1 do 
      yield (i, random.Next(i + 1)) }
``` 

Running this in the interactive window produces the following:

``` fsharp
> open System;;
> let SwapIndexPairs list =  
   let random = new Random()
   seq { 
      for i in (List.length list - 1) .. -1 .. 1 do 
      yield (i, random.Next(i + 1)) };;

val SwapIndexPairs : 'a list -> seq<int * int>

> let i = SwapIndexPairs [0;1;2;3;4;5] |> Seq.toList;;

val i : (int * int) list = [(5, 0); (4, 0); (3, 2); (2, 1); (1, 1)]
``` 

<!--more-->

Applied on a list, it produces a sequence of tuples, representing the successive pairs of items that should be permuted. Now we just need to apply the permutations to our initial list. Rather than updating the same array of indexes in place, I figured it would be fun to try out the [`List.permute`](http://msdn.microsoft.com/en-us/library/ee353537.aspx) function. `List.permute` works by applying a function to a list; the function maps every index of the original list, to the destination index of the permuted list. For instance, mapping each index to itself will return an identical list:

``` fsharp
> let identityMap i = i;;

val identityMap : 'a -> 'a

> List.permute identityMap [0;1;2;3];;
val it : int list = [0; 1; 2; 3]
``` 

Reversing a list can be done like this:

``` fsharp
> List.permute (fun i -> 4 - i) [0;1;2;3;4];;
val it : int list = [4; 3; 2; 1; 0]
``` 

What we need is a permutation function which keeps everything in place, except for the two indexes we want to swap, represented by a [`Tuple`](http://msdn.microsoft.com/en-us/library/dd233200.aspx):

``` fsharp
let SwapIndexMap index (moveIndex, toIndex) =
  if index = moveIndex then toIndex
  elif index = toIndex then moveIndex
  else index

let Swap indexPair list =
  let length = List.length list
  List.permute (fun index -> SwapIndexMap index indexPair) list
``` 

The `SwapIndexMap` function defines how each index should be mapped, given the 2 indexes that should be swapped; the Swap function applies it to a list, and returns the result of the permutation. We are now all set to write the list `Shuffle` function:

``` fsharp
let Shuffle list = 
   let length = List.length list
   let indexPairs = SwapIndexPairs list
   Seq.scan (fun currentList indexPair -> Swap indexPair currentList) 
      list indexPairs
   |> Seq.nth (length - 1)
``` 

Starting from a list, we create a sequence of indexes to be swapped, we scan that sequence, starting from the original list, and applying permutation after permutation until the sequence is exhausted – and we return the last item of the sequence. Let’s try the interactive window again, just to check that nothing is wildly wrong:

``` fsharp
> let s = Shuffle [0;1;2;3;4;5;6;7;8;9];;

val s : int list = [9; 0; 2; 6; 8; 1; 4; 5; 7; 3]

> let a = Shuffle ["A"; "B"; "C"; "D"; "E"];;

val a : string list = ["E"; "B"; "D"; "A"; "C"]
``` 

Looks like we have a random shuffle!

Given what we have gone through, the other problem, generating a solution in the neighborhood of an existing solution is a piece of cake. We just need to switch two consecutive items in the list: the only issue is with the last item of the list, which should be swapped with the first item. Building off our SwapIndexMap function, we get

``` fsharp
let SwapWithNextIndexMap index swapIndex length =
  let flipWith = (swapIndex + 1) % length
  SwapIndexMap index (swapIndex, flipWith)

let SwapWithNext swapIndex list =
  let length = List.length list
  List.permute (fun index -> SwapWithNextIndexMap index swapIndex length) list
``` 

Quick check in the Interactive Window again:

``` 
> SwapWithNext 3 [0;1;2;3;4;5];;
val it : int list = [0; 1; 2; 4; 3; 5]
> SwapWithNext 5 [0;1;2;3;4;5];;
val it : int list = [5; 1; 2; 3; 4; 0]
``` 

Looks good to me.

We now have two of the building blocks we need for the algorithm: a function which returns random solutions, inspired by the `GenerateRandomMemoryMatrix` method of the article, and a function which produces a solution in the neighborhood of an existing solution, similar to the `GenerateNeighborMemoryMatrix` method. Next, we’ll need to evaluate the relative quality of two solutions – but that will be for next time.

In the meanwhile, let me know if you have any comments or suggestions!
