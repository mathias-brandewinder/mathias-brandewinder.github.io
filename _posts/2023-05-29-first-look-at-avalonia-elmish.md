---
layout: post
title: First look at Avalonia with Elmish&#58; wrapping OxyPlot charts
tags:
- F#
- User-Interface
- Avalonia
- Elmish
---

In the recent weeks, I came across a use case which sounded like a good fit for 
a desktop application, which got me curious about the state of affairs for .NET 
desktop clients these days. And, as I was looking into this, I quickly came 
across [Avalonia][1], and specifically [Avalonia.FuncUI][2]. Cross platform 
XAML apps, using F# and the Elmish loop? My curiosity was piqued, and I figured 
it was worth giving it a try.  

In this post, I will go over my first steps trying the library out. My 
ambitions are limited: first, how hard is it to get something running? Then, 
how hard is it to take an existing Avalonia library (in this case, the 
charting library [OxyPlot][3]), and bolt it into an Elmish style Avalonia app?

> You can find the [full code here on GitHub][8]

<!--more-->

## Getting started

Let's get this party started, beginning with installing the template:

```
dotnet new --install JaggerJo.Avalonia.FuncUI.Templates
```

Here we go:

```
Success: JaggerJo.Avalonia.FuncUI.Templates::0.5.0 installed the following templates:
Template Name                      Short Name        Language  Tags
---------------------------------  ----------------  --------  --------------------------
Avalonia FuncUI App                funcui.basic.mvu  F#        Console/Avalonia/UI/Elmish
Avalonia FuncUI App                funcui.basic      F#        Console/Avalonia/UI/Elmish
Avalonia FuncUI App (with extras)  funcUI.full.mvu   F#        Console/Avalonia/UI/Elmish
Avalonia FuncUI App (with extras)  funcUI.full       F#        Console/Avalonia/UI/Elmish
```

We get 2 templates, basic and full, with 2 flavors, "plain" or mvu. As far as 
I can tell, the MVU flavor creates a canonical Model-View-Update app, aka an 
Elmish app, whereas the "plain" flavor uses Components, which I have not had 
time yet to dig into.  

I am interested in Elmish, so let's go with that:  

```
dotnet new funcUI.full.mvu --name LearningAvalonia
```

Template created, we can now run the default app created by the template:

```
cd LearningAvalonia
dotnet run
```

... and it works:

![Default Avalonia MVU app running]({{ site.url }}/assets/2023-05-29/avalonia-template-app.png)

We have a desktop app running, and it was pretty painless.

## How does this work?

My goal here is not to understand in depth how everything works. What I want is 
to start forming a picture of how the pieces fit together, in reference to the 
Elmish I know, that is, Elmish in Fable.

Let's take a look at (a subset of) what the template created:

```
LearningAvalonia
|_ Counter.fs
|_ Shell.fs
|_ Program.fs
|_ Styles.xaml
```

`Program.fs` is the entry point. Looks like mostly application setup, let's 
skip to `Shell.fs`. At the bottom of the file, we find this:

``` fsharp
type MainWindow() as this =
    inherit HostWindow()
    do
        // code omitted for brevity

        Elmish.Program.mkProgram (fun () -> init) update view
        |> Program.withHost this
        |> Program.run
```

This is familiar! We have the starting point of our Elmish loop, with the 
`init`, `update` and `view` functions. The Shell hooks up two sub-pages, each 
in its own tab, the Counter and the About pages. Let's dive straight into what 
is happening in `Counter.fs`:

``` fsharp
module Counter =

    // open statements omitted for brevity

    type State = { count : int }
    let init = { count = 0 }

    type Msg = Increment | Decrement | Reset

    let update (msg: Msg) (state: State) : State =
        match msg with
        | Increment -> { state with count = state.count + 1 }
        | Decrement -> { state with count = state.count - 1 }
        | Reset -> init
```

If you have used Elmish before, this should be very familiar. What about the 
view function, then?  

Avalonia.funcUI has its own DSL, to declaratively create the UI. The pattern is 
pretty straightforward:  

``` fsharp
StackPanel.create [
    StackPanel.dock Dock.Bottom
    StackPanel.margin 5.0
    StackPanel.spacing 5.0
    StackPanel.children [
        Button.create [
            Button.onClick (fun _ -> dispatch Reset)
            Button.content "reset"
            ]
    ]
```

`StackPanel.create` expects a list of `IAttr<StackPanel>`, and creates a 
`IView<StackPanel>`, the UI element itself. We can nest UI components further 
by using `StackPanel.children`, which expects a list of `IView`. If you have 
used Feliz or Fulma, this should be quite familiar.

