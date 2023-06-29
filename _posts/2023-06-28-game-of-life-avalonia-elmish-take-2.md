---
layout: post
title: Game of Life in Avalonia, MVU / Elmish style, take 2
tags:
- F#
- User-Interface
- Avalonia
- Elmish
---

This is a follow-up to my recent post trying to implement the classic 
[Conway Game of Life in an MVU style with Avalonia.FuncUI][1]. While I managed 
to get a version going pretty easily, the performance was not great. The 
visualization ran OK until around 100 x 100 cells, but started to degrade 
severely beyond that.  

After a bit of work, I am pleased to present an updated version, which runs 
through a 200 x 200 cells visualization pretty smoothly:  

![gif: game of life running]({{ site.url }}/assets/2023-06-28/GameOfLifeMVU.gif)

> As a side note, I wanted to point out that the size change is significative. 
> Increasing the grid size from 100 to 200 means that for every frame, the 
> number of elements we need to refresh grows from 10,000 to 40,000.  

In this post, I will go over what changed between the two versions.

> You can find the [full code here on GitHub][2]

<!--more-->

## Upgrading from Avalonia.FuncUI 0.5.0 to 1.0.0-rc.1.1.1

The first change I made was simply to upgrade from 
`JaggerJo.Avalonia.FuncUI version 0.5.0` to the recently published pre-release 
`Avalonia.FuncUI version 1.0.0-rc.1.1.1`.  

How I picked the original version was mostly by accident. I got a little 
confused between the various forks and documentation sources for the library, 
and I _think_ I landed on that one because of the templates.  

Regardless, the update was pretty straightforward. I replaced the dependencies, 
which brought Avalonia up from version `0.10.12` to `11.0.0.rc1.1`. This 
required 2 changes to the original code:  

### Minor changes in `Program.fs`, which launches the application. See 
[this commit][3] for details, nothing particularly interesting going on here.  

### Changes to the asynchronous update

That change was more interesting. In my original version, I triggered updates 
by emitting a delayed asynchronous command, like so:  

``` fsharp
Cmd.OfAsync.perform
    (fun () -> async { do! Async.Sleep config.RefreshIntervalMilliseconds })
    ()
    (fun () -> NextGeneration)
```

