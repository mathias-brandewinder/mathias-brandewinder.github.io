---
layout: post
title: Maintainable Avalonia FuncUI screen layouts with DockPanels and Borders
tags:
- F#
- User-Interface
- Avalonia
- Elmish
---

I have been using [Avalonia FuncUI][1] quite a bit lately, to develop Windows 
desktop clients for 2 applications. The UI for these applications is not 
particularly fancy: select items using listboxes, edit the selected item, and 
save it, that kind of thing.  

As these applications grew, the screens grew in complexity, and I realized that 
I was struggling a bit when I wanted to re-arrange their layout. The problem 
was not caused by FuncUI, but rather by how I was using controls, creating 
layouts that ended up being hard to refactor or re-arrange.  

In this post, I will go over what I ended up doing. It's not particularly 
earth shattering, but who knows - it might help someone out there avoid some of 
the pain I went through :)

<!--more-->

##  DockPanel layout

Avalonia includes multiple [controls to organize screen layout][2]. My go-to 
workhorse for screen layout is the [DockPanel][3]. A DockPanel specifies an 
area that will expand to fill its parent area, and defines how elements inside 
the dock panel area should be displayed, by specifying how they are positioned 
relative to the previous element.  

As they say, a picture is worth a thousand words. Let's illustrate with a 
quick example, with one `DockPanel` split into 5 children:  

``` fsharp
let view (state: State) (dispatch: Msg -> unit) =
    DockPanel.create [
        DockPanel.children [
            TextBlock.create [
                TextBlock.dock Dock.Left
                TextBlock.text "1: LEFT"
                TextBlock.background "Red"
                ]
            TextBlock.create [
                TextBlock.dock Dock.Top
                TextBlock.text "2: TOP"
                TextBlock.background "Yellow"
                ]
            TextBlock.create [
                TextBlock.dock Dock.Top
                TextBlock.text "3: TOP"
                TextBlock.background "Orange"
                ]
            TextBlock.create [
                TextBlock.dock Dock.Right
                TextBlock.text "4: RIGHT"
                TextBlock.background "Green"
                ]
            // last child will fill in whatever space is left
            TextBlock.create [
                TextBlock.text "5: LAST"
                ]
            ]
        ]
```

This DockPanel creates the following layout, which will most certainly not win 
any design prizes, but illustrates what is going on:  

![DockPanel example with 5 children]({{ site.url }}/assets/2025-02-05/dockpanel-example.png)

The first `TextBlock` is docked to the left of the available space. The second 
is docked to the top of the remaining space available on the right of the first 
`TextBlock`. We keep going down the list, until we reach the last child, which 
will fill all the space still available.  

What I like about the `DockPanel` is that  

- it handles dynamic screen resizing gracefully,  
- it handles dynamic scroll bars for controls with expanding contents, 
such as `ListBox`,  
- it is a pretty natural fit for layouts like item selector on the left / 
selected item editor on the right, or more generally newspaper / column style 
layouts.  

## DockPanel of Doom

So what can go wrong using `DockPanels`? If you are not careful, 
things can get out of hand quickly. As a simplistic (and ugly looking) example, 
you might end up with a screen layout along these lines:  

``` fsharp
let view (state: State) (dispatch: Msg -> unit) =
    DockPanel.create [
        DockPanel.children [
            // Left: Selection
            DockPanel.create [
                DockPanel.dock Dock.Left
                DockPanel.minWidth 150
                DockPanel.children [
                    TextBlock.create [
                        TextBlock.dock Dock.Top
                        TextBlock.text "TITLE"
                        TextBlock.background "Red"
                        ]
                    TextBlock.create [
                        TextBlock.dock Dock.Bottom
                        TextBlock.text "FOOTER"
                        TextBlock.background "Orange"
                        ]
                    ListBox.create [
                        ListBox.dataItems (
                            Array.init 20 (fun i -> $"Item {i}")
                            )
                        ]
                    ]
                ]
            // Right: Edit Selected
            TextBlock.create [
                TextBlock.dock Dock.Top
                TextBlock.text "TITLE"
                TextBlock.background "Yellow"
                ]
            TextBlock.create [
                TextBlock.dock Dock.Top
                TextBlock.text "SUBSECTION"
                TextBlock.background "Orange"
                ]
            TextBlock.create [
                TextBlock.text "MAIN EDITOR"
                ]
            ]
        ]
```

This creates a layout with a left section where perhaps we can select an item, 
and a few additional controls, and a right section with its own controls:  

![Crude app layout using DockPanel]({{ site.url }}/assets/2025-02-05/app-example.png)

This looks terrible, but this isn't the point. In its current state, it is 
already difficult to follow the overall screen organization. For instance, take 
the following element:  

``` fsharp
TextBlock.create [
    TextBlock.dock Dock.Top
    TextBlock.text "TITLE"
    TextBlock.background "Yellow"
    ]
```

It is docked to the top, but relative to what? To figure that out, you need to 
navigate all the way up to the previous child of the `DockPanel` (and possibly 
its predecessors):  

```
DockPanel.create [
    DockPanel.dock Dock.Left
    // omitted
    ]
TextBlock.create [
    TextBlock.dock Dock.Top
    // omitted
    ]
```

This is a lot of mental gymnastics just to figure out where a control goes. It 
does not help that the previous child, the inner `DockPanel`, contains many 
elements. We have to navigate through a lot of code to find the relevant 
docking information. The overall layout intent is not made obvious at all.  

## Refactoring

As I see it, there are 2 separate problems at play:  

