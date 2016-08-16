---
layout: post
title: Plot functions from F# to Excel
tags:
- F#
- Excel
- Chart
- Visualization
---

In spite of being color blind, I am a visual guy - I like to see things. Nothing beats a chart to [identify problems in your data](http://alumni.stanford.edu/get/page/magazine/article/?article_id=32181). I also spend lots of time manipulating data in FSI, the F# REPL, and while solutions like [FSharpChart](http://code.msdn.microsoft.com/windowsdesktop/FSharpChart-b59073f5) makes it possible to produce nice graphs fairly easily, I still find it introduces a bit of friction, and wondered how complicated it would be to use Excel as a charting engine.

Turns out, it's not very complicated. The typical use case for generating charts in Excel is to first put data in a spreadsheet, and use the corresponding range as a source for a chart. However, it's also perfectly possible to directly [create a Chart object, and manipulate its SeriesCollection]( {{ site.url }}/2012/01/14/Create-an-Excel-chart-in-C-without-worksheet-data/), adding and editing Series, which are arrays of XValues and Values.

As a starting point, I decided to focus on 2 problems:

* plotting functions, in 2 and 3 dimensions, 
* producing scatterplots.

Both are rather painful to do in Excel itself - and scatterplots are the one chart I really care about when analyzing data, because it helps figuring out whether or not some variables are related.

What I wanted was a smooth experience from FSI - start typing code, and ship data to Excel, without having to worry about the joys of the Excel interop and its syntax. The video below shows what I ended up with, in action.

*Note: watching me type is about as exciting as watching paint dry, so I sped up the video from its original 5 minutes down to 2 - otherwise there is no trick or editing.*

<iframe width="560" height="315" src="https://www.youtube.com/embed/5loQ7zb5HE8" frameborder="0" allowfullscreen></iframe>
*This year's blockbuster: plotting functions from F# to Excel*

<!--more-->

I'll try to do another one on scatterplots later. In the meanwhile, here are some comments on the script, which you can find [here on GitHub](https://github.com/mathias-brandewinder/Excel-Charts).

I really wanted to shield the user from dealing with Excel interop (if you have had the pleasure to deal with it, you know why) - the two functions below help achieving that:

``` fsharp
// Attach to the running instance of Excel, if any
let Attach () = 
    try
        Marshal.GetActiveObject("Excel.Application") 
        :?> Microsoft.Office.Interop.Excel.Application
        |> Some
    with
    | _ -> 
        printfn "Could not find running instance of Excel"
        None

// Find the Active workbook, if any
let Active () =
    let xl = Attach ()
    match xl with
    | None -> None
    | Some(xl) ->
        try
            xl.ActiveWorkbook |> Some   
        with
        | _ ->
            printfn "Could not find active workbook"
            None
``` 

The first looks for a running instance of Excel, and 'attaches' to it, and the second finds the currently active workbook, where new Charts will be produced. As a result, as long as Excel is open, the script will know where to do its work.

*Caveat: if multiple instances of Excel are open (which is typically not the case), results might be a bit unpredictable.*

I went back and forth, but ended up implementing the function plot as a Class, because maintaining some state simplified quite a bit things like adding functions to an existing plot, and resizing / zooming. Here is the full code for Plot, with some comments afterwards:

``` fsharp
type Plot (f: float -> float, over: float * float) =
    let mutable functions = [ f ]
    let mutable over = over
    let mutable grain = 50
    let chart = NewChart ()
    let values () = 
        let min, max = over
        let step = (max - min) / (float)grain
        [| min .. step .. max |]
    let draw f =
        match chart with
        | None -> ignore ()
        | Some(chart) -> 
            let seriesCollection = chart.SeriesCollection() :?> SeriesCollection
            let series = seriesCollection.NewSeries()
            let xValues = values ()
            series.XValues <- xValues
            series.Values <- xValues |> Array.map f
    let redraw () =
        match chart with
        | None -> ignore ()
        | Some(chart) ->
            let seriesCollection = chart.SeriesCollection() :?> SeriesCollection            
            for s in seriesCollection do s.Delete() |> ignore
            functions |> List.iter (fun f -> draw f)

    do
        match chart with
        | None -> ignore ()
        | Some(chart) -> 
            chart.ChartType <- XlChartType.xlXYScatter
            let seriesCollection = chart.SeriesCollection() :?> SeriesCollection
            draw f

    member this.Add(f: float -> float) =
        match chart with
        | None -> ignore ()
        | Some(chart) ->
            functions <- f :: functions
            draw f

    member this.Rescale(min, max) =
        over <- (min, max)
        redraw()

    member this.Zoom(zoom: int) =
        grain <- zoom
        redraw()   
``` 

**`Plot`** maintains a list of functions with signature `float  - > float`, an interval (a tuple of floats) over which to plot them, and a 'grain', which represents how many points will be plotted over that interval. The values() function generates the X-values of the chart, by dividing equally the interval proportionally to the grain, and draw f adds a new Series to the chart, filling in the XValues with values(), and mapping each of them by the function f. Three methods are publicly exposed: Add (to add a new function to the Plot), Rescale (to change the bounds of the display interval), and Zoom (to set the granularity of the display).

The usage of Plot is as simple as the following: load the script into FSI, launch Excel, and go:

``` fsharp
> let f x = cos x;;
val f : x:float -> float
> let plot = Plot(f, (0., 1.));;
val plot : Plot
> let pi = System.Math.PI;;
val pi : float = 3.141592654
> plot.Rescale(-pi, pi);;
val it : unit = ()
> plot.Zoom(200);;
val it : unit = ()
```

The Surface plot is very similar, except that it expects a function of 2 arguments, like this:

``` fsharp
> let g x y = cos x * sin y;;
val g : x:float -> y:float -> float
> let s = Surface(g, (0., pi), (0., pi));;
val s : Surface
```

That's it for today! Next time, I'll talk about the scatterplots. In the meanwhile, if you have feedback, I'd love to hear it. This is still work in progress (obviously, I need to add classic charts like histograms, bars, and lines, this is coming soon), and I am designing it for my own needs - if you see something which would make it better for you, let me know - or place a pull request!

## Resources

[Excel-Charts](https://github.com/mathias-brandewinder/Excel-Charts): full script on GitHub


[FSharpChart](http://code.msdn.microsoft.com/windowsdesktop/FSharpChart-b59073f5): a F# library to generate charts from FSI.

[Unconstrained optimization test functions](http://www-optima.amp.i.kyoto-u.ac.jp/member/student/hedar/Hedar_files/TestGO_files/Page364.htm): Dr. Abdel-Rahman Hedar awesome collection of funky functions.
