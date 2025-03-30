---
layout: post
title: Delaunay triangulation&#58; Bowyer-Watson algorithm
tags:
- F#
- Algorithms
- Geometry
---

In my last two posts, I did a bit of prep work leading to an implementation of 
the [Bowyer-Watson algorithm][1]. Now that we have the geometry building blocks 
we need, we can attack the core of the algorithm, and perform a Delaunay 
triangulation on a list of points.  

Rather than attempt to explain what a [Delaunay triangulation][2] is, I will 
leave that out, and simply illustrate on an example. Starting from a collection 
of 20 random points, like so:  

``` fsharp
let points =
    let rng = Random 0
    List.init 20 (fun _ ->
        {
            X = rng.NextDouble() * 100.
            Y = rng.NextDouble() * 100.
        }
        )
```

... their Delaunay triangulation produces something like this: a mesh of 
triangles connecting all the points, without any edges crossing each other, and 
where the triangles have "reasonably even" angles:  

<svg width="400" height="400" viewbox="-1.7681101205610257 -1.78820137949111 105.76586706832326 106.14780995349763">
  <polygon points="90.60270660119258,44.217787331071584 97.75497531413798,27.370445768987032 67.71811492169189,31.45917930242567" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="97.75497531413798,27.370445768987032 98.21512531406019,3.0366990729406003 67.71811492169189,31.45917930242567" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 63.26590728166788,46.95118784296847 67.71811492169189,31.45917930242567" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 86.23701538249712,99.53470812157481 81.69079086822029,84.8051783092344" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="97.75497531413798,27.370445768987032 98.21512531406019,3.0366990729406003 99.19021753556571,3.2625198379450104" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="76.80226893946634,55.81611914365372 90.60270660119258,44.217787331071584 69.99419837724147,52.62841426424143" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="67.71811492169189,31.45917930242567 90.60270660119258,44.217787331071584 69.99419837724147,52.62841426424143" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="63.26590728166788,46.95118784296847 67.71811492169189,31.45917930242567 69.99419837724147,52.62841426424143" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="90.60270660119258,44.217787331071584 97.75497531413798,27.370445768987032 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 76.80226893946634,55.81611914365372 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 81.69079086822029,84.8051783092344 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="76.80226893946634,55.81611914365372 90.60270660119258,44.217787331071584 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="81.69079086822029,84.8051783092344 86.23701538249712,99.53470812157481 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 67.71811492169189,31.45917930242567 54.68154342597422,8.1109949891041" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="67.71811492169189,31.45917930242567 98.21512531406019,3.0366990729406003 54.68154342597422,8.1109949891041" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 29.190628476995332,46.73147003479836 18.712457417842213,45.33271852197718" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 54.68154342597422,8.1109949891041 18.712457417842213,45.33271852197718" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 29.190628476995332,46.73147003479836 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 63.26590728166788,46.95118784296847 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 76.80226893946634,55.81611914365372 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="69.99419837724147,52.62841426424143 76.80226893946634,55.81611914365372 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="63.26590728166788,46.95118784296847 69.99419837724147,52.62841426424143 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="18.712457417842213,45.33271852197718 20.60331540210327,55.88847946184151 3.039429291635486,38.10045068995117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="18.712457417842213,45.33271852197718 54.68154342597422,8.1109949891041 3.039429291635486,38.10045068995117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 29.717186572829814,98.85437791182397 3.039429291635486,38.10045068995117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 86.23701538249712,99.53470812157481 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.717186572829814,98.85437791182397 86.23701538249712,99.53470812157481 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="64.26974728902324,76.29635882391425 72.62432699679599,81.73253595909688 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 29.717186572829814,98.85437791182397 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 64.26974728902324,76.29635882391425 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
</svg>

The Bowyer-Watson algorithm is one way to generate such a 
triangulation. In this post, I'll go over implementing it.  

<!--more-->

## Implementing the algorithm

In the same spirit as the previous posts, I will simply follow the 
[Wikipedia pseudo-code][3], and convert it to F#. Let's dive into the middle of 
the algorithm:  

