---
layout: post
title: yield, trees and recursion
tags:
- LINQ
- Recursion
- C#
- Tree
---

I have been working with trees quite a bit lately, because I am coding something which involves probability trees: based on the state of the system, there is a number of things which can happen, each with a certain probability.  

I ended up writing a simple generic `Node` class, which can contain anything, and can have multiple children, along these lines:   

``` csharp
public class Node<T>
{
  public Node()
  {
     this.Children = new List<Node<T>>();
  }

  public T Content
  {
     get;
     set;
  }

  public List<Node<T>> Children
  {
     get;
     private set;
  }

  public bool IsLeaf
  {
     get
     {
        return (this.Children.Count() == 0);
     }
  }
}
``` 

Pretty quickly, I realized I would need to get the list of all nodes under a certain node, as well as the list of its leaves (a leaf being a node that has no children, i.e. an endpoint of the tree). This is a job tailor-made for recursion: if a node is a leaf, return it, otherwise, search further in all his children.

<!--more-->

Something like this would get the job done:

``` csharp
public static IEnumerable<Node<T>> ClassicAllNodes(Node<T> root, IList<Node<T>> nodes)
{
   nodes.Add(root);
   foreach (var child in root.Children)
   {
      ClassicAllNodes(child, nodes);
   }

   return nodes;
}
``` 

With my recent interest in things LINQ-related, I wondered if there was a way to use the [yield keyword](http://msdn.microsoft.com/en-us/library/9k7k7cf0(VS.80).aspx) here. Yield provides a way to return items as you are iterating through them, without having to explicitly create a collection to collect them, and can make for more elegant code. 

``` csharp
public static IEnumerable<int> FactorialsUnder(int max)
{
   var i = 1;
   var fact = 1;
   while (i <= max)
   {
      yield return fact;
      i++;
      fact *= i;
   }
}
``` 

My first attempt looked like this:

``` csharp
public static IEnumerable<Node<T>> AllNodesFails(Node<T> root)
{
   yield return root;
   foreach (var child in root.Children)
   {
      yield return child;
      AllNodesFails(child);
   }
}
``` 

I thought this code looked pretty elegant. Unfortunately, it has a major drawback: it completely fails to enumerate all the nodes (as you probably guessed by the name of the method). You get the root, its children, and that’s it.

After some tinkering, I ended up writing this:

``` csharp
public static IEnumerable<Node<T>> AllNodesWorks(Node<T> root)
{
   yield return root;
   foreach (var node in root.Children)
   {
      foreach (var further in AllNodesWorks(node))
      {
         yield return further;
      }
   }
}
``` 

The good news is that as far as I can tell, this works. The bad news is that I don’t find this any clearer or more elegant than the original code; arguably, the nested foreach loops are awkward looking. In fact, while I have empirical reasons to believe it works, I still have a hard time following what’s happening. Furthermore, searching into StackOverflow (another recursion) yielded interesting discussions like [this one](http://stackoverflow.com/questions/1815497/enumerating-collections-that-are-not-inherently-ienumerable/1815600#1815600) and [that one](http://stackoverflow.com/questions/2012274/c-how-to-unroll-a-recursive-structure); the gist of it being that the “straighforward” approach is inefficient. The trees I am working with right now are fairly small, which makes that issue largely irrelevant. However, replacing clear code by something potentially confusing and inefficient doesn’t seem like such a great deal, so I chalked one up for “Sometimes, doing things the old school way is just fine”.