## Using OxyPlot: preparing the scene

Avalonia.funcUI comes loaded with many of the standard Controls you would 
expect. One question I was interested in, though, is the following: how easy is 
it to consume an existing Avalonia library in an Elmish app?  

As an example, I figured I would try out OxyPlot, a charting library that 
offers Avalonia support. For illustration purposes, let's add a simple tab to 
the app, where we will:

- Generate a random series of points whenever we click a button,
- Render these points as a line series.

Let's start with the easy part, namely adding that tab. First, we will add a 
new file, anywhere above `Shell.fs`, and call it `Chart.fs`, and set up a crude 
MVU app:

``` fsharp
namespace LearningAvalonia

module Chart =

    open System
    open Elmish
    open Avalonia.Controls
    open Avalonia.FuncUI.DSL

    let createSeries () =
        let rng = Random ()
        Array.init 20 (fun i -> float i, rng.NextDouble ())

    type State = {
        Series: (float * float) []
        }

    let init () : State =
        { Series = createSeries () }

    type Msg =
        | CreateNewSeries

    let update (msg: Msg) (state: State) : State * Cmd<Msg> =
        match msg with
        | CreateNewSeries ->
            { Series = createSeries () },
            Cmd.none

    let view (state: State) (dispatch: Msg -> unit)=
        TextBlock.create [
            TextBlock.text "TODO"
            ]
```

We can now bolt that into the `Shell`, hosting that app in a new tab. First, we 
need to add `Chart.State` and `Chart.Msg` to the overall app:

``` fsharp
type State = {
    aboutState: About.State
    counterState: Counter.State
    chartState: Chart.State
    }

type Msg =
    | AboutMsg of About.Msg
    | CounterMsg of Counter.Msg
    | ChartMsg of Chart.Msg
```

We bolt the corresponding parts in the `init` and `update` functions:

``` fsharp
let init =
    let aboutState, aboutCmd = About.init
    let counterState = Counter.init
    let chartState = Chart.init ()
    {
        aboutState = aboutState
        counterState = counterState
        chartState = chartState
    },
    Cmd.batch [ aboutCmd ]

let update (msg: Msg) (state: State): State * Cmd<_> =
    match msg with
    | AboutMsg bpmsg ->
        // omitted for brevity
    | CounterMsg countermsg ->
        // omitted for brevity
    | ChartMsg chartMsg ->
        let updatedState, _ = Chart.update chartMsg state.chartState
        { state with chartState = updatedState },
        Cmd.none
```

And we can now add a new tab, like so:

``` fsharp
let view (state: State) (dispatch) =
    DockPanel.create [
        // omitted for brevity
        TabControl.viewItems [
            // omitted for brevity
            TabItem.create [
                TabItem.header "Charts"
                TabItem.content (Chart.view state.chartState (ChartMsg >> dispatch))
                ]
```

This is done. The application runs, and produces a new tab, Charts, which 
currently only displays TODO.  

## Using OxyPlot: adding a chart

`Chart.fs` contains a model, with a series of numbers. What I want now is to 
take this series, and display them as a chart using OxyPlot.  

Let's add first the corresponding package to our project:

```
dotnet add package OxyPlot.Avalonia
```

First, how does OxyPlot work? I never used it before, so it took a bit of 
digging in the docs. Fast forward a bit, I found in the 
[OxyPlot Avalonia samples][4] a relevant example, [ScatterDemo][5]. The `xaml` 
file indicates that we want an OxyPlot `PlotView`, which expects a Model. The
`xaml.cs` file gives some further hints: that Model should be a `ScatterModel`, 
which contains `Series` of `DataPoint`.  

Now the other question is, how do we get all that to work with the DSL?  

What I would like is something like this, where `plotModel` is an OxyPlot 
`ScatterModel`:

``` fsharp
PlotView.create [
    PlotView.model plotModel
    ]
```

The [Avalonia.funcUI docs][6] contain an example of how to do just that. So 
let's get to work, and create some bindings. In `Chart.fs`, I'll create first a 
new module, `PlotView`:

``` fsharp
[<AutoOpen>]
module PlotView =

    open Avalonia.FuncUI.Builder
    open Avalonia.FuncUI.Types

    open OxyPlot
    open OxyPlot.Avalonia

    let create (attrs: IAttr<PlotView> list): IView<PlotView> =
        ViewBuilder.Create<PlotView>(attrs)

    type PlotView with
        static member model<'T when 'T :> PlotView> (value: PlotModel) : IAttr<'T> =
            AttrBuilder<'T>.CreateProperty<PlotModel>(PlotView.ModelProperty, value, ValueNone)
```

