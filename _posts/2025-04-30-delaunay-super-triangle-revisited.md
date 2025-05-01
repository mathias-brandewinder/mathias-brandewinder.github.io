---
layout: post
title: Delaunay triangulation with Bowyer-Watson&#58; initial super triangle, revisited
tags:
- F#
- Algorithms
- Geometry
---

In our [last installment][1], I hit a roadblock. I attempted to 
implement Delaunay triangulations using the Bowyer-Watson algorithm, 
followed [this pseudo-code from Wikipedia][2], 
and ended up with a mostly working F# implementation. 
Given a list of points, the code produces a triangulation, but 
occasionally the outer boundary of the triangulation is not convex, 
displaying bends towards the inside, something that should never 
supposed happen for a proper Delaunay triangulation.  

While I could not figure out the exact issue, by elimination I 
narrowed it down a bit. My guess was that the issue was 
probably a missing unstated condition, probably related to the initial 
super-triangle. As it turns out, my guess was correct.  

The reason I know is, a kind stranger on the internet reached out 
with a couple of helpful links (thank you!):  

[Bowyer-Watson algorithm: how to fill "holes" left by removing triangles with super triangle vertices][3]  
[Bowyer-Watson algorithm for Delaunay triangulation fails, when three vertices approach a line][4]

The second link in particular mentions that the Wikipedia page is 
indeed missing conditions, and suggests that the initial 
super triangle should verify the following property to be valid:  

> it seems that one should rather demand that the vertices of the 
super triangle have to be outside all circumcircles of any three 
given points to begin with (which is hard when any three points are almost collinear)

That doesn't look overly complicated, let's modify our code 
accordingly, and check if this fixes our problem!   

<!--more-->

First off, what does our [original code][5] do?  

What we are after with the so-called super-triangle is a 
triangle that contains all the points we are triangulating. 
The strategy we followed is simple:  

1) compute a rectangular box that contains all the points 
we want to triangulate,  
2) compute a triangle that contains that rectangular box.  

Below is how (1) looks in code; we omitted (2) because 
we are simply going to re-use it as-is, but you can 
look at [this earlier post for details][7].

``` fsharp
let superTriangle (points: seq<Point>): Triangle =

    // find the left and right edges 
    // of the containing box
    let xs =
        points
        |> Seq.map (fun pt -> pt.X)
        |> Array.ofSeq
    let xMin = xs |> Array.min
    let xMax = xs |> Array.max
    // find the top and bottom edges
    // of the containing box
    let ys =
        points
        |> Seq.map (fun pt -> pt.Y)
        |> Array.ofSeq
    let yMin = ys |> Array.min
    let yMax = ys |> Array.max

    // omitted: given a box, 
    // we can compute a triangle around it.
```

The missing condition we need to incorporate says that the 
corners of the super triangle 

> have to be outside all circumcircles of any three given points

Stated differently, the super triangle needs to be large 
enough to contain not just the points we want to triangulate, 
but also, for every single possible triangle they can form, the 
corresponding circumcircle.  

As a reminder, the [circumcircle of a triangle][6] is the 
circle that passes through all the triangle corners:  

<svg width="400" height="400" viewbox="166.34696238775658 182.21595865376153 64.73414249159977 64.73414249159977">
  <polygon points="222.624326996796,231.73253595909688 226.80226893946633,205.81611914365374 170.60331540210328,205.8884794618415" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <circle cx="198.71403363355645" cy="214.5830298995614" r="29.42461022345445" fill="none" stroke="gray" stroke-width="1"/>
</svg>

Fortunately, we already have the code we need to compute that, 
because it is used in the algorithm itself. The details of 
the calculations are not particularly important, what 
matters here is that we have a function that, given a 
`Triangle`, will give us back a `Circle` like so:  

``` fsharp

let circumCircle (triangle: Triangle) =
    // Calculations details omitted, see link:
    // https://en.wikipedia.org/wiki/Circumcircle#Cartesian_coordinates_2
    { Center = center; Radius = radius }
```

With these tools in hand, we should be able to fix our 
code. Let's try to reduce our problem to a (mostly) known 
problem, following this strategy:  

1) enumerate every triangle we can form with the points 
we want to triangulate,  
2) for each triangle, compute the circumcircle  
3) compute a rectangular box that contains all the circles,  
4) compute a triangle that contains that rectangular box.  

(2) and (4) we know how to do already, all we need to focus on 
is (1) and (3).  

So how can we enumerate the triangles we can form 
using a collection of points? Triangles that have 
the same corners are identical, regardless of the 
order (ABC is the same triangle as CBA or any other 
combination), so all we need is to enumerate all 
distinct combinations of 3 points we can form.  

One way to go about it would be along these lines:  

``` fsharp
let triangles (points: seq<Point>) =
    let points = points |> Array.ofSeq
    let len = points.Length
    seq {
        for p1 in 0 .. len - 3 do
            for p2 in (p1 + 1) .. len - 2 do
                for p3 in (p2 + 1) .. len - 1 ->
                    {
                        A = points.[p1]
                        B = points.[p2]
                        C = points.[p3]
                    }
        }
```