```
// add all the points one at a time to the triangulation
for each point in pointList do
    badTriangles := empty set
    // 1) first find all the triangles that are no longer valid due to the insertion
    for each triangle in triangulation do 
        if point is inside circumcircle of triangle
            add triangle to badTriangles
    polygon := empty set
    // 2) find the boundary of the polygonal hole
    for each triangle in badTriangles do
        for each edge in triangle do
            if edge is not shared by any other triangles in badTriangles
                add edge to polygon
    // 3) remove them from the data structure
    for each triangle in badTriangles do
        remove triangle from triangulation
    // 4) re-triangulate the polygonal hole
    for each edge in polygon do
        newTri := form a triangle from edge to point
        add newTri to triangulation
```

The algorithm starts with a valid triangulation (the initial "super triangle", 
see [previous post][]), 
and adds points one-by-one, checking (1) which of the existing triangles are no 
longer valid, and updating them (2, 3, 4). This suggests a function which takes 
in a collection of triangles and a point, and returns an updated collection of 
triangles, something like this:  

``` fsharp
addPoint: Point -> Triangle array -> Triangle array
```

Step 1 is pretty direct. We re-use some of the tools we wrote in the 
[previous post][4], to separate the current triangles in 2 groups, good and bad 
triangles:  

```
// 1) first find all the triangles that are no longer valid due to the insertion
for each triangle in triangulation do 
    if point is inside circumcircle of triangle
        add triangle to badTriangles
```

``` fsharp
let addPoint (point: Point) (triangles: Triangle []) =
    let badTriangles, goodTriangles =
        triangles
        |> Array.partition (fun triangle ->
            triangle
            |> circumCircle
            |> Circle.contains point
            )
```

> Note: I changed `Circle.isInside` to `Circle.contains`, which reads much 
better I think.  

Done. Now to Step 2:  

```
// 2) find the boundary of the polygonal hole
for each triangle in badTriangles do
    for each edge in triangle do
        if edge is not shared by any other triangles in badTriangles
            add edge to polygon
```

This is a bit trickier. For each bad triangle, we want to extract the sides 
that are not shared, that is, unique edges. The tricky bit is that 2 edges (2 
points) are equal if the 2 points are equal, regardless of their order. That 
is, edge `A,B` is equal to edge `B,A`.  

Rather than implement equality, I will be lazy here, and use a trick:  

``` fsharp
let edge (pt1: Point, pt2: Point) =
    if pt1.X < pt2.X
    then pt1, pt2
    elif pt1.X > pt2.X
    then pt2, pt1
    else
        if pt1.Y < pt2.Y
        then pt1, pt2
        else pt2, pt1
```

The `edge` function takes a pair of points, and returns a tuple where the 
points are sorted by X coordinates and Y coordinates. Assuming I did not make 
a logical error here, this should result in `edge(A,B)=edge(B,A)`.  

Armed with that, we can then go over the bad triangles, extract all the edges, 
count them, and keep only the edges that are unique:  

``` fsharp
let uniqueEdges =
    badTriangles
    |> Array.collect (fun triangle ->
        [|
            triangle.A, triangle.B
            triangle.B, triangle.C
            triangle.C, triangle.A
        |]
        )
    |> Array.map edge
    |> Array.countBy id
    |> Array.filter (fun (_, count) -> count = 1)
    |> Array.map fst
```

Step 3 is already done for us. We don't need to remove anything, because we 
already extracted the good triangles in Step 1. All that is left to do is 
Step 4: create a triangle for each unique edge, connecting it to the point we 
are adding to the triangulation:  

```
for each edge in polygon do
    newTri := form a triangle from edge to point
    add newTri to triangulation
```

Pretty direct again:  

``` fsharp
let newTriangles =
    uniqueEdges
    |> Array.map (fun (a, b) ->
        { A = a; B = b; C = point }
        )

Array.append goodTriangles newTriangles
```

... and we are done. The complete `addPoint` function looks like this:  

