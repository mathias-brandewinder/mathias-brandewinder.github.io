---
layout: post
title: "Drawing mountains: direct light"
tags:
- F#

---

Now that we have are setup to [draw SVG on a page with Bolero][1], we can go 
back to our main quest: drawing mountains in a style similar to 
[topographic maps][2], using shading to hint at the relief. In this post, I 
will go over how I approached computing the effect of light on a terrain.  

This post will be heavy on geometry, so let's start with a teaser, showing the 
result first:  

![Animation showing direct light on model of mountains]({{ site.url }}/assets/2026-06-03/direct-light.gif)

<!--more-->

## Representing the terrain

First things first, in order to render a map, we need a map. Our map will be 
stored as a regular Cartesian grid, where for each integer location `(x, y)` on 
the grid, we have an altitude.  

We will represent this with a `Topo`:  

``` fsharp
type Topo = {
    // How many tiles wide is our map
    Width: int
    // How many tiles high is our map
    Height: int
    // Altitudes of the points inside the map
    // indexed as [y][x]
    Altitudes: float[][]
    }
    with
    member this.IsInside (x, y) =
        y > 0
        && y < this.Width
        && x > 0
        && x < this.Height
    member this.Altitude (x, y) =
        if this.IsInside (x, y)
        then this.Altitudes[y - 1][x - 1]
        else 0.0
```

We are making a few assumptions here. First, we want to represent the map as 
square "tiles". A map that is, say, 3 squares high x 4 squares wide, would be 
represented like so:  

```
0 - 0 - 0 - 0 - 0
|   |   |   |   |
0 - ? - ? - ? - 0
|   |   |   |   |
0 - ? - ? - ? - 0
|   |   |   |   |
0 - 0 - 0 - 0 - 0
```

That is, we assume that the altitude at the edges is 0. Only the altitudes 
"inside" (represented as `?` on the diagram) can be non-zero, so we only need 
to store `(height - 1) x (width - 1)` altitudes. We will store these as an 
array of arrays, adding a method `Altitude` to retrieve the altitude at the 
given position.  

We would like to be able to edit such a map. Let's do so, with a couple of 
functions:  

``` fsharp
module Topo =

    let init (width, height) =
        {
            Width = width
            Height = height
            Altitudes =
                Array.create (height - 1)
                    (Array.create (width - 1) 0.0)
        }

    let set ((x, y), alt) (topo: Topo) =
        if topo.IsInside (x, y)
        then
            let updated =
                topo.Altitudes
                |> Array.mapi (fun h row ->
                    if h <> y - 1
                    then row
                    else
                        row
                        |> Array.mapi (fun w currentAltitude ->
                            if w <> x - 1
                            then currentAltitude
                            else alt
                            )
                    )
            { topo with
                Altitudes = updated
            }
        else topo
```

`init` initializes a map with all altitudes set to `0`. `set` allows us to, 
well, set the altitude of a point. We simply ignore any update that doesn't 
correspond to a point inside the map.  

> Note: I might switch at some point to a different storage of altitudes, 
perhaps using a map. An array was the simplest starting point I could think of.  

> Note: the `set` function is pretty heavy handed, re-mapping the entire map 
when a single point is modified. I tried to mutate the original array but ran 
into odd issues, so this will do for now.  

## Direct light

Now that we have a map, how should we go about determining whether a tile 
receives light or is shaded?  

First, how do we even represent light? In general, light has a source, say, the 
sun, so we could imagine many rays originating from that single point. However, 
this introduces some complexity, because rays radiate from that point at 
different angles. We will make our life easier, and assume instead that all 
light follows a single direction. This is not correct, but should be a good 
enough approximation in our case. Our light source, the sun, is far enough from 
the ground that the rays of light hitting our scene are nearly parallel.  

To represent such a direction, we will use a 3D vector, where `dx`, `dy` and 
`dz` represent the direction along the 3 axes:  

``` fsharp
type Vec3 = {
    dx: float
    dy: float
    dz: float
    }

let vec3 (x, y, z) =
    { dx = x; dy = y; dz = z }
```

Now that there is light (fiat lux!), what would its effect be on a tile? Before 
looking into 3D tiles, let's consider the question in 2 dimensions as a warm 
up, with a tile hit by rays of light:  

```
weaker  strong  weaker
   \      |      /
    \     |     /
tile -----------------
```

The illumination provided by a light ray depends on its angle with the target 
tile surface. It will be strongest if they form a straight angle (90°), and 
weaker as the angle gets closer to 0° or 180°. And if the light hits the back 
of the surface, with an angle of 270°, we receive no light at all.  

One reasonable starting point would be to first compute the angle between the 
light and the target surface, and use that angle to measure the amount of light 
received:  

```
90° -> 1.0, full illumination
0° -> 0.0, neutral illumination
180° -> 0.0, neutral illumination
270° -> -1.0, backlit, full darkness
```

