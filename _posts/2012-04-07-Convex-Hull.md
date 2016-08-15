---
layout: post
title: Convex Hull
tags:
- Convex-Hull
- Algorithms
- F#
- Math
- Geometry
---

For no clear reason, I got interested in Convex Hull algorithms, and decided to see how it would look in F#. First, if you wonder what a Convex Hull is, imagine that you have a set of points in a plane – say, a board – and that you planted a thumbtack on each point. Now take an elastic band, stretch it, and wrap it around the thumbtacks. The elastic band will cling to the outermost tacks, leaving some tacks untouched. The convex hull is the set of tacks that are in contact with the elastic band; it is convex, because if you take any pair of points from the original set, the segment connecting them remains inside the hull.  

The picture below illustrates the idea - the blue thumbtacks define the Convex Hull; all the yellow tacks are included within the elastic band, without touching it.  

![Convex-Hull]({{ site.url }}/assets/2012-04-07-Convex-Hull_thumb.jpg)

There are a few algorithms around to [identify the Convex Hull](http://en.wikipedia.org/wiki/Convex_hull_algorithms) of a set of points in 2 dimensions; I decided to go with Andrew’s [monotone chain](http://en.wikibooks.org/wiki/Algorithm_Implementation/Geometry/Convex_hull/Monotone_chain), because of its simplicity.  

The insight of the algorithm is to observe that if you start from the leftmost tack, and follow the elastic downwards, the elastic turns only clockwise, until it reaches the rightmost tack. Similarly, starting from the right upwards, only clockwise turns happen, until the rightmost tack is reached. Given that the left- and right-most tacks belong to the convex hull, the algorithm constructs the upper and lower part of the hull by progressively constructing sequences that contain only clockwise turns. 

<!--more-->

To implement this with F#, we’ll need first to define a `Point`, and a function that determines whether 3 points p1, p2 and p3 turn clockwise:  

``` fsharp
type Point = { X: float; Y: float }

let clockwise (p1, p2, p3) =
   (p2.X - p1.X) * (p3.Y - p1.Y)
   - (p2.Y - p1.Y) * (p3.X - p1.X)
   <= 0.0
``` 

Nothing remarkable so far – [check here](http://en.wikipedia.org/wiki/Graham_scan#Algorithm) for an explanation of why the clockwise function works.

The core of the algorithm is in the following recursive function `chain`:

``` fsharp
let rec chain (hull: Point list) (candidates: Point list) =
   match candidates with
   | [ ] -> hull
   | c :: rest ->
      match hull with
      | [ ] -> chain [ c ] rest
      | [ start ] -> chain [c ; start] rest
      | b :: a :: tail -> 
         if clockwise (a, b, c) then chain (c :: hull) rest else
         chain (a :: tail) rest
``` 

The hull contains the points that have been added to the lower hull so far, and all turn clockwise, and candidates are the remaining points under consideration, which are assumed to be sorted by ascending X coordinate. The chain function will consider candidate points one by one, adding them to the hull if suitable, or remove points that were added to the hull until the candidate can be added without creating an anti-clockwise turn.

First we check whether there are candidates: if none are left, we are done and return the hull, otherwise we use pattern matching to decompose the list of candidates into `c`, the `Point` currently at the head of the candidates list, which could be added to the hull, and the `rest` of the candidates (the tail of the list).

Next, we look at our current “tentative” hull. Assuming we have already 2 points in the hull, we want to check whether adding `c` would turn clockwise from the 2 previous points in the hull. Therefore, we decompose the current hull as `b :: a :: tail`, so that `b` and `a` now correspond to the 2 last points added.

If `a b c` goes clockwise, we have no reason to reject `c` from the hull: we add `c` to the head of the hull, remove it from the candidates by taking only `rest`, the tail of the candidates, and continue constructing the chain. On the other hand, if `a b c` doesn’t go clockwise, we know `b` cannot be part of the hull, so we eliminate it, and try adding c again to `a :: tail`, the new hull.

The two first cases of the `hull` match cover the case where the hull is empty or contains only one point – in what case, we simply add the candidate to the hull and proceed, because there is no potential for a wrong turn yet.

That’s pretty much it: we can now wrap it up in a hull function, which will return the hull of a list of Points:

``` fsharp
let hull (points: Point list) =
   match points with
   | [ ] -> points
   | [ _ ] -> points
   | _ ->
       let sorted = List.sort points
       let upper = chain [ ] sorted
       let lower = chain [ ] (List.rev sorted)
       List.append (List.tail upper) (List.tail lower)
``` 

If we have less that 2 points, we simply return the points (it is already a trivial convex hull); otherwise, we sort the list of Points, which, because they are records, will be lexicographically sorted (i.e. they will be sorted by ascending X, and by ascending Y for Points having the same X coordinate). We create the lower and upper hull by traversing the list of points in both directions, and merge them together, removing the head of each list, which are duplicated (each procedure ends with the starting point of the other one). And we are done!

Running the following example in fsi…

``` fsharp
let a = { X = 0.0; Y = 0.0 }
let b = { X = 2.0; Y = 0.0 }
let c = { X = 1.0; Y = 2.0 }
let d = { X = 1.0; Y = 1.0 }
let e = { X = 1.0; Y = 0.0 }
let test = [a;b;c;d;e]
hull test;;
``` 

… produces the following result, corresponding to the points c, a, e, b:

``` fsharp
>val it : Point list = [{X = 1.0;
                        Y = 2.0;}; {X = 0.0;
                                    Y = 0.0;}; {X = 1.0;
                                                Y = 0.0;}; {X = 2.0;
                                                            Y = 0.0;}]
``` 

![image]({{ site.url }}/assets/2012-04-07-image_thumb_15.png)

When I began with F#, coming from a C# background, I wasn’t comfortable with pattern matching: I got the idea on a conceptual level, but couldn’t see how to use it. In this example, it felt like a natural fit, and avoiding indexes clarifies a lot what the algorithm is doing.

The complete code is posted below – I also posted it on [FsSnip.net](http://fssnip.net/bt). As usual, comments are welcome!

``` fsharp
module ConvexHull

type Point = { X: float; Y: float }

let clockwise (p1, p2, p3) =
   (p2.X - p1.X) * (p3.Y - p1.Y)
   - (p2.Y - p1.Y) * (p3.X - p1.X)
   <= 0.0

let rec chain (hull: Point list) (candidates: Point list) =
   match candidates with
   | [ ] -> hull
   | c :: rest ->
      match hull with
      | [ ] -> chain [ c ] rest
      | [ start ] -> chain [c ; start] rest
      | b :: a :: tail -> 
         if clockwise (a, b, c) then chain (c :: hull) rest else
         chain (a :: tail) rest

let hull (points: Point list) =
   match points with
   | [ ] -> points
   | [ _ ] -> points
   | _ ->
       let sorted = List.sort points
       let upper = chain [ ] sorted
       let lower = chain [ ] (List.rev sorted)
       List.append (List.tail upper) (List.tail lower)
``` 
