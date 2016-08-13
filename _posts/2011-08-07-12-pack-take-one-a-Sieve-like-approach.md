---
layout: post
title: 12-pack, take one&#58; a Sieve-like approach
tags:
- Fun
- Math
- Algorithms
- Optimization
- Sieve-Of-Eratosthene
- 12-Pack
---

In my last post, I presented a [small problem]({{ site.url }}/2011/08/04/The-12-pack-problem-combination-of-integers/) which I found interesting: how to help a Brewery of the glorious land of Bizzarostan in finding the perfect combination of 7-packs and 13-packs of beer. Or, in more serious terms,  

> Suppose that you are given a list of integers, and a target integer. Your goal is to find the closest value that is greater or equal to the target, by combining integers (“packs”) from the list (only positive combinations are allowed). For instance, given 3 and 5, the closest you can get to 16 would be 5 x 2 + 3 x 2 = 16, and the closest to 17 would be 3 x 6 = 18.

My first take on the problem was inspired by the [Sieve of Eratosthenes](http://en.wikipedia.org/wiki/Sieve_of_Eratosthenes). The idea is to accumulate in a list all possible combinations of packs, and take the smallest combination greater than the target. The main difference with the Sieve of Erathostene is that for prime numbers, we only care about listing numbers that are multiples of primes, whereas here we need to enumerate linear combinations of packs, and not simply all the multiples of single packs.  

For instance, in the example where we search for a target of 16 using a combination of 3- and 5-packs, the procedure looks like:  

* Add 0 to the combinations, i.e. {0}  
* Add the multiples of 3, until 17 is reached, i.e. {0, 0 + 3 x 1, 0 + 3 x 2 = 6, 9, 12, 15, 18}  
* For each element of the list, create multiples of 5, and progressively add them to the list, i.e.  {0, 3, 6, 9, 12, 15, 18, **0** + 5, **0** + 2 x 5, **0** + 3 x 5, **0** + 4 x 5, **3** + 5 x 1, **3** + 5 x 2, **3** + 5 x 3, **6** + 5 x 1, … }  

Note that we need to accumulate all the intermediate combinations, and cannot simply store the first number greater than the limit for each pack, because we need to consider solutions which combine multiple packs – like 16 = 3 x 2 + 5 x 2 

<!--more-->

That’s essentially what the code below is doing; it could be optimized some, but I left it as-is for clarity:  

``` csharp
using System;
using System.Collections.Generic;
using System.Linq;

public class Sieve
{
   public static int Find(int target, IEnumerable<int> packs)
   {
      if (packs == null)
      {
         throw new ArgumentException();
      }

      if (packs.Count() == 0)
      {
         throw new ArgumentException();
      }

      var combinations = new List<int>();
      combinations.Add(0);

      foreach (var pack in packs)
      {
         foreach (var combination in combinations)
         {
            var updatedCombinations = new List<int>(combinations);
            var multiplier = 0;
            while (combination + pack * multiplier < target)
            {
               multiplier++;
               var candidate = combination + pack * multiplier;
               if (candidate == target)
               {
                  return target;
               }

               if (!updatedCombinations.Contains(candidate))
               {
                  updatedCombinations.Add(candidate);
               }
            }

            combinations = updatedCombinations;
         }
      }

      return combinations
         .Where(it => it >= target)
         .OrderBy(it => it)
         .Min();
   }
}
``` 

On the plus side, this does the job. 

I see also three drawbacks. First, the code isn’t very intention-revealing: it does take a bit of attention to get what is going on, and having a code that expressed better what we are trying to achieve, instead of how, would be nice. Then, the list of accumulated combinations could grow quite a bit, if the target is large and the packs small. Being able to enumerate complete combinations and their result, simply keeping track of the best current value, without having to accumulate intermediary results, would be a big improvement. Finally, and somewhat related to the two previous points, there is no obvious way to parallelize the accumulation approach.

Next time, we’ll see if we can address some of these problems by using the Microsoft Solver Foundation.
