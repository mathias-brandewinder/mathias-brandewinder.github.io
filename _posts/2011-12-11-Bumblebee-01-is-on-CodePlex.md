---
layout: post
title: Bumblebee 0.1 is on CodePlex
tags:
- F#
- Bee-Colony
- Algorithms
- Search
- Parallelism
- TPL
- Bumblebee
---

Yesterday, I made the first version of [**Bumblee** public on Codeplex](http://bumblebee.codeplex.com/). Version 0.1 is an Alpha release, meaning that it’s usable, but still rough around the edges.  

What is Bumblebee? It is an Artificial Bee Colony (ABC) algorithm, a randomized search method which mimics the behavior of bee hives. Given a search problem, the algorithm will dispatch Scout bees to look for new solutions, and Active bees to explore around known solutions. Once their search is complete, bees return to the Hive and share information with Inactive bees, and new searches are allocated based on the information available so far.  

I have multiple goals with Bumblebee. I came across the algorithm for the first time in [this article](http://msdn.microsoft.com/en-us/magazine/gg983491.aspx), which illustrates it on the Traveling Salesman Problem with a C# implementation. I enjoyed the article, but wondered if I could     

* parallelize the algorithm to use multiple cores,    
* provide a general API to run arbitrary problems.   

… and I figured it would be a good sample project to sharpen my F# skills.  

For the parallelization part, I decided to use the Task Parallel Library: the Hive creates Tasks for each bee beginning a search, which returns to a Queue to be processed and share the search result with the inactive bees in the Hive ([see outline here]({{ site.url }}/2011/09/05/Parallelizing-the-BeeHive/).  

Deciding on a design for the API took some back and forth, and will likely evolve in the next release. 

The API should:     

* accommodate any problem that can be solved by that approach,    
* be reasonably simple to use by default,    
* limit parallelization problems, in particular around random numbers generation,    
* be palatable for F# and C# users.   

Regarding the first point, 3 things are needed to solve a problem using ABC: Scouts need to know how to find new random solutions, Active bees need to be able to find a random neighbor of a solution, and solutions need to be comparable. I figured this could be expressed via 3 functions, held together in a **Problem** class:     

* a generator, which given a RNG returns a new random solution,    
* a mutator, which given a RNG + solution tuple, returns a random neighbor of the solution,    
* an evaluator, which given a solution returns a float, measuring the quality of the solution.   

You can see the algorithm in action in the TspDemo console application included in the source code.  

I opted to have the Random Number Generator as an argument because the algorithm is responsible for spawning Tasks, and is therefore in a good position to provide a RNG that is safe to use, relieving the client of the responsibility of creating RNGs. I’ll probably rework this a bit, though, because I don’t like the direct dependency on Random; it is not very safe, and I would like to provide the ability to use whatever RNG users may happen to prefer.  

The reason I chose to have the evaluator return a float (instead of using IComparable) is because I figured it might be interesting to have a measure which allowed the computation of rates of improvements in solution quality.  

As for simplicity, I ended up with a main class **`Solver`** with 2 main methods. **`Search(Problem)`** initiates a search as a Task, and goes on forever until **`Stop( )`** is called. The Solver exposes an event, **`FoundSolution`**, which fires every time an improvement is found, and returns a **`SolutionMessage`**, containing the solution, its quality, and the time of discovery. It is the responsibility of the user to decide when to stop the search, based on the information returned via the events.  

By default, the Solver is configured with “reasonable” parameters, but if needed, they are exposed via properties, which can be modified before the search is initiated.  

No effort has gone for the first release to make this C# friendly – this, and abstracting the RNG, are the goals of the next release.  

I would love to get feedback, both on the overall design and the code itself! You can download the project from [here](http://bumblebee.codeplex.com/).
