---
layout: post
title: Delaunay triangulation with Bowyer-Watson&#58; initial super triangle
tags:
- F#
- Algorithms
- Geometry
---

A while ago, I got interested in [Delaunay triangulation][1], because 
it seemed to be a good building block for procedural map generation, 
city maps in particular. I started implementing the [Bowyer–Watson algorithm][2], 
but ended up putting this side-project on ice, because, well, life got busy. 
I had something messy somewhat working back then, and figured it would be fun 
to revisit that code and try to get it into shape.  

In this post, I'll revisit one minor piece of the algorithm that seemed easy, 
but gave me some trouble: the calculation of the so-called "super triangle".  

The algorithm is quite interesting. The first step is to compute a triangle 
that contains all the points we want to triangulate, adding points one by one 
and updating the triangulation, until there is nothing left to add. At that point, 
the initial triangle and anything connected to it is removed, and the triangulation 
is done.  

## Super Triangle

What I am after here is fairly simple: given a collection of points on the plane, 
find 3 points (the super triangle) that enclose every point in the list.  

Let's illustrate with an example. Suppose we have 5 points, like in the example below. 
The triangle ABC in yellow is a valid super triangle:  

<svg width="400" height="400" viewbox="50 0 300 300">
    <!-- bounding triangle -->
    <polygon points="100,250 300,250 200,50" fill="lightyellow" stroke="Black" stroke-width="1" />
    <!-- bounding triangle labels -->
    <text x="90" y="270">A</text>
    <text x="300" y="270">B</text>
    <text x="200" y="40">C</text>
    <!-- points -->
    <circle cx="150" cy="220" r="3" fill="White" stroke="Black" stroke-width="1"></circle>
    <circle cx="220" cy="210" r="3" fill="White" stroke="Black" stroke-width="1"></circle>
    <circle cx="200" cy="200" r="3" fill="White" stroke="Black" stroke-width="1"></circle>
    <circle cx="160" cy="150" r="3" fill="White" stroke="Black" stroke-width="1"></circle>
    <circle cx="190" cy="250" r="3" fill="White" stroke="Black" stroke-width="1"></circle>
</svg>

<!--more-->

ABC isn't the only valid super triangle. Many other triangles, some smaller, some larger, would do 
the job equally well. Our problem here is to find reasonably effectively a triangle that works.  

My first take was to start by finding a circle that contains all the points, which is not too 
complicated. Pick a center for the circle, perhaps the average position of all the points, compute 
the distance between every point and the center, take the largest value and use that as the radius.  

However, that doesn't really help us: that circle doesn't immediately give us a valid triangle. 
All we have is a different problem: finding a triangle that fully contains that circle. This 
is not super hard, but after making a few silly mistakes (trigonometry was never something 
I enjoyed) I got irritated and decided to try something simpler.  

The thought went something like this: what if instead of a circle, I could find a square that 
contains all the points? Would that help me find a triangle enclosing all the points?  

As it turns out, yes:  

<svg width="400" height="400" viewbox="50 0 300 300">
    <!-- bounding square -->
    <polygon points="150,150 150,250 250,250 250,150" style="fill:lightyellow;stroke: Black;stroke-width:1" />
    <!-- 3 identical triangles -->
    <polygon points="100,250 200,250 150,150" stroke-dasharray="1,1" fill="none" stroke="Black" stroke-width="1" />
    <polygon points="200,250 300,250 250,150" stroke-dasharray="1,1" fill="none" stroke="Black" stroke-width="1" />
    <polygon points="150,150 250,150 200,50" stroke-dasharray="1,1" fill="none" stroke="Black" stroke-width="1" />
    <!-- bounding triangle labels -->
    <text x="90" y="270">A</text>
    <text x="300" y="270">B</text>
    <text x="200" y="40">C</text>
</svg>

Starting from a yellow square like above, I can easily create a triangle ABC that covers it. 
That triangle is formed of 4 equal smaller triangles, which all have simple properties:  

- They are isosceles (2 sides have the same length), 
- The base has the same length as the square, 
- The altitude (height) has the same length as the square.  

This is also dead-easy to code:  

``` fsharp
type Point = { X: float; Y: float }

type Triangle = {
    A: Point
    B: Point
    C: Point
    }

module BowyerWatson =

    let superTriangle (points: seq<Point>): Triangle =

        let xs =
            points 
            |> Seq.map (fun pt -> pt.X)
            |> Array.ofSeq
        let xMin = xs |> Array.min
        let xMax = xs |> Array.max

        let ys =
            points
            |> Seq.map (fun pt -> pt.Y)
            |> Array.ofSeq
        let yMin = ys |> Array.min
        let yMax = ys |> Array.max

        let squareWidth =
            max (xMax - xMin) (yMax - yMin)

        let pointA = {
            X = xMin - 0.5 * squareWidth
            Y = yMin
            }

        let pointB = {
            X = xMin + 1.5 * squareWidth
            Y = yMin
            }

        let pointC = {
            X = xMin + 0.5 * squareWidth
            Y = yMin + 2.0 * squareWidth
            }

        {
            A = pointA
            B = pointB
            C = pointC
        }
```

First, we identify the bounding square, by finding the min and max values 
of the X and Y coordinates. We compute the largest difference, which will 
be the size of the square. We have now a "virtual" square, anchored at 
`xMin, yMin`, and computing the 3 points A, B and C is straightforward. 