That takes care of (1), now let's consider (3). How can we 
find a rectangular box that contains a collection of circles?  

In our earlier version, we proceeded by finding the left-most 
and right-most points in our collection, which define the 
left and right boundary of the rectangular box, and did 
the same for the top and bottom-most points.  

We can reduce our new problem to that same problem, by 
converting each circle into 4 points that box it from the 
left, right, top and bottom, like so:  

``` fsharp
let xs =
    circles
    |> Seq.collect (fun circle ->
        seq {
            circle.Center.X - circle.Radius
            circle.Center.X + circle.Radius }
        )
    |> Array.ofSeq
let ys =
    circles
    |> Seq.collect (fun circle ->
        seq {
            circle.Center.Y - circle.Radius
            circle.Center.Y + circle.Radius
            }
        )
    |> Array.ofSeq

let xMin = xs |> Array.min
let xMax = xs |> Array.max

let yMin = ys |> Array.min
let yMax = ys |> Array.max
```

Essentially, we create a box around the circles first, 
and then find a box that contains all these boxes.  

And... we are pretty much done at that point, all we need 
to do is bolt these 4 steps together:  

``` fsharp
let superTriangle (points: seq<Point>) =
    let points = points |> Array.ofSeq
    let len = points.Length
    let circles =
        // 1) enumerate all triangles
        seq {
            for p1 in 0 .. len - 3 do
                for p2 in (p1 + 1) .. len - 2 do
                    for p3 in (p2 + 1) .. len - 1 ->
                        {
                            A = points.[p1]
                            B = points.[p2]
                            C = points.[p3]
                        }
            }
        // 2) compute their circumcircles
        |> Seq.map circumCircle
    // 3) convert the circles into points that
    // box them left, right, top and bottom
    let xs =
        circles
        |> Seq.collect (fun circle ->
            seq {
                circle.Center.X - circle.Radius
                circle.Center.X + circle.Radius }
            )
        |> Array.ofSeq
    let ys =
        circles
        |> Seq.collect (fun circle ->
            seq {
                circle.Center.Y - circle.Radius
                circle.Center.Y + circle.Radius
                }
            )
        |> Array.ofSeq

    let xMin = xs |> Array.min
    let xMax = xs |> Array.max

    let yMin = ys |> Array.min
    let yMax = ys |> Array.max

    // 4) back to original algorithm: 
    // find triangle around the bounding boxs
    // Omitted, same as before
```

And we are done!  

