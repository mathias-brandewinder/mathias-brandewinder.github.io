---
layout: post
title: Sierpinski Madness and overloading operators
tags:
- Sierpinski
- Geometry
- Operator-Overloading
- F#
- Fun
- Fractal
---

In a previous post, I looked at creating a [Sierpinski triangle using F# and WPF]({{ site.url }}/2012/03/16/Sierpinski-triangle-WPF-remix/). One of the pieces I was not too happy about was the function I used to transform a Triangle into a next generation triangle:  

``` fsharp
type Point = { X:float; Y:float }
type Triangle = { A:Point; B:Point; C:Point }

let transform (p1, p2, p3) =
   let x1 = p1.X + 0.5 * (p2.X - p1.X) + 0.5 * (p3.X - p1.X)
   let y1 = p1.Y + 0.5 * (p2.Y - p1.Y) + 0.5 * (p3.Y - p1.Y)
   let x2 = p1.X + 1.0 * (p2.X - p1.X) + 0.5 * (p3.X - p1.X)
   let y2 = p1.Y + 1.0 * (p2.Y - p1.Y) + 0.5 * (p3.Y - p1.Y)
   let x3 = p1.X + 0.5 * (p2.X - p1.X) + 1.0 * (p3.X - p1.X)
   let y3 = p1.Y + 0.5 * (p2.Y - p1.Y) + 1.0 * (p3.Y - p1.Y)
   { A = { X = x1; Y = y1 }; B = { X = x2; Y = y2 }; C= { X = x3; Y = y3 }}
``` 

Per se, there is nothing wrong with the transform function: it takes 3 points (the triangle corners), and returns a new Triangle. However, what is being “done” to the triangle is not very expressive – and the code looks rather ugly, with clear duplication (the exact same operation is repeated on the X and Y coordinates of every point).

Bringing back blurry memories from past geometry classes, it seems we are missing the notion of a [Vector](http://en.wikipedia.org/wiki/Ren%C3%A9_Descartes). What we are doing here is taking corner p1 of the Triangle, and adding a linear combinations of the edges p1, p2 and p1, p3 to it, which can be seen as 2 Vectors (p2 – p1) and (p3 – p1). Restated that way, here is what the transform function is really doing:

```
A –> A + 0.5 x AB + 0.5 x AC

A –> A + 1.0 x AB + 0.5 AC

A –> A + 0.5 x AB + 1.0 x AC 
```

In graphical form, the first transformation can be represented as follows:

![image]({{ site.url }}/assets/2012-03-25-image_thumb_14.png)

<!--more-->

In order to achieve this, we need to define a few elements: a `Vector`, obviously, a way to create a `Vector` from two Points, to add Vectors, to scale a Vector by a scalar, and to translate a Point by a Vector. Let’s do it:

``` fsharp
type Vector = 
   { dX:float; dY:float }
   static member (+) (v1, v2) = { dX = v1.dX + v2.dX; dY = v1.dY + v2.dY }
   static member (*) (sc, v) = { dX = sc * v.dX; dY = sc * v.dY }

type Point = 
   { X:float; Y:float }
   static member (+) (p, v) = { X = p.X + v.dX; Y = p.Y + v.dY }
   static member (-) (p2, p1) = { dX = p2.X - p1.X; dY = p2.Y - p1.Y }

type Triangle = { A:Point; B:Point; C:Point }
``` 

Thanks to operators overloading, the transform function can now be re-phrased in a much more palatable way:

``` fsharp
let transform (p1:Point, p2, p3) =
   let a = p1 + 0.5 * (p2 - p1) + 0.5 * (p3 - p1)
   let b = p1 + 1.0 * (p2 - p1) + 0.5 * (p3 - p1)
   let c = p1 + 0.5 * (p2 - p1) + 1.0 * (p3 - p1)
   { A = a; B = b; C = c }
``` 

… and we are done. The code (posted on [**fsSnip.net**](http://fssnip.net/ba) works exactly as before, but it’s way clearer.

It can also be tweaked more easily now. I got curious about what would happen if slightly different transformations were applied, and the results can be pretty fun. For instance, with a minor modification of the transform function…

``` fsharp
let transform (p1:Point, p2, p3) =
   let a = p1 + 0.55 * (p2 - p1) + 0.5 * (p3 - p1)
   let b = p1 + 1.05 * (p2 - p1) + 0.45 * (p3 - p1)
   let c = p1 + 0.5 * (p2 - p1) + 0.95 * (p3 - p1)
   { A = a; B = b; C = c }
``` 

… we get the following, bloated “Sierpinski triangle”:

![BeerPinski-triangle]({{ site.url }}/assets/2012-03-25-BeerPinski-triangle_thumb.png)

Add a bit of transparency, some more tweaks of the linear combinations, 

``` fsharp
let transform (p1:Point, p2, p3) =
   let a = p1 + 0.3 * (p2 - p1) + 0.6 * (p3 - p1)
   let b = p1 + 0.8 * (p2 - p1) + 0.3 * (p3 - p1)
   let c = p1 + 0.6 * (p2 - p1) + 1.1 * (p3 - p1)
   { A = a; B = b; C = c }
``` 

and things get much wilder:

![SnowflakePinski-triangle]({{ site.url }}/assets/2012-03-25-SnowflakePinski-triangle_thumb.png)

I don’t think these are really Sierpinski triangles any more, but I had lots of fun playing with this, and figured someone else might enjoy it, too… If you find a nice new combination, post it in the comments!

Source code: [**fsSnip.net**](http://fssnip.net/ba)
