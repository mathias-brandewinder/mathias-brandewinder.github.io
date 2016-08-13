---
layout: post
title: Fight mutation with recursion
tags:
- Bumblebee
- Recursion
- F#
---

As happy as I am with how [Bumblebee](http://bumblebee.codeplex.com/) came out so far, there was one sore spot bugging me. I tried my best to write it in a functional style, but failed in one place. The inner part of the Search algorithm, which processes bees coming back in the queue with a new solution, was written as a while loop, using two mutable references to maintain the best solution found so far, and the list of solutions stored by the inactive bees.  

And then it hit me yesterday, as I was reading some material on [F# Azure worker roles](http://archive.msdn.microsoft.com/fsharpazure).  


> Novice:  
>    Master, I fail to find the path to the immutable way.  
> Master:  
>    Immutable way?  
>    Nothing changes, just call the  
>    Immutable way.  

This is an execrable [Haiku](http://en.wikipedia.org/wiki/Haiku), and a reminder to myself. When I get stuck with my old mutable ways in F#, usually the answer is recursion.  

In this case, all it took was rewriting the inner loop as a recursive function. The original loop looked along these lines:  

``` fsharp
while cancel.IsCancellationRequested = false do
   match returnQueue.IsEmpty with
   // the returning bees queue is not empty
   | false -> 
      let success, bee = returnQueue.TryDequeue()
      match success with
      // a returning bee has been found in the queue
      | true -> 
         inactives := waggle !inactives bee
         let candidate = Hive.solutionOf bee
         if candidate.Quality > best.Value.Quality then
            best.Value <- candidate
            foundSolution.Trigger(new SolutionMessage<'a>(candidate))
         else ignore ()
      // more code, irrelevant to the point
``` 

The recursive version simply includes in its arguments list all the previously mutable variables, and calls itself, passing along the result of the updates, along these lines:

``` fsharp
let rec loop (queue: ConcurrentQueue<Bee<'a>>) best inactives (cancel: CancellationTokenSource) =
   if cancel.IsCancellationRequested then ignore ()
   else
      let success, bee = queue.TryDequeue()
      if success then
      // a returning bee has been found in the queue
         let updatedInactives = waggle inactives bee
         let candidate = Hive.solutionOf bee
         let updatedBest = bestOf candidate best
         if candidate.Quality > best.Quality 
         then foundSolution.Trigger(new SolutionMessage<'a>(candidate))
         
         dispatchBee updatedInactives pickRandom waggle bee

         loop queue updatedBest updatedInactives cancel

      else loop queue best inactives cancel
``` 

The structure is essentially the same, but all the mutable variables are now gone; instead, the recursive function passes forward new “updated” values.

I think what tripped me up is the fact that I never used recursion to run an “infinite loop” before – I always saw them done using while true statements. Conversely, I always used recursion to produce an actual result, computing intermediary results until a termination condition was met. This one is a bit different, because the recursion simply passes along some state information, but doesn’t return anything (its return is unit) or terminate until a cancellation happens.