<svg width="400" height="400" viewbox="146.03188987943898 146.01179862050887 110.16586706832324 110.54780995349763">
  <polygon points="240.60270660119258,194.21778733107158 247.754975314138,177.37044576898703 217.7181149216919,181.45917930242567" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="247.754975314138,177.37044576898703 248.21512531406017,153.0366990729406 217.7181149216919,181.45917930242567" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="179.19062847699533,196.73147003479835 213.26590728166786,196.95118784296847 217.7181149216919,181.45917930242567" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="222.624326996796,231.73253595909688 236.23701538249713,249.5347081215748 231.6907908682203,234.8051783092344" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="247.754975314138,177.37044576898703 248.21512531406017,153.0366990729406 249.1902175355657,153.262519837945" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="226.80226893946633,205.81611914365374 240.60270660119258,194.21778733107158 219.99419837724147,202.62841426424143" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="217.7181149216919,181.45917930242567 240.60270660119258,194.21778733107158 219.99419837724147,202.62841426424143" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="213.26590728166786,196.95118784296847 217.7181149216919,181.45917930242567 219.99419837724147,202.62841426424143" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="240.60270660119258,194.21778733107158 247.754975314138,177.37044576898703 243.4018658909024,218.7620282493355" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="222.624326996796,231.73253595909688 226.80226893946633,205.81611914365374 243.4018658909024,218.7620282493355" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="222.624326996796,231.73253595909688 231.6907908682203,234.8051783092344 243.4018658909024,218.7620282493355" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="226.80226893946633,205.81611914365374 240.60270660119258,194.21778733107158 243.4018658909024,218.7620282493355" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="231.6907908682203,234.8051783092344 236.23701538249713,249.5347081215748 243.4018658909024,218.7620282493355" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="217.7181149216919,181.45917930242567 248.21512531406017,153.0366990729406 204.6815434259742,158.11099498910409" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="179.19062847699533,196.73147003479835 217.7181149216919,181.45917930242567 204.6815434259742,158.11099498910409" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="170.60331540210328,205.8884794618415 179.19062847699533,196.73147003479835 168.71245741784222,195.33271852197717" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="179.19062847699533,196.73147003479835 204.6815434259742,158.11099498910409 168.71245741784222,195.33271852197717" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="170.60331540210328,205.8884794618415 179.19062847699533,196.73147003479835 214.26974728902326,226.29635882391426" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="179.19062847699533,196.73147003479835 213.26590728166786,196.95118784296847 214.26974728902326,226.29635882391426" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="222.624326996796,231.73253595909688 226.80226893946633,205.81611914365374 214.26974728902326,226.29635882391426" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="219.99419837724147,202.62841426424143 226.80226893946633,205.81611914365374 214.26974728902326,226.29635882391426" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="213.26590728166786,196.95118784296847 219.99419837724147,202.62841426424143 214.26974728902326,226.29635882391426" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="168.71245741784222,195.33271852197717 170.60331540210328,205.8884794618415 153.03942929163549,188.10045068995117" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="168.71245741784222,195.33271852197717 204.6815434259742,158.11099498910409 153.03942929163549,188.10045068995117" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="170.60331540210328,205.8884794618415 179.7171865728298,248.85437791182397 153.03942929163549,188.10045068995117" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="222.624326996796,231.73253595909688 236.23701538249713,249.5347081215748 184.3141844655919,245.74551656644115" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="179.7171865728298,248.85437791182397 236.23701538249713,249.5347081215748 184.3141844655919,245.74551656644115" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="214.26974728902326,226.29635882391426 222.624326996796,231.73253595909688 184.3141844655919,245.74551656644115" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="170.60331540210328,205.8884794618415 179.7171865728298,248.85437791182397 184.3141844655919,245.74551656644115" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <polygon points="170.60331540210328,205.8884794618415 214.26974728902326,226.29635882391426 184.3141844655919,245.74551656644115" fill="lightyellow" stroke="black" stroke-width="1" stroke-dasharray="1 1"/>
  <circle cx="222.624326996796" cy="231.73253595909688" r="2" fill="white" stroke="black"/>
  <circle cx="226.80226893946633" cy="205.81611914365374" r="2" fill="white" stroke="black"/>
  <circle cx="170.60331540210328" cy="205.8884794618415" r="2" fill="white" stroke="black"/>
  <circle cx="240.60270660119258" cy="194.21778733107158" r="2" fill="white" stroke="black"/>
  <circle cx="247.754975314138" cy="177.37044576898703" r="2" fill="white" stroke="black"/>
  <circle cx="179.19062847699533" cy="196.73147003479835" r="2" fill="white" stroke="black"/>
  <circle cx="213.26590728166786" cy="196.95118784296847" r="2" fill="white" stroke="black"/>
  <circle cx="248.21512531406017" cy="153.0366990729406" r="2" fill="white" stroke="black"/>
  <circle cx="236.23701538249713" cy="249.5347081215748" r="2" fill="white" stroke="black"/>
  <circle cx="217.7181149216919" cy="181.45917930242567" r="2" fill="white" stroke="black"/>
  <circle cx="231.6907908682203" cy="234.8051783092344" r="2" fill="white" stroke="black"/>
  <circle cx="249.1902175355657" cy="153.262519837945" r="2" fill="white" stroke="black"/>
  <circle cx="219.99419837724147" cy="202.62841426424143" r="2" fill="white" stroke="black"/>
  <circle cx="243.4018658909024" cy="218.7620282493355" r="2" fill="white" stroke="black"/>
  <circle cx="204.6815434259742" cy="158.11099498910409" r="2" fill="white" stroke="black"/>
  <circle cx="168.71245741784222" cy="195.33271852197717" r="2" fill="white" stroke="black"/>
  <circle cx="179.7171865728298" cy="248.85437791182397" r="2" fill="white" stroke="black"/>
  <circle cx="214.26974728902326" cy="226.29635882391426" r="2" fill="white" stroke="black"/>
  <circle cx="153.03942929163549" cy="188.10045068995117" r="2" fill="white" stroke="black"/>
  <circle cx="184.3141844655919" cy="245.74551656644115" r="2" fill="white" stroke="black"/>
</svg>

## Parting thoughts

Does it work? Yes, it appears so. It's not a proof, 
but when running the modified version, the issues we 
had previously are gone. Now we have a nicely convex triangulation!  

The obvious drawback here is that the initial super-triangle 
computation went from O(n) to O(n^3). Instead of computing the 
bounding box in a single pass over the points, we need to 
compute every possible triangle first. That being said, 
correct and slow beats fast and wrong.  

Another approach that was suggested involved using a 
super triangle with infinite coordinates. I am still 
wrapping my head around what that means practically, 
and might look into it later. There is also still 
the issue of points that could be aligned. But... these 
questions can wait, this is where we'll stop for today! 
And thank you again, Stranger on the Internet, for helping 
me get un-stuck!  

[1]: https://brandewinder.com/2025/04/16/delaunay-algorithm-impasse/
[2]: https://en.wikipedia.org/wiki/Bowyer%E2%80%93Watson_algorithm#Pseudocode
[3]: https://stackoverflow.com/questions/30741459/bowyer-watson-algorithm-how-to-fill-holes-left-by-removing-triangles-with-sup
[4]: https://math.stackexchange.com/questions/4001660/bowyer-watson-algorithm-for-delaunay-triangulation-fails-when-three-vertices-ap
[5]: https://github.com/mathias-brandewinder/delaunay/blob/47782f318e92168264a87ab8f5d36387f3ff43bb/src/Delaunay/Core.fs#L27-L147
[6]: https://en.wikipedia.org/wiki/Circumcircle
[7]: https://brandewinder.com/2025/03/05/delaunay-super-triangle/