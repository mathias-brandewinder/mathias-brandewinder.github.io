---
layout: post
title: How F# cured my 2048 addiction
tags:
- F#
- Algorithms
- Testing
- Canopy
- 2048
---

Like many a good man, I too got caught into the 2048 trap, which explains in part why I have been rather quiet on this blog lately (there are a couple [other](http://vimeo.com/97514517) [reasons](http://fsharpworks.com/paris/2014.html), [too](https://groups.google.com/forum/?fromgroups#!topic/fsharp-opensource/FsIWfxPrxaM)).

In case you don't know what 2048 is yet, first, consider yourself lucky - and, fair warning, you might want to back away now, while you still have a chance. 2048 is a very simple and fun game, and one of the greatest time sinks since Tetris. You can [play it here](http://gabrielecirulli.github.io/2048/), and the source code is [here on GitHub](https://github.com/gabrielecirulli/2048).

<!--more-->

I managed to dodge the bullet for a while, until [@PrestonGuillot](https://twitter.com/PrestonGuillot), a good friend of mine, decided to write a 2048 bot as a fun weekend project to sharpen his F# skills, and dragged me down with him in the process. This has been a ton of fun, and this post is a moderately organized collection of notes from my diary as a recovering 2048 addict.

Let's begin with the end result. The video below shows a F# bot, written by my friend [@Blaise_V](https://twitter.com/Blaise_V), masterfully playing the game. I recorded it a couple of weeks ago, accelerating time "for dramatic purposes":

<iframe width="560" height="315" src="https://www.youtube.com/embed/sjGVEkzylUY" frameborder="0" allowfullscreen></iframe>

One of the problems Preston and I ran into early was how to handle interactions with the game. A [recent post](http://www.hanselman.com/blog/NuGetPackageOfTheWeekCanopyWebTestingFrameworkWithF.aspx) by [@shanselman](https://twitter.com/shanselman) was praising Canopy as a great library for web UI testing, which gave me the idea to try it for that purpose. In spite of my deep incompetence of things web related, I found the Canopy F# DSL super easy to pick up, and got something crude working in a jiffy. With a bit of extra help from the awesome [@lefthandedgoat](https://twitter.com/lefthandedgoat), the creator of Canopy (thanks Chris!), it went from crude to pretty OK, and I was ready to focus on the interesting bits, the game AI.

I had so much fun in the process, I figured others might too, and turned this into another [Community for F# Dojo](http://c4fsharp.net/#list-of-dojos), which you can [find here](https://github.com/c4fsharp/Dojo-Canopy-2048).

The Dojo follows roughly my own path through the project. The point is to learn the basics of Canopy, to create a harness to interact with the 2048 game, and then begin experimenting with writing a bot for the game, using a couple of pre-written utility functions. It's a nice way to introduce newcomers to F# on a fun and lightweight problem, while picking up useful testing skills!

As an aside, we ran the Dojo at the San Francisco F# meetup group a couple of weeks ago. One of the worries I had was whether this would run on non-Windows environments, and sure enough, this was battle tested: we had participants using everything, from emacs on Mac, to Visual Studio on Windows and some editor on Linux. And... it all worked! Thanks to the awesome SF F# group for being good sports and helping fix issues, you guys rocked!

Canopy resolved one problem, talking to the web page. What Preston and I were really interested in was writing bots and experimenting with game strategies. For this, we needed to replicate the game engine, at least to an extent.

We ended up working out a domain model over pair programming sessions. One thing I noted again was that I tend to approach coding in F# and C# a bit differently. In C#, I usually start with high-level interfaces, sketching out the main components, mocking interactions and progressively fleshing out implementation TDD style. In F# I typically start low, and build from the bottom up, experimenting in the REPL along the way.

I suspect it's due to the fact that a functional style makes composition very easy - and you don't need "something" to hold functionality. Once you have the low-level, difficult pieces done, making them work together, and rearranging them differently if you are not happy with the result, isn't an issue, and there isn't much of a use in spending time on the top level concepts, they will emerge naturally.

(At that point, I believe that my F# workflow is actually very close in spirit to TDD, even though it looks pretty different on the surface. The REPL allows me to flesh out my design very fast, experimenting with actual use cases, without the friction of a testing framework in the early, fluid design stage.)

In that case, Preston immediately started thinking high-level components ("game state"), whereas I went straight for the basement, and attacked what I thought would be the trickiest part of the game, modeling how state changes when a move is executed.

My first thought was to focus on what happened to an individual column when the user pushes up. I made (at least) 3 considerations there:

* solving any direction (push a column up) solves the 3 others, because their behavior are equivalent, modulo a rotation,
* what happens to one column is independent from what happens to the 3 others, which makes it a natural way to break up the board,
* the top level API is obviously obvious (we are looking for a function that will look like State -> Move -> State); once the low level nitty-gritty is sorted out, building up to it and figuring out the correct data structure should be straightforward.

So what's happening when I push up a column?

* all non-empty tiles are stacked up to the top,
* adjacent tiles of same value are collapsed into a single tile, its value being their sum.

Let's assume the first step has been performed already. What we are left with is a list of values, the head corresponding to the top tile. How does the tiles collapsing work, exactly? For instance, how does `[2;2;4;4]` collapse? Should it be `[(2+2)+4;4]` or `[(2+2);(4+4)]`?

As it turns out, the second option is the correct one - which can be very nicely represented using List and pattern matching:

``` fsharp
let rec collapse acc list =
    match list with
    | [] -> acc
    | [x] -> x::acc
    | [a::b::rest] ->
        if a = b then
        collapse ((a+b)::acc) rest
        else
        collapse (a::acc) (b::rest)
```

In the process, the list ends up being reversed, so we can just wrap this in a function like this one:

``` fsharp
let process list =
    collapse [] list
    |> List.rev
```

And we are pretty much done. At that point, the only question of interest is how to represent the board itself, in a fashion that works reasonably well to both extract and store the board, and transform it into rows or columns which can be collapsed. I initially started with a sparse List of records, like

``` fsharp
type Cell = { Row:int; Column:int; Value:int; }
type Board = Cell seq
```

However, Preston pointed out, and rightly so, that this was rather unsatisfactory; in particular, it doesn't convey at all the fact that only one cell at most should be stored at a particular position. So we ended up with something more obvious, namely:

``` fsharp
type Position = { Row:int; Column:int; }
type Value = int
type Board = Map<Position,Value>
```

And that's pretty much it! The rest was mostly plumbing.

By a serendipitous turn of events, pretty much at the same time we finished hooking up everything together, I noticed a [tweet from @Blaise_V](https://twitter.com/Blaise_V/status/458651959831314433), who mentioned he had just written a bot, totally independently of our efforts, but had no UI for it. Win-win! We wired his code to our setup, and watched in awe Blaise's bot winning over 80% of the time.

Now what? Well, first, this project has cured me from any interest in playing 2048 myself. That being said, I am now wondering whether I can write a bot that performs better than Blaise's Expectimax beast, and started playing with a dynamic programming approach, which raises lots of fun questions. In case you’re interested, there is a [great discussion on StackOverflow](http://stackoverflow.com/questions/22342854/what-is-the-optimal-algorithm-for-the-game-2048) on the topic.

At any rate, it's been a fun exercise - and if you want to play with it, just grab the dojo, and have a go at it! And if you have feedback on how to make it better, send an issue or a pull request. Happy 2048!

## Links / Resources

[Canopy 2048 Community for F# Dojo](https://github.com/c4fsharp/Dojo-Canopy-2048)

[StackOverflow discussion on the optimal 2048 strategy](http://stackoverflow.com/questions/22342854/what-is-the-optimal-algorithm-for-the-game-2048)

[My 2048 experimentations repo](https://github.com/mathias-brandewinder/Canopy2048)
