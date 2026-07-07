---
layout: post
title: "Drawing mountains: shadows"
tags:
- F#

---

After a couple of weeks of hiatus (sometimes, actual work needs to get done), 
we are back to our pointless but fun weekend project: drawing mountains in a 
style similar to [topographic maps][2], using shadows to hint at the relief. We 
are pretty certain that this must be a solved problem. We aren't particularly 
interested in the result: this is more of an excuse to understand lights, and 
do a bit of geometry.  

As a recap and a teaser, we left off with a [simple illumination model][1], where 
the tiles that represent our terrain were lighter or darker, depending on how 
much direct light they received:  

![Animation showing direct light on model of mountains]({{ site.url }}/assets/2026-06-03/direct-light.gif)

This isn't too bad, but it misses an important element: the shadow cast by the 
mountains. After our latest changes, this is how things look - much more 
satisfying:  

![Animation showing light and shadows on model of mountains]({{ site.url }}/assets/2026-07-08/cast-shadow.gif)

<!--more-->

## Computing cast shadow

Let's get this out of the way from the get-go: we got this working, but it is 
not pretty, and we might revisit this later on. With that said, let's get into 
it.

Conceptually, the problem is not very complicated. Take a point on the surface 
of our terrain, and draw a line from that point, following the direction of the 
light downwards. If that line hits another point on the surface, that point is 
in the shadow of the first point, which blocks the light it would otherwise 
receive.  

Practically, things are a little messy. The question we need to answer is not 
"is this point in the shadow of another point", but "is this tile in the shadow 
of other terrain elements". This is messy because a tile could, for instance, 
be only partially obscured.  

Rather than being correct, we chose to try the simplest thing that we could get 
to work, committing sins and making approximations along the way, so we could 
see how that worked out.  

The general approach we followed was to assume that a tile was either in the 
shadow or not (as opposed to partially obscured). We determine that by 
starting from the mid-point of the tile, and "walking backwards", following the 
direction of the light backwards, until we reach one of two cases:  

- we find a location that would block the light (in what case the tile is "in 
the shadow"), or 
- we are in the clear: we exited the map without encountering any light 
obstruction (no shadow).  

How do we determine whether we found a location that would block the light? We 
used a dreadful approximation. When we follow the light backwards, we take 
discrete steps, and go through a series of coordinates `(x, y, z)`. In other 
words, at position `(x, y)`, the light that would hit our target tile is at 
altitude `z`. If the terrain altitude at that same position `(x, y)` is higher 
the light is blocked.  

Unfortunately, we do not have that altitude readily available. What we have is 
the altitude at the 4 edges of each tile. Fortunately, we are not trying to be 
precise here, so we will approximate the altitude of our location by taking the 
average of the altitudes of the 4 corners of the tile.  

The relevant code is in the [CastShadow][4] module, and in the [`altitude`][5] 
function.  

And that's pretty much it. After we determined the amount of light a tile 
receives, we simply compute if its light is obstructed, and give it a darker 
shade if so.  

## Parting thoughts

Given how inelegant the whole approach was, we were pleasantly surprised that 
the result... kind of worked?  

Before  

![Animation showing direct light on model of mountains]({{ site.url }}/assets/2026-06-03/direct-light.gif)

After  

![Animation showing light and shadows on model of mountains]({{ site.url }}/assets/2026-07-08/cast-shadow.gif)

Our initial idea was to go the other way around, and iterate over the known 
altitudes of the terrain, following the light downwards until we hit a tile. 
Inverting the direction and going backwards, asking "is the light for this tile 
obstructed" ended up being more straightforward, but feels inefficient. One 
easy improvement would be to not follow the light until we exit the map, but 
stop when the altitude is higher than the highest altitude on the map.  

That being said, the real question is, what should we do if we were not using 
our dirty approximation. The answer here is, we don't know. From a geometry 
standpoint, it sounds like we would need to take each tile, project its 
cast shadow on a surface that is not that simple, the terrain, and possibly 
determine how much of each tile is shaded, to determine how dark it should be.  

This does not sounds like an easy problem, so we gave up, at least temporarily. 
We have a nagging suspicion that we are not thinking about this right, and that 
perhaps there is a better way to represent the domain that simplifies some of 
these issues. Anyways, we will give it a rest for now, and maybe revisit it 
later!  

In the meantime, you can check out the [work in progress on Codeberg][3].  


[1]: https://brandewinder.com/2026/06/03/direct-light/
[2]: https://en.wikipedia.org/wiki/Topographic_map
[3]: https://codeberg.org/mathias-brandewinder/cartographer
[4]: https://codeberg.org/mathias-brandewinder/cartographer/src/commit/fec63b2f7145d00a2cfc4104b62b8a9f2b0efbeb/Cartographer/src/Cartographer.Client/Main.fs#L187-L207
[5]: https://codeberg.org/mathias-brandewinder/cartographer/src/commit/fec63b2f7145d00a2cfc4104b62b8a9f2b0efbeb/Cartographer/src/Cartographer.Client/Main.fs#L140-L150