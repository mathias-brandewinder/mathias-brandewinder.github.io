---
layout: post
title: How dense is the product of Sparse Matrices?
tags:
- Matrix
- Sparse
- Simulation
- F#
- Math
- Algebra
---

This post is to be filed in the "useless but fun" category. A friend of mine was doing some Hadoopy stuff a few days ago, experimenting with rather large sparse matrices and their products. Long story short, we ended up wondering how sparse the product of 2 sparse matrices should be.

A [sparse matrix](http://en.wikipedia.org/wiki/Sparse_matrix) is a matrix which is primarily filled with zeros. The [product of two matrices](http://en.wikipedia.org/wiki/Matrix_multiplication#Matrix_product_.28two_matrices.29) involves computing the dot product of each row of the first one, with each column of the second one. There is clearly a relationship between how dense the two matrices are, and how dense the result should be. As an obvious illustration, if we consider 2 matrices populated only with zeroes - as sparse as it gets - their product is obviously 0. Conversely, two matrices populated only with ones - as dense as it gets - will result in a "completely dense" matrix. But... what happens in between?

Should I expect the product of 2 sparse matrices to be more, or less dense than the original matrices? And does it depend on how large the matrices are? What would be your guess?

<!--more-->

Because I am lazy, I figured I would let the computer do some work for me, and run some simulations. Plus, this was the excuse I needed to finally play with Matrices in F#.

I'll define the density of a Matrix as the proportion of its elements that are non-zero. After referencing the F# PowerPack, we write the following function:

``` fsharp
#r "FSharp.PowerPack.dll"
open System

let density (M: Matrix<float>) =
    let elements = M.NumRows * M.NumCols |> (float)
    let nonZero =
        M
        |> Matrix.map (fun e -> 
            if e = 0.0 then 0.0 else 1.0)
        |> Matrix.sum
    nonZero / elements

``` 

We count all the elements of the matrix, all the non-zero elements, and divide.
Does this work? Let's check:

``` fsharp
let dense = matrix [ [ 42.0; 0.0  ]; 
                     [-1.0;  123.0] ]
let sparse = matrix [ [ 0.0; 1.0 ]; 
                      [ 0.0; 0.0 ] ]
printfn "Dense matrix: %f" (density dense)
printfn "Sparse matrix: %f" (density sparse)

``` 

Running this in fsi produces the following:
``` fsharp
Dense matrix: 0.750000
Sparse matrix: 0.250000

``` 

This is what we expect - the dense matrix contains 3 non-zero entries out of 4 (75% of entries), whereas the sparse example contains 25% of non-zero entries. We are in business.

To keep things simple, let's look at square matrices, and perform the following experiment: generate multiple random matrices with a given density, multiply them, and compute the density of the result.
Here is what I came up with:

``` fsharp
let rng = new System.Random()

let create n density =
    Matrix.create n n 0.0
    |> Matrix.map (fun e -> 
        if rng.NextDouble() > density 
        then 0.0 
        else 1.0)

let simulation n d r =
    Seq.initInfinite (fun index ->
        let m1 = create n d
        let m2 = create n d
        density (m1 * m2))
    |> Seq.take r
    |> Seq.average

``` 

We instantiate one `Random` - the default .NET Random Number Generator - which we'll reuse throughout, to avoid the classic [non-random random](http://stackoverflow.com/questions/767999/random-number-generator-only-generating-one-random-number) issue. The create function returns a n x n matrix, which will have on average the requested density; it is initially populated with 0, and each entry is randomly "replaced" by a 1, with a probability based on the density.

And we are now ready to run simulations. The parameters n, d and r correspond to the size of the matrix, the density, and the number of runs that will be performed. We initialize an infinite sequence, where each step creates 2 random matrices, multiplies them and returns the density of the result; we take r elements of that sequence, average it out, and voila! We have a quick-and-dirty simulation.

So how do things look? Let's try this for densities increasing from 0% to 50%, by 5% increments:

``` fsharp
for density in 0.0 .. 0.05 .. 0.5 do
    simulation 10 density 1000
    |> printfn "Density %f -> Result is %f" density

``` 

The moment of truth  -  here is the result:

``` fsharp
Density 0.000000 -> Result is 0.000000
Density 0.050000 -> Result is 0.024850
Density 0.100000 -> Result is 0.095100
Density 0.150000 -> Result is 0.200120
Density 0.200000 -> Result is 0.336880
Density 0.250000 -> Result is 0.471450
Density 0.300000 -> Result is 0.612040
Density 0.350000 -> Result is 0.724430
Density 0.400000 -> Result is 0.827680
Density 0.450000 -> Result is 0.897720
Density 0.500000 -> Result is 0.945310
val it : unit = ()

``` 

Reassuringly, the density of the product is increasing with the density of its elements. What's interesting though is that the answer to our question isn't clear cut: for very sparse matrices, the product is even more sparse, but as density increases, past a certain limit, the product becomes denser.

How about the size of the matrix? Easy enough:

``` fsharp
for size in 5 .. 5 .. 50 do
    simulation size 0.1 1000
    |> printfn "Size %i -> Result is %f" size

``` 

... which produces the following:

``` fsharp
Size 5 -> Result is 0.049320
Size 10 -> Result is 0.095880
Size 15 -> Result is 0.141333
Size 20 -> Result is 0.182195
Size 25 -> Result is 0.222949
Size 30 -> Result is 0.260047
Size 35 -> Result is 0.296136
Size 40 -> Result is 0.331687
Size 45 -> Result is 0.362050
Size 50 -> Result is 0.396066
val it : unit = ()

``` 

Visibly, the size of the matrices does have an impact on the product density: the larger the matrix, the denser the product.

So what? Well, a few things. First, with F# and the interactive window, it took me about 15 minutes to get this done, including reading this [post on linear algebra in F#](http://fdatamining.blogspot.com/2010/03/matrix-and-linear-algebra-in-f-part-i-f.html). The more I use the REPL, the more I love it, it's just an incredible tool for exploration. Then, we got some interesting results - but also more questions: we established that size matters (larger matrices product are denser than smaller ones), and the product density looks like a S-shaped function of the density of the inputs, with an inflexion point. This is one of the drawbacks of numeric methods - on the one hand, for very cheap we gained a sense for what is going on, on the other hand, this is rather useless in figuring out how to relate formally the size and density of the matrices, with the density of the product - this would be a job better done with paper, pencil, and some effort.

That effort is beyond what I am prepared to invest in this question, so I'll leave it at that. However, if you know anything about this, I would love to hear about it - I confess I was particularly intrigued by the S-shape relationship between the input and output density, hopefully I can let that one go.

For convenience, here is the full script code:

``` fsharp
#r "FSharp.PowerPack.dll"

let density (M: Matrix<float>) =
    let elements = M.NumRows * M.NumCols |> (float)
    let nonZero =
        M
        |> Matrix.map (fun e -> 
            if e = 0.0 then 0.0 else 1.0)
        |> Matrix.sum
    nonZero / elements
  
let dense = matrix [ [ 42.0; 0.0  ]; 
                     [-1.0;  123.0] ]
let sparse = matrix [ [ 0.0; 1.0 ]; 
                      [ 0.0; 0.0 ] ]

printfn "Dense matrix: %f" (density dense)
printfn "Sparse matrix: %f" (density sparse)

let rng = new System.Random()

let create n density =
    Matrix.create n n 0.0
    |> Matrix.map (fun e -> 
        if rng.NextDouble() > density 
        then 0.0 
        else 1.0)

// Run r times the product of 2 matrices
// of density d, and size n, and compute
// the average density
let simulation n d r =
    Seq.initInfinite (fun index ->
        let m1 = create n d
        let m2 = create n d
        density (m1 * m2))
    |> Seq.take r
    |> Seq.average

// Relationship between density and density
for density in 0.0 .. 0.05 .. 0.5 do
    simulation 10 density 1000
    |> printfn "Density %f -> Result is %f" density

// Relationship between size and density
for size in 5 .. 5 .. 50 do
    simulation size 0.1 1000
    |> printfn "Size %i -> Result is %f" size

``` 
