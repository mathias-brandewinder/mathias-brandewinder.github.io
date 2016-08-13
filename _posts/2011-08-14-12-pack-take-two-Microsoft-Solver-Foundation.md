---
layout: post
title: 12-pack, take two&#58; Microsoft Solver Foundation
tags:
- Microsoft-Solver-Foundation
- Fun
- Math
- Algorithms
- Optimization
- 12-Pack
---

In our last post, we looked at a [Sieve-like algorithm]({{ site.url }}/2011/08/07/12-pack-take-one-a-Sieve-like-approach/) to help a Brewery find how closely they can match the number of beer bottles their thirsty customers desire, using only [7-packs and 13-packs of delicious beer]({{ site.url }}/2011/08/04/The-12-pack-problem-combination-of-integers/); in less appetizing but more precise terms, we are trying to solve the following problem:  

> Suppose that you are given a list of integers, and a target integer. Your goal is to find the closest value that is greater or equal to the target, by combining integers (“packs”) from the list (only positive combinations are allowed). For instance, given 3 and 5, the closest you can get to 16 would be 5 x 2 + 3 x 2 = 16, and the closest to 17 would be 3 x 6 = 18. 

The Sieve solution is pretty effective, but has some limitations. Today, we’ll take another approach: leveraging the [Microsoft Solver Foundation](http://archive.msdn.microsoft.com/solverfoundation).  

The beauty of the Solver is that it allows you to focus on what you want to achieve, rather than on how to achieve it. As long as you can define clearly what your **goal**, your **decision** variables and your **constraints** are, you can leave it to the Solver engine to figure out what the best way to achieve that goal is, by searching the best values for the Decision variables you defined.  

So what are we trying to achieve here? Our goal, in Solver terms, is to minimize the extra number of bottles shipped, under the constraint that the number of bottles shipped is greater than the requested target number. Our Decision variables are the number of units of each Beer Pack we will ship, with a constraint that Decisions must be integer (we cannot ship half-packs), and positive.  

Let’s add a reference to the Solver in our project ([details here]({{ site.url }}/2011/07/16/First-steps-with-the-Microsoft-Solver-Foundation/)), and see how this looks like in code: 

<!--more-->

``` csharp
namespace TwelvePack
{
   using System;
   using System.Collections.Generic;
   using System.Linq;
   using Microsoft.SolverFoundation.Services;

   public class Solver
   {
      public int Find(int target, IEnumerable<int> packSizes)
      {
         var context = SolverContext.GetContext();
         context.ClearModel();
         var model = context.CreateModel();

         var packDefinitions = new Dictionary<string, int>();
         foreach (var packSize in packSizes)
         {
            var packName = "Pack_" + packSize;
            packDefinitions.Add(packName, packSize);
         }

         var decisions = packDefinitions.Select(
            it => new Decision(Domain.IntegerNonnegative, it.Key));
         model.AddDecisions(decisions.ToArray());

         var bottlesDelivered = new SumTermBuilder(packDefinitions.Count());
         foreach (var packDefinition in packDefinitions)
         {
            var decision = model.Decisions
               .First(it => it.Name == packDefinition.Key);
            var packSize = packDefinition.Value;
            bottlesDelivered.Add(packSize * decision);
         }

         model.AddGoal(
            "ExtraBottlesDelivered", 
            GoalKind.Minimize, 
            bottlesDelivered.ToTerm() - target);
         model.AddConstraint(
            "ExtraBottles", 
            bottlesDelivered.ToTerm() >= target);

         var solution = context.Solve();
         
         var totalBottles = 0;
         foreach (var decision in solution.Decisions)
         {
            var packName = decision.Name;
            var packSize = packDefinitions[packName];
            var quantity = Convert.ToInt32(decision.ToDouble());
            totalBottles += packSize * quantity;
         }

         return totalBottles;
      }
   }
}
``` 

Let’s break it down step by step:

* We start by instantiating a SolverContext, which will be responsible for managing the solver, and create a Model, 

* For convenience, we create a Dictionary, which stores a variable name for each of our case packs, and store the number of bottles contained in each beer pack, the Pack Size, 

* We create a Decision variable (input variables the Solver is allowed to modify to reach an optimal solution) for each of the beer packs available, named according to the names we created in our dictionary, and add it to the Model, specifying that each of these decisions has to be a positive integer, 

* We create a mathematical expression (in Solver speak, a Term) for the total number of beer bottles delivered, **bottlesDelivered**, which is the sum across all available beer packs of the number of bottles in the pack, multiplied by the quantity of that pack we will deliver – which is the decision variable corresponding to that beer pack. To do this, we use a SumTermBuilder, a utility class somewhat similar to a StringBuilder, allowing us to add elements of a Sum, and converting them to a Term once all elements have been added, 

* We define our goal, name it, and add it to the Model: we want to Minimize the extra bottles shipped, which corresponds to bottlesDelivered – target, 

* We add a constraint to the model, specifying that the number of extra bottles must be at least zero. The reason we need this constraint is that without it, the idea combination would be to ship nothing, because shipping zero units of each Beer Pack would minimize our Goal, 

* We call Solve to tell the Solver to work its magic, 

* We retrieve the value of each Decision from the Solution proposed by the Solver, and match it with our Dictionary to retrieve the number of bottles in the corresponding Beer Pack, and compute the total number of bottles shipped. Note how the quantity is converted back to an integer: even though we constrained Decisions to be integers, they always come back as doubles, and need to be converted back. 

* and… we are done! 

So is this worth the effort, compared to the Sieve approach we presented last time? Well, it depends a bit on what you are after. The upside of the Sieve is that it runs typically much faster (based on a rough comparison test I ran), using familiar code any developer can understand. 

On the other hand, there are a few benefits to the Solver code. First, in my opinion, the resulting code is much more expressive and intention-revealing, once you get past the domain-specific vocabulary. It is not too difficult to figure out what problem we are after, by simply scanning through the code. By contrast, the Sieve is heavy on the “how”, but not very clear on the “why”.

Then, while the Sieve produced the total number of bottles closest to the desired quantity, the solver delivers something much better – how to achieve that solution. We are not returning that information explicitly here, but the Solution tells you exactly how much of each Beer Pack should be shipped. Getting that information from the Sieve would require quite a bit more coding.

That’s it for today! Feel free to let me know your thoughts or ask questions in the comments – and next time, we’ll see if we can find a recursion-based solution, and if some of the work can be parallelized.