- Docking multiple elements, in particular using different docking directions, 
can be difficult to follow, because the behavior of any element depends on the 
entire chain of previous elements within the `DockPanel`.  
- The more code there is inline, the harder it gets to see the relevant 
information about the structure.  

The second one sounds easy: if there is too much code inline, extract it. In 
our case, we could for instance extract the whole left section into its own 
view:  

``` fsharp
module Selection =

    let view (state: State) (dispatch: Msg -> unit) =
        DockPanel.create [
            DockPanel.dock Dock.Left
            DockPanel.minWidth 150
            DockPanel.children [
                TextBlock.create [
                    TextBlock.dock Dock.Top
                    TextBlock.text "TITLE"
                    TextBlock.background "Red"
                    ]
                TextBlock.create [
                    TextBlock.dock Dock.Bottom
                    TextBlock.text "FOOTER"
                    TextBlock.background "Orange"
                    ]
                ListBox.create [
                    ListBox.dataItems (Array.init 20 (fun i -> $"Item {i}"))
                    ]
                ]
            ]
```

This allows us to refactor the `view` like so:  

``` fsharp
let view (state: State) (dispatch: Msg -> unit) =
    DockPanel.create [
        DockPanel.children [
            // Left: Selection
            Selection.view state dispatch

            // Right: Edit Selected
            TextBlock.create [
                TextBlock.dock Dock.Top
                TextBlock.text "TITLE"
                TextBlock.background "Yellow"
                ]
            // omitted
            ]
        ]
```

While the `view` is now de-cluttered, this is arguably even worse than before. 
In the main `view`, all we see is a call to `Selection.view`, with no 
information about how it is docked. If we want to know how the `TextBlock` will 
be positioned, we need to navigate even further away in the code than before, 
inside the `Selection.view` function.  

The problem here is that `Selection.view` should not contain information 
about docking - it is not its responsibility to decide where it should appear 
in the containing element! So what can we do here?  

If the `Selection.view` is not responsible for how it is docked, that 
responsibility should be moved up to its containing element. Let's refactor, 
adding a bit of indirection:  

``` fsharp
module Selection =

    let view (state: State) (dispatch: Msg -> unit) =
        DockPanel.create [
            DockPanel.children [
                TextBlock.create [
                    TextBlock.dock Dock.Top
                    TextBlock.text "TITLE"
                    TextBlock.background "Red"
                    ]
                // omitted
                ]
            ]

let view (state: State) (dispatch: Msg -> unit) =
    DockPanel.create [
        DockPanel.children [
            // Left: Selection
            Border.create [
                Border.dock Dock.Left
                Border.minWidth 150
                Border.child (
                    Selection.view state dispatch
                    )
                ]

            // Right: Edit Selected
            TextBlock.create [
                TextBlock.dock Dock.Top
                TextBlock.text "TITLE"
                TextBlock.background "Yellow"
                ]
            // omitted
        ]
```

Instead of directly using `Selection.view`, we introduce a `Border` in the 
parent `DockPanel`, which carries the relevant docking information, as well as 
anything else that pertains to its layout in the parent `DockPanel`, like 
`minWidth` in our example.  

The next refactoring involves doing something similar for the right 
section. I won't go into the details, and leave it as the proverbial 
"exercise to the reader". Once completed, the result would look along these 
lines, which I believe is markedly better than the original version:  

``` fsharp
let view (state: State) (dispatch: Msg -> unit) =
    DockPanel.create [
        DockPanel.children [
            // Left: Selection
            Border.create [
                Border.dock Dock.Left
                Border.minWidth 150
                Border.child (
                    Selection.view state dispatch
                    )
                ]
            // Right: Edit Selected
            Border.create [
                Border.child (
                    Editor.view state dispatch
                    )
                ]
            ]
        ]
```

## Parting thoughts

The approach I described is not particularly complicated or fancy, but I wanted 
to document it, for myself and possibly others. While I realized relatively 
quickly that my UI was devolving into an un-manageable mess of `DockPanels`, it 
took me longer than it should have to figure out what was wrong about it, and 
how to resolve the issue.  

The key insight was that when extracting view code, I needed to remove all 
information pertaining to its layout _in the containing control_.  

I knew that having controls dictating their layout behaving in their container 
was off, but realizing that I needed to insert a control in-between to carry 
that information took me a while. It might simply be that adding more controls 
did not seem like an obvious path to simplifying an already over-complicated 
UI!  

The result is a pretty simple pattern:  

- use a `DockPanel` to define a few broad areas,  
- wrap each area in a `Border` containing the corresponding controls, and 
the correspondong layout information.  

The `Border` control works pretty well for our purposes. 
First, we are defining broad layout areas, so there is a good chance that if we 
want to use actual visual borders to delineate organization, this is where we 
will need them. Then, unlike most other layout controls, a `Border` has a 
single child. This will enforce that its content have to be a single, self 
contained control, and leads to thinking in groups of related controls, rather 
than individual disconnected ones. Finally, this leads to much easier UI 
reorganization: reorganizing the layout within a `DockPanel` is straightforward 
because that is what the `Borders` highlight, and moving the controls around or 
even re-using them in different spots in the application is easy because they 
are self-contained and layout agnostic.  

This is what I got for today!  

[1]: https://github.com/fsprojects/Avalonia.FuncUI
[2]: https://docs.avaloniaui.net/docs/basics/user-interface/building-layouts/
[3]: https://docs.avaloniaui.net/docs/basics/user-interface/building-layouts/panels-overview#dockpanel