## Visual check

Let's see if we can confirm visually that this works as expected.  

We create first a sample of 20 random points:  

``` fsharp
open System

let points =
    let rng = Random 0
    List.init 20 (fun _ ->
        {
            X = rng.NextDouble() * 100.
            Y = rng.NextDouble() * 100.
        }
        )
```

We can now compute a super triangle:  

``` fsharp
let triangle = BowyerWatson.superTriangle points
```

And we can render the result, with a little home-cooked DSL to convert to SVG:  

``` fsharp
[
    // render super triangle as a polygon
    polygon
        [
            Style.Fill (Fill.Color "lightyellow")
            Style.Stroke (Stroke.Color "black")
            Style.Stroke (Stroke.Width 1)
            Style.Stroke (Stroke.Dashes [ 1; 1 ])
        ]
        [ triangle.A; triangle.B; triangle.C ]
    // render each point
    for pt in points do
        point
            [
                Style.Fill (Fill.Color "white")
                Style.Stroke (Stroke.Color "black")
            ]
            (pt, 4)
]
|> Plot.plot (400, 400)
```

... we get the following result:  

<svg width="400" height="400" viewbox="-45.209575232681615 -0.9633009270593997 192.9960180972684 196.9960180972684">
  <polygon points="-45.209575232681615,3.0366990729406003 147.78644286458677,3.0366990729406003 51.28843381595259,196.032717170209" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <circle cx="72.62432699679599" cy="81.73253595909688" r="4" fill="white" stroke="black"/>
  <circle cx="76.80226893946634" cy="55.81611914365372" r="4" fill="white" stroke="black"/>
  <circle cx="20.60331540210327" cy="55.88847946184151" r="4" fill="white" stroke="black"/>
  <circle cx="90.60270660119258" cy="44.217787331071584" r="4" fill="white" stroke="black"/>
  <circle cx="97.75497531413798" cy="27.370445768987032" r="4" fill="white" stroke="black"/>
  <circle cx="29.190628476995332" cy="46.73147003479836" r="4" fill="white" stroke="black"/>
  <circle cx="63.26590728166788" cy="46.95118784296847" r="4" fill="white" stroke="black"/>
  <circle cx="98.21512531406019" cy="3.0366990729406003" r="4" fill="white" stroke="black"/>
  <circle cx="86.23701538249712" cy="99.53470812157481" r="4" fill="white" stroke="black"/>
  <circle cx="67.71811492169189" cy="31.45917930242567" r="4" fill="white" stroke="black"/>
  <circle cx="81.69079086822029" cy="84.8051783092344" r="4" fill="white" stroke="black"/>
  <circle cx="99.19021753556571" cy="3.2625198379450104" r="4" fill="white" stroke="black"/>
  <circle cx="69.99419837724147" cy="52.62841426424143" r="4" fill="white" stroke="black"/>
  <circle cx="93.4018658909024" cy="68.76202824933549" r="4" fill="white" stroke="black"/>
  <circle cx="54.68154342597422" cy="8.1109949891041" r="4" fill="white" stroke="black"/>
  <circle cx="18.712457417842213" cy="45.33271852197718" r="4" fill="white" stroke="black"/>
  <circle cx="29.717186572829814" cy="98.85437791182397" r="4" fill="white" stroke="black"/>
  <circle cx="64.26974728902324" cy="76.29635882391425" r="4" fill="white" stroke="black"/>
  <circle cx="3.039429291635486" cy="38.10045068995117" r="4" fill="white" stroke="black"/>
  <circle cx="34.31418446559188" cy="95.74551656644117" r="4" fill="white" stroke="black"/>
</svg>

## Parting thoughts

In hindsight, I am surprised that this super triangle question caused me issues earlier on. 
I suspect it's one of these situations where I started with the wrong idea of what the solution 
to the problem was, and then stayed on the wrong path for too long because I didn't want to 
accept that my initial direction was wrong.  

Once I scrapped my initial plan entirely, it was pretty quick. I took a piece of paper, 
drew a few shapes, and realized that there was a simple solution: covering the square 
with 4 equal triangles. There is something about finding a nice, clean solution to a geometry 
problem that brings me joy. As it happens, I suspect the box approach must also be much more 
efficient computationally than a trigonometry based one.  

That being said, even though the solution described here works perfectly fine, I think 
using a bounding rectangle instead of a square would work equally well, and form a 
tighter super triangle. This train of thought got me wondering about another question: 
what is the tightest super triangle for a set of points? This seems like a fun geometry 
problem, but I'll let that one rest for now, I want to finish this Delaunay triangulation 
first :)

Finally, as I was working through this problem, I realized that embedding SVG 
directly in this post would be much easier than creating images, which led me to write 
a quick-and-dirty DSL to convert shapes (points and polygons) to an SVG plot. This is 
currently a bit too messy to post about, but I'll probably revisit that later as well!

Anyways, that's what I got for today! In the next installments, I will start digging 
into the Bowyer-Watson algorithm.  

[1]: https://en.wikipedia.org/wiki/Delaunay_triangulation
[2]: https://en.wikipedia.org/wiki/Bowyer%E2%80%93Watson_algorithm
