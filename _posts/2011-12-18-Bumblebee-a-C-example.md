---
layout: post
title: Bumblebee&#58; a C# example
tags:
- Bumblebee
- F#
- C#
- Algorithms
- WPF
- TPL
- Artificial-Bee-Colony
---

I spent some time this week putting together an example illustrating how to use [Bumblebee](http://bumblebee.codeplex.com) from C# code. I figured it would be more exciting to have a graphical representation of the bee colony working on the traveling salesman problem, so I put together a small WPF application which creates a random set of cities, and displays the improvements live as they are found by the algorithm.

Here is a screen capture of the first 10 seconds of a 100-cities problem:

<iframe width="420" height="315" src="https://www.youtube.com/embed/UpfYrMHjMMA" frameborder="0" allowfullscreen></iframe>
*Bumblebee working on 100 cities*

The source code for the example is available in the current head revision, under the TspDemo.CSharp project; I&rsquo;ll push an &ldquo;official&rdquo; downloadable version as soon as I have time for some cleanup. Note that, besides a reference to Bumblebee, a reference to FSharp.Core 4.0 is required - the rest is all pure C#.

<!--more-->

The goal of the algorithm is to search for the shortest path connecting every city in a list; a City is defined as a simple struct, which has a name and 2 coordinates:

``` csharp
using System.Diagnostics;

[DebuggerDisplay("{Name}")]
public struct City
{
    private readonly string name;
    private readonly double x;
    private readonly double y;

    public City(string name, double x, double y)
    {
        this.name = name;
        this.x = x;
        this.y = y;
    }

    public string Name
    {
        get { return this.name; }
    }

    public double X
    {
        get { return this.x; }
    }

    public double Y
    {
        get { return this.y; }
    }
}
``` 

The core of the search algorithm is in the Tsp class, which defines 3 core methods, and an auxiliary method:
``` csharp
using System;
using System.Collections.Generic;
using System.Linq;

public class Tsp
{
    public static IList<City> Shuffle(Random rng, IList<City> cities)
    {
        var shuffled = new List<City>(cities);
        for (var i = cities.Count() - 1; i >= 1; i--)
        {
            var j = rng.Next(i + 1);
            var temp = shuffled[i];
            shuffled[i] = shuffled[j];
            shuffled[j] = temp;
        }

        return shuffled;
    }

    public static IList<City> Swap(Random rng, IList<City> cities)
    {
        var count = cities.Count();
        var first = rng.Next(count);
        var second = rng.Next(count);

        var swapped = new List<City>(cities);
        var temp = swapped[first];
        swapped[first] = swapped[second];
        swapped[second] = temp;

        return swapped;
    }

    public static double Length(IList<City> cities)
    {
        var length = 0d;
        for (var i = 0; i < cities.Count() - 1; i++)
        {
            length = length + Distance(cities[i], cities[i + 1]);
        }

        length = length + Distance(cities[cities.Count() - 1], cities[0]);
        return length;
    }

    public static double Distance(City city1, City city2)
    {
        return Math.Sqrt(
        Math.Pow((city1.X - city2.X), 2d) +
        Math.Pow((city1.Y - city2.Y), 2d));
    }
}
``` 

The `Shuffle` method returns a random shuffle of a list of Cities, `Swap` simply permutes 2 cities in the itinerary, and `Length` computes the total length of the circuit, using the `Distance` method, which computes the Euclidean distance between two cities.

The actual resolution is happening in the `RouteViewModel`. The `StartSearch` method passes the 3 methods to the Bumblebee solver, with a list of Cities, and begins the search:

``` csharp
private void StartSearch(IList<City> cities)
{
    var generator = new Func<Random, IList<City>>(
        (random) => Tsp.Shuffle(random, cities));

    var mutator = new Func<Tuple<Random, IList<City>>, IList<City>>(
        (tuple) => Tsp.Swap(tuple.Item1, tuple.Item2));

    var evaluator = new Func<IList<City>, double>(
        (circuit) => -Tsp.Length(circuit));

    var problem = new Problem<IList<City>>(generator, mutator, evaluator);

    this.solver.Search(problem);
    this.IsSearching = true;
}
``` 

In the `ViewModel` constructor, the event `solver.FoundSolution` is hooked to the `SolutionFound` handler, which retrieves the list of Cities from the latest solution found, and transforms it to a `PointCollection`, a collection of Points bound to a Polygon in the WPF main window (this post from [Bea Stollnitz](http://bea.stollnitz.com/blog/?p=35) was very helpful in the process). Because I am lazy, I used the [MVVMLight library](http://mvvmlight.codeplex.com/) to handle the WPF tedium - in this case, I leveraged the `DispatcherHelper` to update the UI thread with a solution that has been found outside of that thread:

``` csharp
private void SolutionFound(object sender, SolutionMessage<IList<City>> args)
{
    DispatcherHelper.CheckBeginInvokeOnUI(
        () =>
        {
            var points = args.Solution.Select(city => new Point(city.X, city.Y));
            this.Points = new PointCollection(points);
            this.Quality = args.Quality;
            this.DiscoveryTime = args.DateTime;
        });
}
``` 

That's pretty much it, the rest is fairly standard. Below are two more videos; they are probably not going to make any waves on YouTube, but they show the algorithm in action, on a larger problem (500 cities), and on a few small ones. I noticed that the algorithm usually starts well, but gets stumped for sometimes very long periods once it reaches &ldquo;decent&rdquo; solutions with multiple good subsequences of cities. I have to play with different Mutate functions, to see if a different neighbor searches improves things, and to look into adding some path-crossing removal functions. On the other hand, I find the results pretty fun for such a small amount of search code!

<iframe width="420" height="315" src="https://www.youtube.com/embed/8_PXfJveoIg" frameborder="0" allowfullscreen></iframe>

*10 minutes of search on a 500-cities problem*

<iframe width="420" height="315" src="https://www.youtube.com/embed/PwjkK45GH_U" frameborder="0" allowfullscreen></iframe>

*A few 25 cities problems*