``` fsharp
let addPoint (point: Point) (triangles: Triangle []) =
    let badTriangles, goodTriangles =
        triangles
        |> Array.partition (fun triangle ->
            triangle
            |> circumCircle
            |> Circle.contains point
            )
    let edge (pt1: Point, pt2: Point) =
        if pt1.X < pt2.X
        then pt1, pt2
        elif pt1.X > pt2.X
        then pt2, pt1
        else
            if pt1.Y < pt2.Y
            then pt1, pt2
            else pt2, pt1

    let uniqueEdges =
        badTriangles
        |> Array.collect (fun triangle ->
            [|
                triangle.A, triangle.B
                triangle.B, triangle.C
                triangle.C, triangle.A
            |]
            )
        |> Array.map edge
        |> Array.countBy id
        |> Array.filter (fun (_, count) -> count = 1)
        |> Array.map fst

    let newTriangles =
        uniqueEdges
        |> Array.map (fun (a, b) ->
            { A = a; B = b; C = point }
            )

    Array.append goodTriangles newTriangles
```

## Adding all the points

Now that we have a function to add a point to an existing triangulation, all we 
need is to chain that together, adding the points one by one.  

Let's start manually, for illustration. First, we need an initial super 
triangle that will contain all the points (see the 
[first post in this series][5]):  

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
```

This gives us the points we want to triangulate, and an initial triangle. We 
can now start adding the first point, which produces an array of 3 triangles:  

``` fsharp
let update1 =
    BowyerWatson.addPoint points.[0] [| triangle |]
```

And we can keep going:  

``` fsharp
let update2 =
    BowyerWatson.addPoint points.[1] update1

let update3 =
    BowyerWatson.addPoint points.[2] update2
