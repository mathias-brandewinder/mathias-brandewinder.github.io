---
layout: post
title: On the road from C# to F# (2)
tags:
- Foreach
- Aggregate
- Linq
- Fold
- Functional
---

One of the immediate benefits I saw in digging into F# is that it gave me a much better understanding of LINQ and lambdas in C#. Until recently, my usage of LINQ was largely limited to returning `IEnumerable` instead of `List<T>` and writing simpler queries, but I have avoided the more “esoteric” features. I realize that now that F# is becoming familiar to my brain, whenever I see a statement in C# which contains a `foreach`:  

``` csharp
foreach (var item in items)
{
   // do something with item.
}
``` 

… I ask myself if this could be re-written in a more functional way. Sometimes it works, sometimes not. Just like classic OO Design Patterns, functional programming has its own patterns, and I find that having a larger toolkit of patterns in the back of my mind helps criticizing my own code and think about alternatives and possible improvements.

I encountered one such case a few days ago, with the following snippet: 

``` csharp
public bool IsValid()
{
    foreach (var rule in this.rules)
    {
        if (!rule.IsSatisfied())
        {
            return false;
        }
    }

    return true;
}
``` 

There is nothing really wrong with this code. However, seeing the `foreach` statement, and an [`if` statement with a `return` and no `else` branch]({{ site.url }}/2009/12/24/On-the-road-from-C-to-F/) made me wonder how I would have done this in F# – and my immediate thought was "I’d use a [Fold](http://en.wikipedia.org/wiki/Fold_(higher-order_function))".

<!--more-->

The fold exists in LINQ; it’s called Aggregate – one of these [intimidating LINQ signatures](http://msdn.microsoft.com/en-us/library/system.linq.enumerable.aggregate.aspx):

`Aggregate(TSource)(IEnumerable(TSource), Func(TSource, TSource, TSource))`

`Aggregate(TSource, TAccumulate)(IEnumerable(TSource), TAccumulate, Func(TAccumulate, TSource, TAccumulate))`

`Aggregate(TSource, TAccumulate, TResult)(IEnumerable(TSource), TAccumulate, Func(TAccumulate, TSource, TAccumulate), Func(TAccumulate, TResult))`

Practically, what this means is "I have this collection of things, which I want to summarize into one single value – take the list, apply this method to each element, accumulate it and return it". The prototypical example is the product of a list of numbers. This is how the same function could look like, using "classic" foreach syntax, and using LINQ Aggregate:

``` csharp
public int Foreach(IEnumerable<int> integers)
{
    var runningProduct = 1;
    foreach (var integer in integers)
    {
        runningProduct = runningProduct * integer;
    }
    return runningProduct;
}

public int Aggregate(IEnumerable<int> integers)
{
    var seed = 1;
    return integers.Aggregate(
        seed, 
        (runningProduct, integer) => runningProduct * integer);
}
``` 

Note that we need to provide a seed value of 1 to the running product: if we didn’t define that starting value, the product would begin at zero, and stay at zero forever. 

For illustration, here is how this would look like in F# – nice, short and to the point:

``` fsharp
let product integers = 
  integers |> List.fold (*) 1;;
``` 

Applying the same idea to my original rule validation example, this is the LINQ version:

``` csharp
public bool IsValid()
{
    return this.rules.Aggregate(true, (x, rule) => x && rule.IsSatisfied());
}
``` 

3 months ago, I’d have kept the original version in place. Today, I ended up picking the LINQ version. I can’t quite say why – it has to do in part with the LINQ terseness, and in part with its focus on what the function intent is, rather than how it does it. On the other hand, I wonder if I would make the same decision if this was not my own code: this is very maintainable, provided that you are comfortable with LINQ, which is a big caveat.

Which one would you pick?
