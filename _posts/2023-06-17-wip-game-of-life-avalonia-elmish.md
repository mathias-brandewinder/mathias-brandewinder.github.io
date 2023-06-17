---
layout: post
title: WIP&#58; Game of Life in Avalonia, MVU / Elmish style
tags:
- F#
- User-Interface
- Avalonia
- Elmish
---

A couple of days ago, I came across [a toot from Khalid Abuhakmeh][1], 
showcasing a C# + MVVM implementation of the Game of Life on [Avalonia][2]. I 
have been experimenting with Avalonia funcUI recently, and thought a conversion 
would be both a fun week-end exercise, and an interesting way to take a look at 
performance.  

Long story short, I took a look at [his repository][3] as a starting point, and 
proceeded to rewrite it in an Elmish style, shamelessly lifting the core from 
his code. The good news is, it did not take a lot of time to get it running, 
the less good news is, my version has clear performance issues.

![gif: game of life running]({{ site.url }}/assets/2023-06-17/GameOfLifeMVU.gif)

In this post, I will go over how I approached it so far, and where I _think_ 
the performance issues might be coming from. In a later post, I'll try to see 
if I can fix these. As the French saying goes, "A chaque jour suffit sa peine".  

> You can find the [full code here on GitHub][4]

<!--more-->

## Modeling the Game of Life, F# remix

Overall I deliberately kept the design close to Khalid's version -- in part out 
of laziness, in part to facilitate comparison.  

At its core, my model is a 2D array of cells. The main difference with the C# 
model is that a `Cell` is represented as a Discriminated Union:  

``` fsharp
type Cell =
    | Dead
    | Alive of age: int
```

A `Cell` is either `Dead` or `Alive`, in which case we track for how many 
generations it has been alive for. As a result, our `State` is simply a 2D 
array of cells, where the position of the cell is its indices:  

``` fsharp
type State = {
    Generation: int
    Running: bool
    Cells: Cell [,]
    }
```

Calculating the next generation follows simple rules:  

- A `Dead` cell will come alive if it has exactly 3 live neighbors,
- A `Live` cell will stay alive if it has exactly 2 or 3 live neighbors.

That part can be expressed like so:  

``` fsharp
match cells.[row, col] with
| Dead ->
    if liveNeighbors = 3
    then Alive 0
    else Dead
| Alive age ->
    if liveNeighbors = 2 || liveNeighbors = 3
    then Alive (age + 1)
    else Dead
```

The painful part was counting the number of `liveNeighbors`. We need to check 
all 8 adjacent cells, ignoring the ones that fall off the board at the edges. 
This is probably not the smartest way to go about it, but I ended up creating 
a list of offsets from the current cell:  

``` fsharp
let neighbors =
    [
        -1, -1
        -1, 0
        -1, 1
        0, -1
        0, 1
        1, -1
        1, 0
        1, 1
    ]
```

... which allows me to iterate over the offsets and count the live neighbors:  

``` fsharp
let nextGeneration (cells: Cell [,]) (row: int, col: int) =
    let isAlive (row, col) =
        if row < 0 || col < 0 || row >= cells.GetLength(0) || col >= cells.GetLength(1)
        then false
        else cells.[row, col] <> Dead
    let liveNeighbors =
        neighbors
        |> Seq.sumBy (fun (dx, dy) ->
            if isAlive (row + dx, col + dy)
            then 1
            else 0
            )
    match cells.[row, col] with
    | Dead ->
        if liveNeighbors = 3
        then Alive 0
        else Dead
    | Alive age ->
        if liveNeighbors = 2 || liveNeighbors = 3
        then Alive (age + 1)
        else Dead
```

That's pretty much it for the model itself. The view rendering follows Khalid's 
approach pretty closely, a `UniformGrid` with one `Rectangle` per cell:  

``` fsharp
UniformGrid.create [

    UniformGrid.margin 5

    UniformGrid.columns state.Columns
    UniformGrid.rows state.Rows

    UniformGrid.width (state.Columns * config.CellSize |> float)
    UniformGrid.height (state.Rows * config.CellSize |> float)

    UniformGrid.children [
        for row in 0 .. state.Rows - 1 do
            for col in 0 .. state.Columns - 1 do
                match state.Cells.[row, col] with
                | Dead -> deadCell
                | Alive age ->
                    if age < 2
                    then youngCell
                    else oldCell
        ]
    ]
```

Where `deadCell` is defined as

``` fsharp
let deadCell =
    Rectangle.create [
        Rectangle.width config.CellSize
        Rectangle.height config.CellSize
        Rectangle.fill "Black"
        ]
```

One piece that is perhaps interesting is the update loop itself. The way I 
approached it is by sending delayed messages back to the `update` function, 
like so (omitting some details for clarity):  