```

After update 3, this produces the following triangulation:  

<svg width="400" height="400" viewbox="-107.53397718888428 -57.27455658245577 317.2976012049698 265.3695248837441">
  <polygon points="51.1148234136006,196.032717170209 195.34100577949593,-45.2123054513765 72.62432699679599,81.73253595909688" fill="lightyellow" stroke="black" stroke-width="0.1"/>
  <polygon points="-93.11135895229474,-45.2123054513765 195.34100577949593,-45.2123054513765 76.80226893946634,55.81611914365372" fill="lightyellow" stroke="black" stroke-width="0.1"/>
  <polygon points="72.62432699679599,81.73253595909688 195.34100577949593,-45.2123054513765 76.80226893946634,55.81611914365372" fill="lightyellow" stroke="black" stroke-width="0.1"/>
  <polygon points="-93.11135895229474,-45.2123054513765 51.1148234136006,196.032717170209 20.60331540210327,55.88847946184151" fill="lightyellow" stroke="black" stroke-width="0.1"/>
  <polygon points="51.1148234136006,196.032717170209 72.62432699679599,81.73253595909688 20.60331540210327,55.88847946184151" fill="lightyellow" stroke="black" stroke-width="0.1"/>
  <polygon points="72.62432699679599,81.73253595909688 76.80226893946634,55.81611914365372 20.60331540210327,55.88847946184151" fill="lightyellow" stroke="black" stroke-width="0.1"/>
  <polygon points="-93.11135895229474,-45.2123054513765 76.80226893946634,55.81611914365372 20.60331540210327,55.88847946184151" fill="lightyellow" stroke="black" stroke-width="0.1"/>
</svg>

Note that the triangulation still includes the initial, outer super-triangle. 
We will remove that in a minute. First, let's see how we can write that loop 
and add all the points in one go.  

Updates 1, 2 and 3 follow a clear pattern:  

- Take the current collection of triangles, the `State` of the triangulation,  
- Take the next Point in the collection of Points,  
- Add the Point, which gives us a new collection of triangles,  
- Repeat, using the new collection of triangles as a new `State`.  

This is exactly what a `fold` does: starting from an initial state and a 
collection, we iterate over the collection, updating the state each time until 
there isn't anything left to iterate over.  

``` fsharp
val fold:
   folder: ('State -> 'T -> 'State) ->
   state : 'State ->
   source: seq<'T>
        -> 'State
```

So we can iterate over all the points like so:  

``` fsharp
([| triangle |], points)
||> Seq.fold (fun triangulation point ->
    BowyerWatson.addPoint point triangulation
    )
```

## Wrapping it all up

We are more or less done at that point. The only thing we need to do is 
remove any triangle that has an edge connected to one of the initial 3 points. 
Let's do that, and wrap the whole thing into a function:  

``` fsharp
let delaunay (points: seq<Point>) =
    let corners (triangle: Triangle) =
        set [ triangle.A; triangle.B; triangle.C ]
    let initial = superTriangle points
    let initialCorners = corners initial
    ([| initial |], points)
    ||> Seq.fold (fun triangulation point ->
        addPoint point triangulation
        )
    |> Array.filter (fun triangle ->
        Set.intersect (corners triangle) initialCorners
        |> Set.isEmpty
        )
```

We write a small utility function, `corners`, which takes a triangle and 
extracts its 3 corners into a `Set`. This is useful, because we can use 
set functions, like `Set.intersect`, to verify if 2 triangles have a common 
corner, and, if so, remove them from the list. And... we are done, and can run 
a full Delaunay triangulation, and visualize it:  

``` fsharp
points
|> BowyerWatson.delaunay
|> List.ofArray
|> List.map (fun triangle ->
    polygon
        [
            Style.Fill (Fill.Color "lightyellow")
            Style.Stroke (Stroke.Color "black")
            Style.Stroke (Stroke.Width 0.2)
        ]
        [ triangle.A; triangle.B; triangle.C ]
    )
|> Plot.plot (400, 400)
```

> Note: I am still working on that SVG generation DSL, once it's in a 
presentable state I plan to blog about it.  

<svg width="400" height="400" viewbox="-1.7681101205610257 -1.78820137949111 105.76586706832326 106.14780995349763">
  <polygon points="90.60270660119258,44.217787331071584 97.75497531413798,27.370445768987032 67.71811492169189,31.45917930242567" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="97.75497531413798,27.370445768987032 98.21512531406019,3.0366990729406003 67.71811492169189,31.45917930242567" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 63.26590728166788,46.95118784296847 67.71811492169189,31.45917930242567" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 86.23701538249712,99.53470812157481 81.69079086822029,84.8051783092344" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="97.75497531413798,27.370445768987032 98.21512531406019,3.0366990729406003 99.19021753556571,3.2625198379450104" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="76.80226893946634,55.81611914365372 90.60270660119258,44.217787331071584 69.99419837724147,52.62841426424143" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="67.71811492169189,31.45917930242567 90.60270660119258,44.217787331071584 69.99419837724147,52.62841426424143" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="63.26590728166788,46.95118784296847 67.71811492169189,31.45917930242567 69.99419837724147,52.62841426424143" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="90.60270660119258,44.217787331071584 97.75497531413798,27.370445768987032 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 76.80226893946634,55.81611914365372 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 81.69079086822029,84.8051783092344 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="76.80226893946634,55.81611914365372 90.60270660119258,44.217787331071584 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="81.69079086822029,84.8051783092344 86.23701538249712,99.53470812157481 93.4018658909024,68.76202824933549" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 67.71811492169189,31.45917930242567 54.68154342597422,8.1109949891041" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="67.71811492169189,31.45917930242567 98.21512531406019,3.0366990729406003 54.68154342597422,8.1109949891041" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 29.190628476995332,46.73147003479836 18.712457417842213,45.33271852197718" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 54.68154342597422,8.1109949891041 18.712457417842213,45.33271852197718" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 29.190628476995332,46.73147003479836 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 63.26590728166788,46.95118784296847 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 76.80226893946634,55.81611914365372 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="69.99419837724147,52.62841426424143 76.80226893946634,55.81611914365372 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="63.26590728166788,46.95118784296847 69.99419837724147,52.62841426424143 64.26974728902324,76.29635882391425" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="18.712457417842213,45.33271852197718 20.60331540210327,55.88847946184151 3.039429291635486,38.10045068995117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="18.712457417842213,45.33271852197718 54.68154342597422,8.1109949891041 3.039429291635486,38.10045068995117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 29.717186572829814,98.85437791182397 3.039429291635486,38.10045068995117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 86.23701538249712,99.53470812157481 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.717186572829814,98.85437791182397 86.23701538249712,99.53470812157481 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="64.26974728902324,76.29635882391425 72.62432699679599,81.73253595909688 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 29.717186572829814,98.85437791182397 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="20.60331540210327,55.88847946184151 64.26974728902324,76.29635882391425 34.31418446559188,95.74551656644117" fill="lightyellow" stroke="black" stroke-width="0.2"/>
</svg>

## Parting thoughts

I was expecting the core algorithm to give me more trouble than it did. As it 
turns out, the hardest part was getting the geometry functions done - wiring up 
the main loop was more or less a direct transcription of the pseudo code to F#.   

That being said, I know I am not fully done, because there is a bug, which I 
spotted by accident. If I run the same code, using only the first 9 points 
instead of the full list, I get this:  

<svg width="400" height="400" viewbox="16.722724906505423 -1.78820137949111 85.37299090315263 106.14780995349763">
  <polygon points="20.60331540210327,55.88847946184151 72.62432699679599,81.73253595909688 29.190628476995332,46.73147003479836" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="76.80226893946634,55.81611914365372 90.60270660119258,44.217787331071584 63.26590728166788,46.95118784296847" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="90.60270660119258,44.217787331071584 97.75497531413798,27.370445768987032 63.26590728166788,46.95118784296847" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 76.80226893946634,55.81611914365372 63.26590728166788,46.95118784296847" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 72.62432699679599,81.73253595909688 63.26590728166788,46.95118784296847" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="63.26590728166788,46.95118784296847 97.75497531413798,27.370445768987032 98.21512531406019,3.0366990729406003" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="29.190628476995332,46.73147003479836 63.26590728166788,46.95118784296847 98.21512531406019,3.0366990729406003" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="72.62432699679599,81.73253595909688 76.80226893946634,55.81611914365372 86.23701538249712,99.53470812157481" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="76.80226893946634,55.81611914365372 90.60270660119258,44.217787331071584 86.23701538249712,99.53470812157481" fill="lightyellow" stroke="black" stroke-width="0.2"/>
  <polygon points="90.60270660119258,44.217787331071584 97.75497531413798,27.370445768987032 86.23701538249712,99.53470812157481" fill="lightyellow" stroke="black" stroke-width="0.2"/>
</svg>

This looks _mostly_ correct, which is also commonly described as "wrong". The 
problem is visible on the bottom edge, connecting the west and south-east 
corners. The triangulation looks pretty, but, if it is done right, the result 
should always be a convex hull. Stated differently: the outer polygon should 
never bend inwards.  

There is a clear inwards bend on that edge, which tells me that something is 
wrong in my implementation somewhere. If you run the algorithm for more points, 
the problem fixes itself, but reappears a few iterations later. The 
algorithm as implemented seems to occasionally produce obviously incorrect 
triangulations. This might be a more general problem, but it seems related to 
adding points that are added close to the outside boundary.  

The problem here is that I am not entirely sure yet how to approach fixing that 
issue. Fortunately, I have an example that reproduces the bug, but it involves 
adding 1 point to an 8 points mesh. Isolating what step goes wrong or even 
debugging will be a nightmare.  

Anyways, that's probably what I will be tackling next! In the meantime, if you 
can spot the bug... let me know :)

[1]: https://en.wikipedia.org/wiki/Bowyer%E2%80%93Watson_algorithm
[2]: https://en.wikipedia.org/wiki/Delaunay_triangulation
[3]: https://en.wikipedia.org/wiki/Bowyer%E2%80%93Watson_algorithm#Pseudocode
[4]: https://brandewinder.com/2025/03/19/delaunay-triangulation-circumcircle
[5]: https://brandewinder.com/2025/03/05/delaunay-super-triangle/