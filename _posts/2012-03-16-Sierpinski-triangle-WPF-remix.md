---
layout: post
title: Sierpinski triangle, WPF remix
tags:
- WPF
- Sierpinski
- Triangle
- Geometry
- Fun
- Sequence
- F#
- Fractal
---

In my last post, I looked into drawing a [Sierpinski triangle using F# and WinForms]({{ site.url }}/2012/03/11/Sierpinski-triangle/), and noted that the rendering wasn’t too smooth – so I converted it to WPF, to see if the result would be any better, and it is. In the process, I discovered John Liao’s blog, which contains some [F# + WPF code examples](http://jyliao.blogspot.com/2007_10_01_archive.html) I found very useful. I posted the code below, as well as on [FsSnip](http://fssnip.net/ba). The differences with the WinForms code are minimal, I’ll let the interested reader figure that part out!  

One thing I noticed is that the starting point of the Sierpinski sequence is a single triangle – but nothing would prevent a curious user to initialize the sequence with multiple triangles. And while at it, why not use WPF Brush opacity to create semi-transparent triangles, and see how their superposition looks like?  

We just change the `Brush` `Color` and `Opacity`, and add a second triangle to the root sequence…  

``` fsharp
let brush = new SolidColorBrush(Colors.DarkBlue)
brush.Opacity <- 0.6
let renderTriangle = render canvas brush

let triangle = 
    let p1 = { X = 190.0; Y = 170.0 }
    let p2 = { X = 410.0; Y = 210.0}
    let p3 = { X = 220.0; Y = 360.0}
    { A = p1; B = p2; C = p3 }

let triangle2 =
    let p1 = { X = 290.0; Y = 170.0 }
    let p2 = { X = 510.0; Y = 210.0}
    let p3 = { X = 320.0; Y = 360.0}
    { A = p1; B = p2; C = p3 }

let root = seq { yield triangle; yield triangle2 }
``` 

… and here we go:

![Sierpinski-superposition]({{ site.url }}/assets/2012-03-16-Sierpinski-superposition_thumb.png)

<!--more-->

Granted, it’s pretty useless, but I thought it looked rather nice!

As an aside, here is something I noted when working in F#: I often end up looking at the code, thinking “can I use this to do something I didn’t think about when I wrote it”? In C#, I tend to think in terms of restrictions: write Components, with a “containment” approach – figure out what the component should do, and enforce safety by constraining the inputs/outputs via an interface. By contrast, because of type inference and the fact that a function doesn’t require an “owner” (it is typically not a member of a class), I find myself less “mentally conditioned”, and instead of a world of IWidgets and ISprockets, I simply see functions that transform elements, and wonder what else they could apply to.

The case we saw here was trivial, but pretty much from the moment I wrote that code, I have been mulling over other extensions. What is the transform function really doing, and what other functions could I replace it with? generateFrom is simply permuting the triangle corners and applying the same transformation – could I generalize this to an arbitrary sequence and write Sierpinski Polygons? Could I even apply it to something that has nothing to do with geometry?

``` fsharp
// Requires reference to 
// PresentationCore, PresentationFramework, 
// System.Windows.Presentation, System.Xaml, WindowsBase

open System
open System.Windows
open System.Windows.Media
open System.Windows.Shapes
open System.Windows.Controls

type Point = { X:float; Y:float }
type Triangle = { A:Point; B:Point; C:Point }

let transform (p1, p2, p3) =
   let x1 = p1.X + 0.5 * (p2.X - p1.X) + 0.5 * (p3.X - p1.X)
   let y1 = p1.Y + 0.5 * (p2.Y - p1.Y) + 0.5 * (p3.Y - p1.Y)
   let x2 = p1.X + 1.0 * (p2.X - p1.X) + 0.5 * (p3.X - p1.X)
   let y2 = p1.Y + 1.0 * (p2.Y - p1.Y) + 0.5 * (p3.Y - p1.Y)
   let x3 = p1.X + 0.5 * (p2.X - p1.X) + 1.0 * (p3.X - p1.X)
   let y3 = p1.Y + 0.5 * (p2.Y - p1.Y) + 1.0 * (p3.Y - p1.Y)
   { A = { X = x1; Y = y1 }; B = { X = x2; Y = y2 }; C= { X = x3; Y = y3 }}

let generateFrom triangle = seq {
      yield transform (triangle.A, triangle.B, triangle.C)
      yield transform (triangle.B, triangle.C, triangle.A)
      yield transform (triangle.C, triangle.A, triangle.B)
   }

let nextGeneration triangles =
   Seq.collect generateFrom triangles 
      
let render (target:Canvas) (brush:Brush) triangle =
   let points = new PointCollection()
   points.Add(new System.Windows.Point(triangle.A.X, triangle.A.Y))
   points.Add(new System.Windows.Point(triangle.B.X, triangle.B.Y))
   points.Add(new System.Windows.Point(triangle.C.X, triangle.C.Y))
   let polygon = new Polygon()
   polygon.Points <- points
   polygon.Fill <- brush
   target.Children.Add(polygon) |> ignore
   
let win = new Window()
let canvas = new Canvas()
canvas.Background <- Brushes.White
let brush = new SolidColorBrush(Colors.Black)
brush.Opacity <- 1.0
let renderTriangle = render canvas brush

let triangle = 
    let p1 = { X = 190.0; Y = 170.0 }
    let p2 = { X = 410.0; Y = 210.0}
    let p3 = { X = 220.0; Y = 360.0}
    { A = p1; B = p2; C = p3 }

let root = seq { yield triangle }
let generations = 
   Seq.unfold (fun state -> Some(state, (nextGeneration state))) root
   |> Seq.take 7
Seq.iter (fun gen -> Seq.iter renderTriangle gen) generations

win.Content <- canvas
win.Show()

[<STAThread()>]
do 
   let app =  new Application() in
   app.Run() |> ignore
``` 