This compiled just fine in the updated version, but exploded at runtime. Based 
on the exceptions, I suspected that the source of the issue was an operation 
not running on the UI thread. After a bit of tinkering, and reading an older 
post on [writing non-blocking user-interfaces in F# by Tomas Petricek][4], I 
ended up modifying the code into this:  

``` fsharp
let update (msg: Msg) (state: State): State * Cmd<Msg> =
    match msg with
    // omitted for brevity
    | NextGeneration ->
        // omitted for brevity
        let ctx = SynchronizationContext.Current
        let cmd =
            Cmd.OfAsync.perform
                (fun () -> async {
                    do! Async.Sleep config.RefreshIntervalMilliseconds
                    do! Async.SwitchToContext ctx
                    return Msg.NextGeneration
                    }
                )
                ()
                id
        { state with
            Cells = updated;
            Generation = state.Generation + 1
        },
        cmd
```

> Note: I could also have used a subscription with a timer, as outlined in some 
> of the samples. However, I was interested in trying out this approach, as an 
> example of background async processing.

This already produced minor performance improvements, but it was still not 
where I wanted it to be. So I grabbed [dotTrace][5] again for some profiling.  

## Careful with F# lists

Among other things, profiling lead me to a hotspot in Avalonia.FuncUI itself 
(slightly reformatted here):  

``` fsharp
let diffContentMultiple (lastList: IView list, nextList: IView list) : ViewDelta list =
    nextList
    |> List.mapi (fun index next ->
        if index + 1 <= lastList.Length then
            Differ.diff(lastList.[index], nextList.[index])
        else
            ViewDelta.From next
    )
```

The intent of this function goes something like this: if a UI element contains 
a list of nested UI elements (`IView`), compare the view before (`lastList`) 
and after (`nextList`) the view update. Compute the differences if there is an 
element in both (`Differ.diff`), otherwise, if new elements have been added to 
the list, compute `ViewDelta` for the new element.  

Now, typically there won't be many nested elements. However, in my case, that 
list is pretty massive (`40,000` elements for a 200 x 200 grid), and this is 
where things begin to fall apart, for 2 reasons. An F# list is a linked list, 
and as a result:  

- Accessing an item by index in a `List` scales with the index of the list,
- Computing the length of a list scales with the lenght of the list.

Let's illustrate with a crude benchmark in the scripting environment, 
reproducing the situation with 2 simplified examples:  

``` fsharp

#time "on"

let list_10 = [ 1 .. 10 ]
let list_1_000 = [ 1 .. 1_000 ]
let list_100_000 = [ 1 .. 100_000 ]

let index list =
    list
    |> List.mapi (fun i x -> list.[i])
    |> ignore

let length list =
    list
    |> List.mapi (fun i x -> list.Length)
    |> ignore
```

```
> index list_10;;
Real: 00:00:00.002, CPU: 00:00:00.000, GC gen0: 0, gen1: 0, gen2: 0

> index list_1_000;;
Real: 00:00:00.002, CPU: 00:00:00.000, GC gen0: 0, gen1: 0, gen2: 0

> index list_100_000;;
Real: 00:00:05.219, CPU: 00:00:04.500, GC gen0: 0, gen1: 0, gen2: 0
```

```
> length list_10;;
Real: 00:00:00.002, CPU: 00:00:00.000, GC gen0: 0, gen1: 0, gen2: 0

> length list_1_000;;
Real: 00:00:00.003, CPU: 00:00:00.031, GC gen0: 0, gen1: 0, gen2: 0

> length list_100_000;;
Real: 00:00:10.297, CPU: 00:00:09.656, GC gen0: 0, gen1: 0, gen2: 0
```

These are rough measurements, using the timer in fsi. Even if the measurements 
might not be entirely accurate, the big picture is clear. Everything is fine 
for lists of 10 or 1,000 elements, but we fall off a cliff for 100,000 
elements, going from milliseconds to seconds. The problem is two-fold: as the 
lists get longer, 

- we make the same calls more and more often,  
- the calls themselves get slightly worse for longer lists.

Long story short, I submitted a proposed improvement, and a 
[fun discussion ensued][https://github.com/fsprojects/Avalonia.FuncUI/pull/317] 
with [JaggerJo][6] and [Numpsy][7], exploring alternatives. And the result is 
now part of [`Avalonia.FuncUI version 1.0.0-rc.1.1.1`][8]!

## Parting words

I had a lot of fun digging into this issue, especially because it made such an 
improvement in that little Game of Life implementation! I usually don't spend 
that much time performance tuning, but I find it enjoyable to hone in on one 
very narrow problem, and dissect the hell out of it.  

I will probably do another pass at looking for performance hot spots. In 
general it's an interesting problem, basically efficiently identifying the diff 
between 2 lists of arbitrary sizes. However, I suspect it's going to be harder 
to find similarly clean hotspots - after all, I found that one only because of 
that specific Game of Life example, which happens to push the number of 
UI elements beyond what you would typically expect :)

And... thanks a lot to [JaggerJo][6] and [Numpsy][7] for a fun discussion!  

If you have comments or questions, hit me up on [Mastodon][9]!  

> You can find the [full code here on GitHub][2]

[1]: https://brandewinder.com/2023/06/17/wip-game-of-life-avalonia-elmish/
[2]: https://github.com/mathias-brandewinder/GameOfLifeMvu/tree/fd4e9242df70bdbb7df91b2133f4f6b6fc7b15f0
[3]: https://github.com/mathias-brandewinder/GameOfLifeMvu/commit/f3ba539be96cd40b3c038ab57fb20f7e7be154aa?diff=split#diff-1bb09fd3cbba270825beac2b9db35c64baab798c79fe92932e88058c10e3bfe2
[4]: https://tomasp.net/blog/async-non-blocking-gui.aspx/
[5]: https://www.jetbrains.com/profiler/
[6]: https://mastodon.social/@josua_jaeger
[7]: https://github.com/Numpsy
[8]: https://www.nuget.org/packages/Avalonia.FuncUI

[9]: https://hachyderm.io/@brandewinder
