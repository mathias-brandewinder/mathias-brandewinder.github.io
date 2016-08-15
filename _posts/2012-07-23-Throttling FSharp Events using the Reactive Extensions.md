---
layout: post
title: Throttling F# Events using the Reactive Extensions
tags:
- F#
- Rx
- Reactive
- Observable
- Bumblebee
- Throttling
---

Nothing fancy this week – just thought I would share some of what I learnt recently playing with the Reactive Extensions and F#.  

Here is the context: my current week-ends project, [Bumblebee](http://bumblebee.codeplex.com/), is a Solver, which, given a Problem to solve, will search for solutions, and fire an event every time an improvement is found. I am currently working on using in in Azure, to hopefully scale out and tackle problems of a larger scale than what I can achieve on a single local machine. One problem I ran into, though, is that if multiple worker roles begin firing events every time a solution is found, the system will likely grind to a halt trying to cope with a gazillion messages (not to mention a potentially unpleasantly high bill), whereas I really don’t care about every single solution – I care about being notified about some improvements, not necessarily every single one. What I want is an ability to “throttle” the flow of events coming from my solver, to receive, say, the best one every 30 seconds.  

For illustration purposes, here is a highly simplified version of the Bumblebee solver:  

``` fsharp
type Generator() =

    let intFound = new Event<int>()
    member this.IntFound = intFound.Publish

    member this.Start() =
        Task.Factory.StartNew(fun () ->
            printfn "Searching for numbers..."
            for i in 0 .. 100 do
                intFound.Trigger(i)
                Thread.Sleep(500)
            ) |> ignore
``` 

<!--more-->

The Generator class exposes a Start method, which, once called, will “generate” numbers from 0 to 100 – just like the Solver would return solutions of improving quality over time.

Generator declares an event, intFound, which will be triggered when we found a new integer of interest, and which is exposed through IntFound, which consumers can then subscribe to. When we Start the generator, we spin a new Task, which will be running on its own thread, and will simply produce integers from 0 to 100, with a 500ms delay between solutions.

The syntax for declaring an event is refreshingly simple, and we can use it in a way similar to what we would do in C#, by adding a Handler to the event, for instance in a simple Console application like this:

``` fsharp
let Main =

    let handler i = printfn "Simple handler: got %i" i

    let generator = new Generator()
    generator.IntFound.Add handler

    generator.Start()

    let wait = Console.ReadLine()
    ignore ()
``` 

Create a handler that prints out an integer, hook it up to the event, and run the application – you should see something like this happening:

![Simple Handler Output]({{ site.url }}/assets/2012-07-23-image_thumb_22.png)

So far, nothing very thrilling.

However, there is more. Our event this.IntFound is an IEvent, which inherits from IObservable, and allows you to do all sort of fun stuff with your events, like transform and compose them into something more usable. Out-of-the-box, the F# Observable module provides a few useful functions. Instead of adding a handler to the event, let’s start by subscribing to the event:

``` fsharp
et Main =

    let handler i = printfn "Simple handler: got %i" i

    let generator = new Generator()
    generator.IntFound.Add handler

    let interval = new TimeSpan(0, 0, 5)
    generator.IntFound
    |> Observable.subscribe (fun e -> printfn "Observed %i" e)
    |> ignore

    generator.Start()

    let wait = Console.ReadLine()
    ignore ()
``` 

This is doing essentially the same thing as before – running this will produce something along these lines:

![Console Output]({{ site.url }}/assets/2012-07-23-image_thumb_23.png)

As you can see, we have now 2 subscribers to the event. However, this is just where the fun begins. We can start transforming our event in a few ways – for instance, we could decide to filter out integers that are odd, and transform the result by mapping integers to floats, multiplied by 3 (why not?):

``` fsharp
let Main =

    let handler i = printfn "Simple handler: got %i" i

    let generator = new Generator()
    generator.IntFound.Add handler

    let interval = new TimeSpan(0, 0, 5)
    generator.IntFound
    |> Observable.filter (fun e -> e % 2 = 0)
    |> Observable.map (fun e -> (float)e * 3.0)
    |> Observable.subscribe (fun e -> printfn "Observed %f" e)
    |> ignore

    generator.Start()

    let wait = Console.ReadLine()
    ignore ()
``` 

Still not the most thrilling thing ever, but it proves the point – from a sequence of Events that was returning integers, we managed to transform it into a fairly different sequence, all in a few lines of code:

![Transformed Console Output]({{ site.url }}/assets/2012-07-23-image_thumb_24.png)

The reason I was interested in Observables, though, is because a while back, I attended a [talk ](http://www.baynetug.org/DesktopModules/DetailXEvents.aspx?ItemID=462&mid=49), given by my good friend [Petar](https://twitter.com/petarvucetin), where he presented the [Reactive Extensions](http://msdn.microsoft.com/en-us/data/gg577609.aspx) (Rx) – and I remembered that Rx had a few nice utilities built-in to manage Observables, which would hopefully help me achieve my goal, throttling my sequence of events over time.

At that stage, I wasted a bit of time, trying first to figure out whether or not I needed Rx (the F# module already has a lot built in, so I was wondering if maybe it had all I needed…), then I got tripped up by figuring out what Rx method I needed, and how to make it work seamlessly with F# and the pipe-forward operator.

Needing some “throttling”, I rushed into the [`Throttle`](http://rxwiki.wikidot.com/101samples#toc29) method, which looked plausible enough; unfortunately, throttle wasn’t doing quite what I thought it would – from what I gather, it filters out any event that is followed by another event within a certain time window. I see how this would come handy in lots of scenarios (think typing in a Search Box – you don’t want to trigger a Search while the person it typing, so waiting until no typing occurs is a good idea), but what I really needed was [Sample](http://rxwiki.wikidot.com/101samples#toc28), which returns only the latest event that occurred by regular time window.

Now there is another small problem: [`Observable.Sample`](http://msdn.microsoft.com/en-us/library/ff707287(v=vs.92).aspx) takes in 2 arguments, the Observable to be sampled, and a sampling interval represented as a `TimeSpan`. The issue here is that because of the C#-style signature, we cannot directly use it with a pipe-forward. It’s simple enough to solve, though: create a small extension method, extending the Observable module with a composable function:

``` fsharp
module Observable =
    let sample (interval: TimeSpan) (obs: IObservable<'a>) =
        Observable.Sample(obs, interval)
``` 

And we are now set! Armed with our new sample function, we can now do the following:

``` fsharp
let Main =

    let handler i = printfn "Simple handler: got %i" i

    let generator = new Generator()
    generator.IntFound.Add handler

    let interval = new TimeSpan(0, 0, 5)
    generator.IntFound
    |> Observable.filter (fun e -> e % 2 = 0)
    |> Observable.map (fun e -> (float)e * 3.0)
    |> Observable.sample interval
    |> Observable.subscribe (fun e -> printfn "Observed %f" e)
    |> ignore

    generator.Start()

    let wait = Console.ReadLine()
    ignore ()
``` 

We sample our event stream every 5 seconds, returning only the latest that occurred in that window. Running this produces the following:

![Sampled Events In Console]({{ site.url }}/assets/2012-07-23-image_thumb_25.png)

As you can see, while the original handler is capturing an event every half second, our Observable is showing up every 10 events, that is, every 5 seconds, which is exactly what we expected – and I have now exactly what I need to “throttle” the solutions stream coming from Bumblebee.

That’s it for today – fairly simple stuff, but hopefully this illustrates how easy it is to work with events in F#, and what Observables add to the table, and maybe this will come in useful for someone!

Additional resources I found useful or interesting underway:

[Time Flies Like an Arrow in F#](http://weblogs.asp.net/podwysocki/archive/2010/03/28/time-flies-like-an-arrow-in-f-and-the-reactive-extensions-for-net.aspx)

[Reactive Programming: First Class Events in F#](http://tomasp.net/blog/reactive-i-fsevents.aspx)

[FSharp.Reactive](https://github.com/panesofglass/FSharp.Reactive)

Full code sample (F# console application, using Rx Extensions)

``` fsharp
open System
open System.Threading
open System.Threading.Tasks
open System.Reactive.Linq

type Generator() =

    let intFound = new Event<int>()
    [<CLIEvent>]
    member this.IntFound = intFound.Publish

    member this.Start() =
        Task.Factory.StartNew(fun () ->
            printfn "Searching for numbers..."
            for i in 0 .. 100 do
                intFound.Trigger(i)
                Thread.Sleep(500)
            ) |> ignore

module Observable =
    let sample (interval: TimeSpan) (obs: IObservable<'a>) =
        Observable.Sample(obs, interval)

let Main =

    let handler i = printfn "Simple handler: got %i" i

    let generator = new Generator()
    generator.IntFound.Add handler

    let interval = new TimeSpan(0, 0, 5)
    generator.IntFound
    |> Observable.filter (fun e -> e % 2 = 0)
    |> Observable.map (fun e -> (float)e * 3.0)
    |> Observable.sample interval
    |> Observable.subscribe (fun e -> printfn "Observed %f" e)
    |> ignore

    generator.Start()

    let wait = Console.ReadLine()
    ignore ()
``` 