Of course, one could argue that any angle that isn't between 0° and 180° should 
be dark. I will probably try that out later, to see the difference, but let's 
start with this approach first, and see where that leads us!  

## Computing angles

Regardless of how much we decide to illuminate a tile, we need to compute the 
angle between the light and a tile on the map. Let's assume first that these 
tiles are planes (more on that in a bit).  

Brushing up on 3D geometry, one of the building blocks we have available is a 
formula to compute the angle between two vectors. For two vectors `a` and `b` 
we have the following relationship:  

`dot product (a, b) = norm(a) x norm(b) x cos (angle(a, b))`  

Let's start with that, defining first the [`dot` product][3] and `norm`:  

``` fsharp
let norm (v: Vec3) =
    (v.dx * v.dx + v.dy * v.dy + v.dz * v.dz)
    |> sqrt

// dot product
let dot (v1: Vec3) (v2: Vec3) =
    v1.dx * v2.dx + v1.dy * v2.dy + v1.dz * v2.dz
```

Rearranging a bit, we get the angle between 2 vectors via the `cos` part:  

``` fsharp
let angle (v1: Vec3) (v2: Vec3) =
    (dot v1 v2) / (norm v1 * norm v2)
    |> acos
```

However, this is not exactly what we want. We need the angle between a plane 
(our tile) and a vector (the light). We can, however, compute the 
[vector perpendicular to the plane defined by 2 vectors][4], like so:  

``` fsharp
let ortho (v1: Vec3, v2: Vec3) =
    // cross product of vectors
    (
        (v1.dy * v2.dz - v1.dz * v2.dy),
        (v1.dz * v2.dx - v1.dx * v2.dz),
        (v1.dx * v2.dy - v1.dy * v2.dx)
    )
    |> vec3
```

Putting this all together, if we have a plane surface defined by 2 vectors, and 
light, defined by a vector, we can compute first the vector perpendicular to 
the plane, and then the angle between the light and that vector:  

``` fsharp
// define the plane with 2 vectors
let v1 = vec3 (0.0, 1.0, 0.0)
let v2 = vec3 (1.0, 0.0, 0.0)
// compute the vector perpendicular
let perpendicular = ortho (v1, v2)
// define the light direction
let light = vec3 (2.0, 3.0, -1.0)
// compute the angle, in radians
let lightAngle = angle light perpendicular
// val lightAngle: float = 1.300246564
```

What does this buy us? The `lightAngle` describes how the light hits the 
plane:  

```
0° -> full direct illumination
180° -> backlit, full darkness
90°, 270° -> neutral illumination
```

Using the `cos` trigonometric function, we can convert that directly into 
something we can work with, becase cos 0° will give us 1.0, cos 180° -1.0, and 
cos 90° 0.0. In other words, we will get directly a strength between -1.0 and 
1.0, describing how much darkness or light the tile is receiving.  

## Tiles are not planes

At that point, I thought I was done, and then I realized I had missed an 
important detail: tiles are not planes. Let's consider a simple example, a tile 
where 3 corners have altitude 0, and one corner has an altitude of 1:  

```
0 --- 1
|     |
|     |
0 --- 0
```

These 4 points cannot be in the same plane. The 3 points with altitude 0 are on 
a plane with altitude 0, so the fourth point, having an altitude of 1, cannot 
possibly be in that same plane.  

This is a problem. We have the tools to work with planes, not with whatever 
surface this is. So what can we do? Being lazy, I went with a lazy solution. 
By definition, 3 points form a plane, so I considered the 4 planes formed by 
the 4 combinations of 3 vertexes of the tile, computed the light each of these 
planes would receive, and averaged that out. It's not particularly pretty, but 
it has the benefit of being fairly simple to compute.  

## Parting thoughts

Does it work? It appears to!  

Using the code above, I created a couple of fake mountains (basic cones) in my 
Bolero app, added illumination, and rendered the tiles as SVG. This isn't going 
to win me any web design prizes, but we can clearly see how sides of the 
mountains get shaded or illuminated as we rotate the light:  

![Animation showing direct light on model of mountains]({{ site.url }}/assets/2026-06-03/direct-light.gif)

So what's next? One issue with the version above is that it only handles direct 
light, and ignores the shadows other mountains cast. If there is a high 
mountain between a tile and the light, that tile should not be illuminated, 
because it is in the shadow of the mountain. We'll address that in the next 
post!  

In the meantime, you can check out the [work in progress on Codeberg][5].  


[1]: https://brandewinder.com/2026/05/20/first-steps-with-bolero/
[2]: https://en.wikipedia.org/wiki/Topographic_map
[3]: https://en.wikipedia.org/wiki/Dot_product#Physics
[4]: https://en.wikipedia.org/wiki/Cross_product#Coordinate_notation
[5]: https://codeberg.org/mathias-brandewinder/cartographer