---
layout: post
title: Sierpinski triangle
tags:
- Sierpinski
- Triangle
- F#
- Geometry
- Fun
- Functional
- Sequence
- Fractal
---

I am midway through the highly-recommended “[Real-world functional programming](http://www.amazon.com/Real-World-Functional-Programming-Examples/dp/1933988924): with examples in C# and F#”, which inspired me to play with graphics using F# and WinForms (hadn’t touched that one in a long, long time), and I figured it would be fun to try generating a Sierpinski Triangle.  

The [Sierpinski Triangle](http://en.wikipedia.org/wiki/Sierpinski_triangle) is generated starting from an initial triangle. 3 half-size copies of the triangle are created and placed outside of the original triangle, each of them having a corner “touching” the middle of one side of the triangle.   

![Sierpinski-original]({{ site.url }}/assets/2012-03-11-Sierpinski-original_thumb.png)  

<!--more-->

That procedure is then repeated for each of the 3 new triangles, creating more and more smaller triangles, which progressively fill in an enclosing triangular shape. The figure below uses the same starting point, stopped after 6 “generations”:  

![Sierpinski-6]({{ site.url }}/assets/2012-03-11-Sierpinski-6_thumb.png)

The Sierpinski Triangle is an example of a [fractal](http://en.wikipedia.org/wiki/Fractal) figure, displaying [self-similarity](http://en.wikipedia.org/wiki/Self-similarity): if we were to run the procedure ad infinitum, each part of the Triangle would look like the whole “triangle” itself.  

So how could we go about creating this in F#?  

I figured this would be a good case for Seq.unfold: given a state (the triangles that have been produced for generation n), and an initial state to start from, provide a function which defines how the next generation of triangles should be produced, defining a “virtual” infinite sequence of triangles – and then use Seq.take to request the number of generations to be plotted.  

Here is the entire code I used; you’ll need to add a reference to `System.Windows.Forms` and `System.Drawings` for it to run:  

```  fsharp
open System
open System.Drawing
open System.Windows.Forms

type Point = { X:float32; Y:float32 }
type Triangle = { A:Point; B:Point; C:Point }

let transform (p1, p2, p3) =
   let x1 = p1.X + 0.5f * (p2.X - p1.X) + 0.5f * (p3.X - p1.X)
   let y1 = p1.Y + 0.5f * (p2.Y - p1.Y) + 0.5f * (p3.Y - p1.Y)
   let x2 = p1.X + 1.0f * (p2.X - p1.X) + 0.5f * (p3.X - p1.X)
   let y2 = p1.Y + 1.0f * (p2.Y - p1.Y) + 0.5f * (p3.Y - p1.Y)
   let x3 = p1.X + 0.5f * (p2.X - p1.X) + 1.0f * (p3.X - p1.X)
   let y3 = p1.Y + 0.5f * (p2.Y - p1.Y) + 1.0f * (p3.Y - p1.Y)
   { A = { X = x1; Y = y1 }; B = { X = x2; Y = y2 }; C= { X = x3; Y = y3 }}

let generateFrom triangle = seq {
      yield transform (triangle.A, triangle.B, triangle.C)
      yield transform (triangle.B, triangle.C, triangle.A)
      yield transform (triangle.C, triangle.A, triangle.B)
   }

let nextGeneration triangles =
   Seq.collect generateFrom triangles 
      
let render (target:Graphics) (brush:Brush) triangle =
   let p1 = new PointF(triangle.A.X, triangle.A.Y)
   let p2 = new PointF(triangle.B.X, triangle.B.Y)
   let p3 = new PointF(triangle.C.X, triangle.C.Y)
   let points = List.toArray <| [ p1; p2; p3 ]
   target.FillPolygon(brush, points)
   
let form = new Form(Width=500, Height=500)
let box = new PictureBox(BackColor=Color.White, Dock=DockStyle.Fill)
let image = new Bitmap(500, 500)
let graphics = Graphics.FromImage(image)
let brush = new SolidBrush(Color.FromArgb(0,0,0))
let renderTriangle = render graphics brush

let p1 = { X = 190.0f; Y = 170.0f }
let p2 = { X = 410.0f; Y = 210.0f}
let p3 = { X = 220.0f; Y = 360.0f}
let triangle = { A = p1; B = p2; C = p3 }

let root = seq { yield triangle }
let generations = 
   Seq.unfold (fun state -> Some(state, (nextGeneration state))) root
   |> Seq.take 7
Seq.iter (fun gen -> Seq.iter renderTriangle gen) generations

box.Image <- image
form.Controls.Add(box)

[<STAThread>]
do
   Application.Run(form)
``` 

A few comments on the code. I first define 2 types, a `Point` with 2 float32 coordinates (float32 chosen because that’s what [System.Drawing.PointF](http://msdn.microsoft.com/en-us/library/system.drawing.pointf.aspx) takes), and a `Triangle` defined by 3 Points. The transform function is pretty ugly, and can certainly be cleaned up / prettified. It takes a tuple of 3 Points, and returns the corresponding transformed triangle, shrunk by half and located at the middle of the p1, p2 edge. We can now build up on this with the nextGeneration function, which takes in a Sequence of Triangles (generation n), transforms each of them into 3 new Triangles and uses `collect` to “flatten” the result into a new Sequence, generation n+1.

The rendering code has been mostly lifted with slight modifications from Chapter 4 of Real-world functional programming. The render function retrieves the 3 points of a Triangle and create a filled Polygon, displayed on a Graphics object which we create in a form.

Running that particular example generates the following Sierpinski triangle; you can play with the coordinates of the root triangle, and the number of generations, to build your own!

As an aside, I was a bit disappointed by the quality of the graphics; beyond 7 or 8 generations, the result gets fairly blurry. I’ll probably give a shot at moving this to XAML, and see if it’s any better.

![Sierpinski-example]({{ site.url }}/assets/2012-03-11-Sierpinski-example_thumb.png)

As usual, comments, questions or criticisms are welcome!