All I need to do now is create a `PlotModel` I can feed in my view. Let's do 
this, inside the `Chart` module, where we now need to open a few more 
references:  

``` fsharp
open OxyPlot
open OxyPlot.Avalonia
open OxyPlot.Series

let createPlotModel (series: (float * float) []) =
    let points =
        series
        |> Array.map (fun (x, y) ->
            DataPoint(x, y)
            )

    let series = LineSeries()
    series.StrokeThickness <- 1.0
    series.Color <- OxyColors.Blue
    series.MarkerSize <- 2.0
    series.MarkerStroke <- OxyColors.Blue
    series.MarkerType <- MarkerType.Circle

    points
    |> Array.iter (fun x -> series.Points.Add x)

    let plotModel = PlotModel()
    plotModel.Series.Add series
    plotModel.Title <- "OxyPlot Chart"
    plotModel
```

We are about done, in our view we can replace the `TODO` text block by our 
`PlotView`:  

``` fsharp
let view (state: State) (dispatch: Msg -> unit) =
    PlotView.create [
        PlotView.model (state.Series |> createPlotModel)
        ]
```

And we are almost done. If you run the code at that point, the tab will show 
nothing. What is going on? That one took me a bit to figure out. Like any self 
respecting software engineer, I barely read the [OxyPlot Avalonia docs][7], 
which call out very clearly that you need to add some `xaml` styling to your 
application. This is easy enough, we just need to add the following line to our 
`Styles.xaml` file:

```
<Styles
    xmlns="https://github.com/avaloniaui"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <StyleInclude Source="resm:OxyPlot.Avalonia.Themes.Default.xaml?assembly=OxyPlot.Avalonia"/>

    <Style Selector="Button /template/ ContentPresenter">
        <Setter Property="CornerRadius" Value="5" />
    </Style>
    // omitted
```

`dotnet run`, and now we get this:

![Default Avalonia MVU app running]({{ site.url }}/assets/2023-05-29/avalonia-oxyplot-chart.png)

As a final touch, let's add a button to that page, which will regenerate a new 
chart every time we click it:  

``` fsharp
let view (state: State) (dispatch: Msg -> unit)=
    DockPanel.create [
        DockPanel.lastChildFill true
        DockPanel.children [
            Button.create [
                Button.dock Dock.Bottom
                Button.content "Generate New Chart"
                Button.onClick (fun _ -> CreateNewSeries |> dispatch)
                ]
            PlotView.create [
                PlotView.model (state.Series |> createPlotModel)
                ]
            ]
        ]
```

## Parting words

That is where I will leave it for today.  

My experience so far with Avalonia funcUI has been very pleasant. Based on what 
I have seen so far, I will definitely keep investigating. I love the Elmish / 
MVU UI model, and it was pretty easy to go from what I knew, Elmish with Fable, 
to Avalonia.  

I really wanted to check how difficult it would be to wrap an existing library 
in the DSL, and it was not too complicated overall, the docs provide plenty of 
hints. One interesting difficulty was that most of the docs presume users want 
to use MVVM with C#, and as a result, it required looking at documentation that 
also involved some XAML, something I had not looked at in a long, long time :)

Anyways, I had a fun times with this! And hopefully you found something useful 
in this post.  

Big shout-out to [Josua Jäger](https://mastodon.social/@josua_jaeger), 
[Jordan Marr](https://mastodon.sdf.org/@jmarr), 
[SleepyFran](https://fosstodon.org/@sleepyfrans) and 
[Angel Munoz](https://misskey.cloud/@angelmunoz) for the really nice work on 
this library, and the samples, which were super helpful in getting started!  

If you have comments or questions, hit me up on [Mastodon][5]!

> You can find the [full code here on GitHub][8]

[1]: https://www.avaloniaui.net/
[2]: https://avaloniacommunity.github.io/Avalonia.FuncUI.Docs/
[3]: https://oxyplot.github.io/
[4]: https://github.com/oxyplot/oxyplot-avalonia/tree/master/Source/Examples/Avalonia/AvaloniaExamples/Examples/
[5]: https://github.com/oxyplot/oxyplot-avalonia/blob/master/Source/Examples/Avalonia/AvaloniaExamples/Examples/ScatterDemo/MainWindow.xaml.cs
[6]: https://avaloniacommunity.github.io/Avalonia.FuncUI.Docs/guides/Bindings.html
[7]: https://github.com/oxyplot/oxyplot-avalonia
[8]: https://github.com/mathias-brandewinder/Exploring-Avalonia-Elmish/tree/f73a15550b442e4f36c53bfd5aa6e3b4255d3cc6
[9]: https://hachyderm.io/@brandewinder
