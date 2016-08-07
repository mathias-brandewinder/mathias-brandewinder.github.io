---
layout: post
title: Sometimes, TDD doesn’t flow
tags:
- Optimization
- TDD
- OO
- Design
- Mocks
---

I have been using test-driven development since I read [Kent Beck’s book](http://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530) on the topic. I loved the book, I tried it, and adopted it, simply because it makes my life easier. It helps me think through what I am trying to achieve, and I like the safety net of having a test suite which tells me exactly what I have broken. It also fits well with the type of code I write, which is usually math-oriented, with nice, tight domain objects.  

So when I decided recently to write a C# implementation of the [Simplex algorithm](http://en.wikipedia.org/wiki/Simplex_algorithm), a classic method to resolve [linear programming](http://en.wikipedia.org/wiki/Linear_programming) optimization problems, I expected a walk in the park.   

*(Side note:I am aware that re-implementing the Simplex is pointless, I am doing this as an exercise/experiment)*

Turns out, I was mistaken. I have been struggling with this project pretty much from the beginning, and unit testing hasn’t really helped so far. Unfortunately, I didn’t reach a point where I fully understand what it is that is not flowing, but I decided I would share some of the problems I encountered. Maybe brighter minds than me can help me see what I am doing wrong!

<!--more-->

## A bit of context  

If you read through the algorithm explanation, you will realize that it is very matrix-oriented. The classic way to represent and solve a linear programming problem is through the “Simplex Tableau” – any LP problem can be expressed as a tableau like the one displayed below, and a succession of pivots on the rows of the tableau will either yield the optimum solution, or conclude that there isn’t such a solution.  

 | Variable 1 | Variable 2 | Right Hand Side
___ | ___ | ___ | ___
Constraint 1 | 1.0 | 2.5 | 3.0
Constraint 2 | 0.0 | 4.5 | 2.0
Relative Cost | 5.5 | 1.5 | 3.5

To decide what transformation to apply to the tableau, the algorithm looks at the relative cost row to pick candidate variables/columns, and at the right-hand side to pick which of the candidate variable to choose and apply the transformation to.  

Given the matrix-like structure of the tableau, it is no surprise, then, than the algorithm has traditionally been implemented as a long iterative procedure which modifies an array of doubles.  

## What’s the problem?  

Here are some of the issues I ran into when attempting to implement it in an object-oriented fashion, using test-driven development.  

* Making the Tableau into a meaningful object isn’t easy. A matrix can be seen as either a collection of row vectors, or a collection of column vectors, and running the algorithm requires switching between these two views. A pivot will be applied to a row, but selecting candidate variables requires analyzing columns. Representing the tableau as an array of doubles works well to store the information, but requires re-creating rows or columns all the time to analyze them. I chose to represent the Tableau as a collection of Rows, because pivots are the most common operation performed in that context, but this makes Columns a “second-class” citizen, which feels untrue to what a Matrix is. On top of that, a Tableau is not simply a collection of vectors. Each row and Column can be treated as one, but the last row and last column are special, and require to be handled slightly differently from the others.
* I made the Simplex procedure a class, which starts with a Tableau and transforms it, based on what the current state of the Tableau is. However, I am falling into an [arrow anti-pattern](http://www.codinghorror.com/blog/archives/000486.html). Refactoring the code into smaller methods helps a bit, but it feels uncomfortable because&#160; the class begins to feel bloated with internal or public methods, exposed for testability purposes. The solution is probably to break these chunks of logic into their own testable class, but so far, coming up with meaningful abstractions hasn’t been easy, and having static utility-like classes works, but feels artificial.
* Test cases are expensive to write. To test what transformation needs to be done, I need to pass in an entire Tableau, and any non-trivial case requires something like a 3 rows, 4 columns array, which will typically return a Tableau of similar size, which needs to be verified. This is lengthy, hard to read, and this feels a lot closer to integration testing than unit testing. Mocking doesn’t help, either, because I can’t pass anything smaller than a Tableau, and Mocking an entire Tableau is worse than creating an actual instance.
* At each step, the Simplex computes an updated Tableau, and based on that Tableau, “decides” what to do next, depending on whether a dead-end has been reached, or the solution can be improved. Determining what to do next can be done by analyzing the Tableau itself, but most of the information required to make that decision is usually known through the previous step. For instance, each time a pivot is applied, one of the “basic” variables of previous iteration becomes non-basic, and all the others remain basic. So far, my approach has been to write methods which take a Tableau and return a Tableau (transformations), and methods which take a Tableau and return some information about the state (what variables to pivot on for instance), which contributes to the Arrow structure. At that point, I think a better approach would be to maintain a “state” describing what is know of the current solution, and have transformations which return an object composed of a Tableau and the “state” information.
* I keep obsessing about performance, which is an important consideration in numerical algorithms. However, that concern prevents me from concentrating on a design, and keeps me second-guessing my decisions.

## Current conclusion  

What bugs me here is not that I can’t find a solution: my current solution works (or almost works…). What bugs me is that I expected this problem to be a very good fit for object-oriented design and TDD, and it has been a struggle every step of the way – and I can’t pinpoint what I did wrong. Had I taken an old-school, procedural approach, modifying an array step by step, I would have been done in an afternoon. And – I just don’t like the way my code looks, it doesn’t feel like a good design.  

In the end, I don’t think TDD is to blame. TDD works great if you have good objects, and my problem here is that I didn’t really manage to break down the problem in smaller, well-encapsulated objects. This may have to do with the 2 dimensional array, which is hard to “divide”, but I suspect part of the problem is that [drifted off the spirit of TDD](http://gojko.net/2009/08/02/tdd-as-if-you-meant-it-revisited/): rather than write one test at a time, from requirements, I started with strong pre-conceptions of what the solution would look like, heavily biased by the existing procedural implementations I had seen before.  

So what’s next? First, finish off the implementation as I started it, in hopes that the struggle will shed some light. And then, start again, around different ideas. One such idea is to re-write the algorithm not as a “master” procedure, but rather, as a generator of steps; the completion of each step would return what next step should be performed, and the outer-most structure would have no knowledge of what to do, but simply store and execute each step. The other thought is to ditch the representation of the Tableau as a collection of rows, and simply make it a collection of coefficients attached to a variable and a constraint.