``` fsharp
let update (msg: Msg) (state: State): State * Cmd<Msg> =
    match msg with
    | NextGeneration ->
        let updated =
            state.Cells
            |> Array2D.mapi (fun row col _ ->
                nextGeneration state.Cells (row, col)
                )
        { state with
            Cells = updated;
            Generation = state.Generation + 1
        },
        waitAndUpdate
```

Whenever a `NextGeneration` message arrives, the new state is computed, and 
emites a command, `waitAndUpdate`:  

``` fsharp
let waitAndUpdate =
    Cmd.OfAsync.perform
        (fun () -> async { do! Async.Sleep config.RefreshIntervalMilliseconds })
        ()
        (fun () -> NextGeneration)
```

Essentially, we sleep for the `RefreshIntervalMilliseconds`, and upon 
completion we fire another message, `NextGeneration`, which goes back to the 
`update` function, triggering the delayed computation of another generation, 
followed by another `NextGeneration` message.  

## Performance

Khalid mentioned somewhere that his MVVM version got  

> a 250x250 UniformGrid showing the game of life at a reasonable pace

I can't say the same of my current version. At the moment, things start to 
crumble around 100x100, with an unresponsive UI.  

A good starting point when looking at a code issue is "my code has issues". So, 
as a sanity check, I did a quick and dirty benchmark for how long it took to 
generate 1,000 generations, for a 250 x 250 population, no UI involved. This 
takes around 12 seconds on my machine. I am sure I can squeeze some 
improvements there, but with 12-ish milliseconds for a generation update, this 
is not the source of the issue.  

The next step was profiling with [dotTrace][5]: run for 3 minutes, and see 
what happens:  

![dotTrace snapshot]({{ site.url }}/assets/2023-06-17/dotTrace.png)

I am not an expert on profiling, but my sense from what I am seeing here is 
that rendering is dying under pressure. What jumps out to me from a casual 
inspection is: half the time spent in lock contention, and there is a whole lot 
of UI freeze, and calls to `Avalonia.Rendering.DeferredRenderer.Render()`, and 
to a lesser extent `DrawPath`, `CreatePaint`, `DrawGeometry`.  

So... what next?

What I think is happening is, updates are happing too fast for rendering to 
keep up. Assuming a full redraw, each generation requires a refresh of:  

- 50 x 50: 2,500 rectangles,
- 100 x 100: 10,000 rectangles,
- 150 x 150: 22,500 rectangles,
- 200 x 200: 40,000 rectangles,
- 250 x 250: 62,500 rectangles.

Given that the loop produces a new updated grid to render at fixed intervals, 
mechanically, at some point, new states will come in faster than they can be 
rendered. As the number of cells increases as a square of the grid size, it is 
to be expected that rendering will collapse. However, it would be nice to defer 
that unavoidable demise further than 100 x 100 :)

The part that I find interesting is, I am not entirely sure yet how to improve 
performance. This is speculation at that point, but here are some of my current 
thoughts:  

- There might be a few low hanging fruits, for instance perhaps making sure 
that I am re-using brushes and not re-creating them un-necessarily.
- However, overall speed probably hinges on re-drawing only the Rectangles that 
have changed. If a Cell has not changed state, do not redraw it.  

For the last part, I will need to dig a little deeper into funcUI and its 
virtual DOM. My conceptual understanding is that behind the scenes, upon every 
view update, the engine computes a diff between the current and the new view, 
and redraws what requires redrawing. Stated differently: I am not directly in 
control of caching or smart UI updates. That's the part I need to understand 
better, so that I can:  

- Create objects that are easy to compare,
- Help the engine perform comparisons. I noticed in particular a couple 
functions (`View.createWithKey`, `View.withKey`, `View.withOutlet`) which I 
suspect have something to do with giving identifiers for view elements, 
presumably for comparison purpose (this is total speculation on my part),  
- Perhaps even look at potential improvements in the library itself.

Anyways, this is where I will leave things at for today! Shout out to 
[@khalidabuhakmeh][6] for inspiring this, and making his repo accessible, this 
is a fun problem, and a great benchmark to explore performance questions. As a 
side note, this does not change my interest in Avalonia funcUI one bit. In 
general, a business-y UI will rarely require redrawing tens of thousands of 
elements per second.

I will come back to this problem over the next few weeks, and would love to hear 
your thoughts on how to approach this!

If you have comments or questions, hit me up on [Mastodon][7]!

> You can find the [full code here on GitHub][4]

[1]: https://mastodon.social/@khalidabuhakmeh/110504083946218161
[2]: https://www.avaloniaui.net/
[3]: https://github.com/khalidabuhakmeh/GameOfLifeMvvm
[4]: https://github.com/mathias-brandewinder/GameOfLifeMvu/tree/bec2141d5e711348b639646364911f7410643b33
[5]: https://www.jetbrains.com/profiler/
[6]: https://mastodon.social/@khalidabuhakmeh
[7]: https://hachyderm.io/@brandewinder
