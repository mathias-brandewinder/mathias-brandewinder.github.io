---
layout: post
title: 12-pack, take three&#58; recursion
tags:
- Fun
- Math
- Algorithms
- Recursion
- Optimization
- 12-Pack
use_math: true
---

Let’s take a last stab at our [beer-delivery problem]({{ site.url }}/2011/08/04/The-12-pack-problem-combination-of-integers/). We tried out a [Sieve]({{ site.url }}/2011/08/07/12-pack-take-one-a-Sieve-like-approach/), we used the [Microsoft Solver]({{ site.url }}/2011/08/14/12-pack-take-two-Microsoft-Solver-Foundation/) – time for some recursion.  

How can we organize our recursion?   

If we had only 1 type of beer pack, say, 7-packs, the best way to supply <em>n</em> bottles of beer is to supply the closest integer greater than n/7, that is, 

$$\lceil {n \over 7} \rceil$$  

If we had 7-packs and 13-packs, we need to consider multiple possibilities. We can select from 0 to the ceiling of n/7 7-packs, and, now that we have only one type of case pack left, apply the same calculation as previously to the remaining bottles we need to supply – and select the best of the combinations, that is, the combination of beer packs closest to the target.  

If we had even more types of beer packs available, we would proceed the same way, by trying out the possible quantities for the first pack, and given the first, for the second, and so on until we reach the last type of pack – which is pretty much the outline of a recursive algorithm.  

<!--more-->

The implementation below follows more or less that description, with minor changes. We represent a solution as a **dictionary<int, int>** , mapping the number of bottles in each beer pack with the quantity of that pack in the solution. We begin with an empty solution, **current**, and a set of beer packs sizes, **packSizes**, and we progressively pick each beer pack size from packSizes, move it in the solution, and repeat until there is no beer pack left to add or we found a perfect match with the target.  

``` csharp
using System;
using System.Collections.Generic;
using System.Linq;

public class Recursion
{
   public int Find(int target, IEnumerable<int> packSizes)
   {
      var current = new Dictionary<int, int>();
      var remainingPacks = new List<int>(packSizes);
      var solution = Search(target, current, remainingPacks);
      return solution.Sum(it => it.Key * it.Value);
   }

   private IDictionary<int, int> Search(
      int target, 
      IDictionary<int, int> currentSelection, 
      IList<int> remainingPacks)
   {
      var currentValue = Bottles(currentSelection);
      if (currentValue >= target) { return currentSelection; }

      if (remainingPacks.Count() == 0) { return currentSelection; }

      var remainingTarget = target - currentValue;
      var newPack = remainingPacks.First();
      var maximum = Convert.ToInt32(Math.Ceiling((double)remainingTarget / (double)newPack));

      if (remainingPacks.Count() == 1)
      {
         currentSelection.Add(newPack, maximum);
         return currentSelection;
      }

      IDictionary<int, int> bestSolution = null;
      for (var packQuantity = 0; packQuantity <= maximum; packQuantity++)
      {
         var newCurrent = new Dictionary<int, int>(currentSelection);
         newCurrent.Add(newPack, packQuantity);
         var newRemainingPacks = new List<int>(remainingPacks);
         newRemainingPacks.Remove(newPack);

         var newSolution = Search(target, newCurrent, newRemainingPacks);
         var newSolutionValue = Bottles(newSolution);

         if (newSolutionValue == target) { return newSolution; }

         if (newSolutionValue > target)
         {
            if (bestSolution == null) { bestSolution = newSolution; }
            else
            {
               if (Bottles(newSolution) < Bottles(bestSolution))
               {
                  bestSolution = newSolution;
               }
            }
         }
      }

      return bestSolution;
   }

   private static int Bottles(IDictionary<int, int> solution)
   {
      return solution.Sum(it => it.Key * it.Value);
   }
}
``` 

So what is there to say about this approach? It’s not much longer than the 2 other approaches, but, in my opinion, it is significantly more difficult to follow. Maybe it’s just me, but even though I love recursion, I always have to think extra-hard to keep track of what is going on – and I did write some extra unit tests here to make sure this was working.

Is it worth the effort? In this case, it would think so. Testing on randomly generated data showed that the recursion approach was typically much faster than the solver-based approach, and comparable to the sieve, with the added benefit of providing an explicit solution.

Does this mean that the Solver isn’t the right tool for the job? In this case, probably not. There is an overhead in getting the solver in action, and, in a way, the problem is probably too easy for it. First, the brute-force enumeration approach is not too bad here, because there are not too many solutions. Then, a crucial point is that we know from the beginning what the best solution is: as soon as we hit a combination that matches the target, we can return and stop enumerating, because we know we have reached an optimum. As it turns out, I realized that finding a perfect match is not unusual, and typically, multiple combinations exist which are perfect, so it is actually likely that we will only enumerate a small portion of the combinations, and terminate early.

On a final note, I realized that this problem was a variation on the [Cashier’s algorithm](http://www.cs.princeton.edu/courses/archive/spring07/cos423/lectures/greed-dp.pdf) (given a set of coin denominations, find how to pay a certain amount to a customer using the fewest number of coins) and the Postal Worker’s algorithm (same thing, with stamps). These definitely sound more dignified than my 12-pack algorithm – but then, I am more of a beer enthusiast than a philatelist or numismatist, so to each its own, and its own algorithms. Prosit!
