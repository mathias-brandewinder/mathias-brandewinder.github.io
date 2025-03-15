---
layout: post
title: Delaunay triangulation with Bowyer-Watson&#58; circumcircle
tags:
- F#
- Algorithms
- Geometry
---

In my last installment, I started revisiting some old code of mine around 
[Delaunay triangulation][1], the dual of a Voronoi diagram. My goal is to 
implement the [Bowyer–Watson algorithm][2], and perhaps use it for procedural 
map generation at some point.  

I will follow the pseudo-code outlined on the Wikipedia page, and work my way 
through it. Last time I took care of the initialization step, computing an 
initial super-triangle large enough to completely contain all the points:  

```
function BowyerWatson (pointList)
    triangulation := empty triangle mesh data structure
    add super-triangle to triangulation
```

Today I will tackle the next step:  

```
for each point in pointList do
    badTriangles := empty set
    for each triangle in triangulation do
        if point is inside circumcircle of triangle
            add triangle to badTriangles
```

<!--more-->

I need 2 new pieces of machinery here:  

- Determine if a Point is inside a Circle,  
- Identify the Circumcircle of a Triangle.  

## Circumcircle of a Triangle

First, what _is_ the [circumcirle of a triangle][3]? Per Wikipedia again, the 
circumcircle of a triangle is the circle that passes through all 3 corners of 
the triangle.  

Let's compute that circle. We already defined `Point` and `Triangle` last time, 
let's add `Circle` too:  

``` fsharp
type Point = { X: float; Y: float }

type Triangle = {
    A: Point
    B: Point
    C: Point
    }

type Circle = {
    Center: Point
    Radius: float
    }
```

If that circle goes through all 3 corners of the triangle, the radius will be 
the distance from its center to any corner. We will need to compute the 
distance between two points, let's get that out of the way: 

``` fsharp
let distance (a: Point, b: Point) =
    sqrt (pown (a.X - b.X) 2 + pown (a.Y - b.Y) 2)
```

Fortunately, computing the coordinates of the [center of the circumcircle][4] 
is a well-known problem, I will lazily lift the formula, which gives us the 
following function:  

``` fsharp
let circumCircle (triangle: Triangle) =

    let a, b, c = triangle.A, triangle.B, triangle.C

    let d = 2.0 * (a.X * (b.Y - c.Y) + b.X * (c.Y - a.Y) + c.X * (a.Y - b.Y))
    let x =
        (pown a.X 2 + pown a.Y 2) * (b.Y - c.Y)
        +
        (pown b.X 2 + pown b.Y 2) * (c.Y - a.Y)
        +
        (pown c.X 2 + pown c.Y 2) * (a.Y - b.Y)
    let y =
        (pown a.X 2 + pown a.Y 2) * (c.X - b.X)
        +
        (pown b.X 2 + pown b.Y 2) * (a.X - c.X)
        +
        (pown c.X 2 + pown c.Y 2) * (b.X - a.X)

    let center = { X = x / d; Y = y / d }
    let radius = distance (center, a)

    { Center = center; Radius = radius }
```

It's not particularly pretty, but it does the job. Or... does it? Let's check, 
by re-using last week's code, computing a super-triangle, and its 
circumcircle:  

``` fsharp
let points =
    let rng = Random 0
    List.init 20 (fun _ ->
        {
            X = rng.NextDouble() * 100.
            Y = rng.NextDouble() * 100.
        }
        )

let triangle = BowyerWatson.superTriangle points
let circum = BowyerWatson.circumCircle triangle

[
    // render circumcircle
    circle
        [
            Style.Stroke (Stroke.Color "black")
            Style.Fill (Fill.Color "none")
        ]
        (circum.Center, circum.Radius)
    // render super triangle as a polygon
    polygon
        [
            Style.Fill (Fill.Color "lightyellow")
            Style.Stroke (Stroke.Color "black")
            Style.Stroke (Stroke.Width 1)
            Style.Stroke (Stroke.Dashes [ 1; 1 ])
        ]
        [ triangle.A; triangle.B; triangle.C ]
]
|> Plot.plot (400, 400)
```

This produces the following SVG - things appear to be working as expected:  

<svg width="400" height="400" viewbox="-69.33438983881598 -44.86570933462417 240.89842650483317 240.89842650483317">
  <circle cx="51.114823413600604" cy="75.58350391779241" r="120.44921325241658" stroke="black" fill="none"/>
  <polygon points="-45.035964830329625,3.0366990729406003 147.26561165753083,3.0366990729406003 51.1148234136006,196.032717170209" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
</svg>

While we are at it, the algorithm also contains the following check:  

```
if point is inside circumcircle of triangle
```

Let's take care of that quick:  

``` fsharp
    type Circle = {
        Center: Point
        Radius: float
        }

    let distance (a: Point, b: Point) =
        sqrt (pown (a.X - b.X) 2 + pown (a.Y - b.Y) 2)

    [<RequireQualifiedAccess>]
    module Circle =
        let isInside (circle: Circle) (pt: Point) =
            distance (pt, circle.Center) <= circle.Radius
```

As expected, the 3 corners of the triangle are inside the circumcircle:  

``` fsharp
[ triangle.A; triangle.B; triangle.C ]
|> List.map (Circle.isInside circum)

// val it: bool list = [true; true; true]
```

## Parting thoughts

Nothing particularly fancy in this episode, this was mainly re-using a math 
formula. The good news is, I think we are over the geometry part. The rest of 
the algorithm revolves around updating a set of triangles as we add points to 
the triangulation one by one, which should be more about data structures.  

One interesting edge case of the circumcircle function is the situation where 
the 3 points are aligned (and distinct), that is, the triangle is really just a 
straight line. In this case, there is no circle that can pass through all 3 
corners, which we can confirm by running our code on an example of such a 
situation:  

``` fsharp
{
    A = { X = 0.0; Y = 0.0 }
    B = { X = 0.0; Y = 1.0 }
    C = { X = 0.0; Y = 2.0 }
}
|> BowyerWatson.circumCircle

val it: Circle = { Center = { X = -infinity
                              Y = nan }
                   Radius = nan }
```

I will ignore that issue for now, but we will probably have to revisit that 
later. We should be fine for as long as none of the points we want to 
triangulate are aligned. As a first step, we should be able to recognize that 
situation by changing the signature of `circumCirle` from 
`Triangle -> Circle` to `Triangle -> Option<Circle>`. However, that only 
postpones the real issue, which is "what should we do if we add a point that 
creates a flat triangle"? But we can deal with that later, when we actually 
go through the rest of the algorithm and create / update triangles.  

[1]: https://en.wikipedia.org/wiki/Delaunay_triangulation
[2]: https://en.wikipedia.org/wiki/Bowyer%E2%80%93Watson_algorithm
[3]: https://en.wikipedia.org/wiki/Circumcircle
[4]: https://en.wikipedia.org/wiki/Circumcircle#Cartesian_coordinates_2