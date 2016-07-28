---
layout: post
title: Safe Refactoring with Units of Measure
tags:
- F#
- Refactoring
- Units-of-Measure
- Testing
- Pacman
---

A couple of weeks ago, I had the pleasure to attend [Progressive F# Tutorials in NYC](http://skillsmatter.com/event/scala/progressive-f-tutorials-nyc). The conference was fantastic – two days of hands-on workshops, great organization by the good folks at SkillsMatter, [Rickasaurus](https://twitter.com/rickasaurus) and [Paul Blasucci](https://twitter.com/pblasucci), and a great opportunity to exchange with like-minded people, catch up with old friends and make new ones.

After some discussion with [Phil Trelford](https://twitter.com/ptrelford), we decided it would be a lot of fun to organize a workshop around PacMan. Phil has a long history with [game](http://www.allgame.com/game.php?id=14293&tab=credits) [development](http://www.imdb.com/name/nm2999421/?ref_=ttfc_fc_cr260), and a lot of wisdom to share on the topic. I am a total n00b as far as game programming goes, but I thought PacMan would make a fun theme to hack some AI, so I set to refactor some of Phil’s old code, and transform it into a “coding playground” where people could tinker with how PacMan and the Ghosts behave, and make them smarter.

<!--more-->

Long story short, the refactoring exercise turned out to be a bit more involved than what I had initially anticipated. First, games are written in a style which is pretty different from your run-of-the-mill business app, and getting familiar with a code base that didn’t follow a familiar style wasn’t trivial.

So here I am, trying to refactor that unfamiliar and somewhat idiosyncratic code base, and I start hitting stuff like this:

``` fsharp
let ghost_starts =
    [
        "red", (16, 16), (1,0)
        "cyan", (14, 16), (1,0)
        "pink", (16, 14), (0,-1)
        "orange", (18, 16), (-1,0)
    ]
    |> List.map (fun (color,(x, y), v) ->
    // some stuff happens here
        { … X = x * 8 - 7; Y = y * 8 - 3; V = v; … }
    )
```
This is where I begin to get nervous. I need to get this done quickly, and factor our functions, but I am really worried to touch any of this. What’s X and Y? Why 8, 7 or 3?

Part of the problem here is that the game merges two approaches: it is tile-based (the maze layout is built from square tiles), but also pixel-based, for the creatures movement and collisions. Being able to see more clearly what part of the code is dealing with pixels vs. tiles would be very helpful at that point.

And then it hits me – [Units of Measure](http://msdn.microsoft.com/en-us/library/dd233243.aspx) to the rescue!

What I really need is a mechanism that distinguishes between 8 tiles and 8 pixels, so that I don’t accidentally mix one and the other. That is exactly what Units of Measure are for: instead of integers everywhere, I can define a Pixel unit in one line:

``` fsharp
[<Measure>] type pix
```

I can now annotate the parts that I know are Pixels, like this:

``` fsharp
let TileSize = 8<pix>
```

or this:

``` fsharp
type Ghost = {
    // more stuff omitted
    X : int<pix>
    Y : int<pix>
    V : int<pix> * int<pix> }
```

Hit build, and everything breaks. *This is a good thing* – now the compiler is helping me out. Now that I told the compiler that some of the integers were actually pixels, it’s pointing out all the places where pixels should be passed, and I just have to go through the code and review everything that broke to know where these pixels are used.

I can start clarifying the code:

``` fsharp
let ghost_starts =
    [
        "red", (16, 16), (1<pix>, 0<pix>)
        "cyan", (14, 16), (1<pix>, 0<pix>)
        "pink" , (16, 14), (0<pix>, -1<pix>)
        "orange" , (18, 16), (-1<pix>, 0<pix>)
    ]
    |> List.map (fun (color,(x,y),v) ->
        // code omitted here
        { ...; X = x * TileSize - 7<pix>; Y = y * TileSize - 3<pix>; V = v; ... }
    )
```

This is great – now, I see that (16, 16) is not pixels, but the initial tile position of the Red Ghost, whereas (1, 0) is its velocity in pixels. I can refactor left and right, without having to write a single unit test, with a great sense of safety. Types are awesome.

So what’s the moral of the story here?

First, I have usually seen Units of Measure come up in the context of scientific computation. It’s an obvious use case: with very little work, you can make sure that you are not adding apples and oranges. This is handy if you don’t want to [blow up equipment worth 125 million dollars in space](http://en.wikipedia.org/wiki/Mars_Climate_Orbiter) for instance. On the other hand, scientific computations is a bit of a niche topic, which would seem to make that feature marginally useful. This example was interesting to me, because it shows how Units of Measure are an incredibly powerful debugging tool, applicable in areas that have nothing to do with science. Add a couple annotations to your code, and the compiler will pick up the hints and help you track down how the code works, at very little cost.

Then, adding Units of Measure gave me a deeper understanding of the code base. While I had realized that there was a duality between tiles and pixels in how the game worked, trying to fix one of the functions pointed out something else, the implicit presence of time in the game. If you think about it, the unit (`1<pix>`, `0<pix>`) on the ghost is slightly incorrect (if there is such a thing as “partly correct”…): what it represents is really a velocity, i.e. how many pixels per frame the creature is moving, and the correct unit should probably be `1<pix/frame>`. In this case, it didn’t really matter, because all creatures moved at constant speed, and I ended up ignoring the issue; however, if speed could change, I am pretty sure separating positions in pixels vs. speed in pixels per frame would again clarify the inner workings of the code a lot.
