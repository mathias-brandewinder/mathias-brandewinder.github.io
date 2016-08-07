---
layout: post
title: On the road from C# to F#
tags:
- C#
- F#
- Languages
- Guard-Clause
- Design-Patterns
---

After spending a few years working mostly with C#, it has become a natural, comfortable way to think about programming problems. I won&rsquo;t complain about it -- comfort is nice. At the same time, I strongly believe in questioning what you do, especially the un-stated assumptions. When you start doing things a certain way without asking yourself if this is indeed the way to go, you are on a dangerous path, especially in a fast-evolving field like software engineering. So when I read the advice to"**learn one new language every year**", it resonated, and I decided to give a shot at F#. 

I purchased "[Programming F#](http://oreilly.com/catalog/9780596153656)", and I am working my way through the [Project Euler problems](http://projecteuler.net/index.php?section=problems) as an exercise.

This is my first exposure to functional languages, and it has proven a very stimulating mental exercise so far. One particular aspect I have struggled with is `if ... then` statements. [Chris Smith](http://blogs.msdn.com/chrsmith/) says that "if expressions work just as you would expect". That's sort of true, except for the fact that an `if ... then` statement with no `else` clause can't return a value.

This made me realize how much I use single-pronged if statements in C#, [guard clauses](http://www.refactoring.com/catalog/replaceNestedConditionalWithGuardClauses.html) being a prime example.

<!--more-->

As a  practical example, consider the following. If I were to identify whether a particular number is prime in C#, I would write something along these lines:

``` csharp
public bool IsPrime(int n)
{
    for (int i = 2; i < n; i++)
    {
        if (n % i == 0)
        {
            return false;
        }
    }
    return true;
}
``` 

This code is obviously sub-optimal, but that&rsquo;s not the point here. The direct transposition in F# just won&rsquo;t execute, because the if statement can't return a value: 

``` fsharp
let IsPrime n =
  for i in 2 .. n - 1 do
    if n % d = 0
      false  
  true;;
``` 

I won't claim that the following is the"right" way to do it, but it is the closest equivalent I could come up with:

``` fsharp
let IsPrime n =
  seq {2 .. n-1} |> Seq.exists (fun i -> n % i = 0) |> not
``` 

This could be loosely translated as "look up the sequence of 2 to n-1, and if there is a divider, it is not a prime number".

I found this example interesting for a few reasons. 

First, it made me realize how deeply the pattern `if some condition is true, do something` was ingrained in my brain. Then, it made me wonder what the upside of that constraint was. I won't pretend any deep understanding of functional languages yet (it's just been a week so far), but one thing I noticed was that the idea of mutually exclusive, collectively exhaustive partitions seems to be very present in F#. One issue with sequential guard clauses is that they are order-dependent, and can leave some cases uncovered in a non-obvious way. Forcing each if to have an else counterpart removes that problem by construction.

I am still unsure whether this idea will make it into my C# code, and what form it would take. I can&rsquo;t quite see yet how to do this without going back to

While less obvious in this example, the other realization I came to was that I was still only marginally using lambdas and LINQ in C#, and resorted heavily to explicit iterations through collections. I guess the reason is in part the force of habit, and in part an ill-formed suspicion that by giving up explicit iteration, I may be suffering some performance penalty. Lists and Sequences are deeply baked in F#, and make your life easier  -  I am now warming to using the equivalent extension methods in my C# code.
