---
layout: post
title: Simplify data with SVD and Math.NET in F#
tags:
- Machine-Learning
- Linear-Algebra
- Math
- F#
- SVD
- Math.NET
---

{% include ml-in-action-series.html %}

My trajectory through “[Machine Learning in Action](http://www.manning.com/pharrington/)
<a href="http://www.manning.com/pharrington/">Machine Learning in Action</a>” is becoming more unpredictable as we go – this time, rather than completing our last episode on K-means clustering (we’ll get back to it later), I’ll make another jump directly to Chapter 14, which is dedicated to Singular Value Decomposition, and convert the example from Python to F#. 

The chapter illustrates how Singular Value Decomposition (or SVD in short) can be used to build a collaborative recommendation engine. We will follow the chapter pretty closely: today we will focus on the mechanics of using SVD in F# – and leave the recommendation part to our next installment. 

As usual, [the code is on GitHub](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/blob/2d3d78a95b8c88227bcea29a87b1441f55272890/MachineLearningInAction/MachineLearningInAction/Chapter14.fsx). 

Until this point, I have avoided using a Linear Algebra library, because the algorithms we discussed so far involved lightweight, row-centric operations, which didn’t warrant taking such a dependency. SVD is one of these cases where using an established library is a good idea, if only because implementing it yourself would not be trivial. So let’s create a new script file (Chapter14.fsx), add a reference to [Math.NET Numerics for F#](http://nuget.org/packages/MathNet.Numerics.FSharp/) to our project via NuGet, and reference it in our script:

``` fsharp
#r @"..\..\MachineLearningInAction\packages\MathNet.Numerics.2.4.0\lib\net40\MathNet.Numerics.dll"
#r @"..\..\MachineLearningInAction\packages\MathNet.Numerics.FSharp.2.4.0\lib\net40\MathNet.Numerics.FSharp.dll"

open MathNet.Numerics.LinearAlgebra
open MathNet.Numerics.LinearAlgebra.Double
``` 

Now that we have our tools, let’s start working our example. Imagine that we are running a website, where our users can rate dishes, from 1 (horrendous) to 5 (delightful). Our data would look something along these lines:

``` fsharp
type Rating = { UserId: int; DishId: int; Rating: int }

// Our existing "ratings database"
let ratings = [
    { UserId = 0; DishId = 0; Rating = 2 };
    { UserId = 0; DishId = 3; Rating = 4 };
    ... omitted for brevity ...
    { UserId = 10; DishId = 8; Rating = 4 };
    { UserId = 10; DishId = 9; Rating = 5 } ]
``` 

<!--more-->

Our goal will be to provide recommendations to User for Dishes they haven’t tasted yet, based on their ratings and what other users are saying.

Our first step will be to represent this as a Matrix, where each Row is a User, each Column a Dish, and the corresponding cell is the User Rating for that Dish. Note that not every Dish has been rated by every User – we will represent missing ratings as zeroes in our matrix:

``` fsharp
let rows = 11
let cols = 11
let data = DenseMatrix(rows, cols)
ratings 
|> List.iter (fun rating -> 
       data.[rating.UserId, rating.DishId] <- (float)rating.Rating)
``` 

We initialize our 11 x 11 matrix, which creates a zero-filled matrix, and then map our user ratings to each “cell”. Because we constructed our example that way, our UserIds go from 0 to 10, and DishIds from 0 to 10, so we can map them respectively to Rows and Columns.

*Note: while this sounded like a perfect case to use a Sparse Matrix, I chose to go first with a DenseMatrix, which is more standard. I may look at whether there is a benefit to going sparse later.*

*Note: our matrix happens to be square, but this isn’t a requirement.*

*Note: I will happily follow along the book author and replace unknown ratings by zero, because it’s very convenient. I don’t fully get how this is justified, but it seems to work, so I’ll temporarily suspend disbelief and play along.*

At that point, we have our data matrix ready. Before going any further, let’s write a quick utility function, to “pretty-render” matrices:

``` fsharp
let printNumber v = 
    if v < 0. 
    then printf "%.2f " v 
    else printf " %.2f " v
// Display a Matrix in a "pretty" format
let pretty matrix = 
    Matrix.iteri (fun row col value ->
        if col = 0 then printfn "" else ignore ()
        printNumber value) matrix
    printfn ""
``` 

We iterate over each row and column, start a newline every time we hit column 0, and print every value, nicely formatted with 2 digits after the decimal.

In passing, note the F#-friendly `Matrix.iteri` syntax – the [good people at Math.NET](https://twitter.com/MathDotNet) do support F#, and `MathNet.Numerics.FSharp.dll` contains handy helpers, which allow for a much more functional usage of the library. Thanks, guys!

Let’s see how our data matrix looks like:

``` fsharp
printfn "Original data matrix"
pretty data
``` 

… which produces the following output in FSI:

```
Original data matrix
2.00  0.00  0.00  4.00  4.00  0.00  0.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  5.00 
4.00  0.00  0.00  0.00  0.00  0.00  0.00  1.00  0.00  0.00  0.00 
3.00  3.00  4.00  0.00  3.00  0.00  0.00  2.00  2.00  0.00  0.00 
5.00  5.00  5.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  0.00  0.00  0.00  5.00  0.00  0.00  5.00  0.00 
4.00  0.00  4.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  5.00 
0.00  0.00  0.00  0.00  0.00  4.00  0.00  0.00  0.00  0.00  4.00 
0.00  0.00  0.00  0.00  0.00  0.00  5.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  3.00  0.00  0.00  0.00  0.00  4.00  5.00  0.00 
1.00  1.00  2.00  1.00  1.00  2.00  1.00  0.00  4.00  5.00  0.00  
```

We seem to be in business.

Now is the moment when I wave my hands in the air, and say “let’s run a Singular Value Decomposition”. I won’t even attempt to explain how or why it works, because this would be way beyond the scope of a single post (and to be perfectly honest, because my linear algebra is pretty rusty). Rather, I’ll do it, and I hope that the results will convey some of the magic that it happening:

``` fsharp
let svd = data.Svd(true)
let U, sigmas, Vt = svd.U(), svd.S(), svd.VT()
let S = DiagonalMatrix(rows, cols, sigmas.ToArray())
``` 

The Singular Value Decomposition breaks a matrix into the product of 3 matrices U, Sigma and V<sup>T</sup>. We call the SVD procedure on our data matrix, and retrieve these 3 elements from the result: U and V<sup>T</sup>, which are both already in matrix form, and sigma, a vector listing the Singular Values, from which we recompose the expected S diagonal matrix, using the vector elements to populate the diagonal.

Great. Now instead of one matrix, we have three – what’s so special about U, S and VT?

First, we have by definition of the SVD, **`data = U x S x Vt`**. Let’s check that this holds:

``` fsharp
let reconstructed = U * S * Vt
pretty reconstructed
``` 

… which produces the following output in FSI:

```
2.00  0.00  0.00  4.00  4.00  0.00  0.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  5.00 
4.00  0.00  0.00  0.00  0.00  0.00  0.00  1.00  0.00  0.00  0.00 
3.00  3.00  4.00  0.00  3.00  0.00  0.00  2.00  2.00  0.00  0.00 
5.00  5.00  5.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  0.00  0.00  0.00  5.00  0.00  0.00  5.00  0.00 
4.00  0.00  4.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  5.00 
0.00  0.00  0.00  0.00  0.00  4.00  0.00  0.00  0.00  0.00  4.00 
0.00  0.00  0.00  0.00  0.00  0.00  5.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  3.00  0.00  0.00  0.00  0.00  4.00  5.00  0.00 
1.00  1.00  2.00  1.00  1.00  2.00  1.00  0.00  4.00  5.00  0.00
``` 

<em>Note: I don’t quite understand what’s happening, but my pretty function produces some unexpected misalignments. If someone figures out what I did wrong, you would have my gratitude!</em>

This matrix looks identical to our original data matrix. Success!

However, all we did so far was replacing one matrix by three, which doesn’t seem like progress. A hint at what is going on is provided by the S matrix itself:

``` fsharp
pretty S
``` 

```
13.10  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00 
0.00  10.54  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00 
0.00  0.00  8.18  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  6.89  0.00  0.00  0.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  0.00  5.59  0.00  0.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  0.00  0.00  4.11  0.00  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  0.00  0.00  0.00  3.30  0.00  0.00  0.00  0.00 
0.00  0.00  0.00  0.00  0.00  0.00  0.00  2.78  0.00  0.00  0.00 
0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  2.03  0.00  0.00 
0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  1.89  0.00 
0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.63 

val it : unit = () 
```

Note that the values on the diagonal are in decreasing order. One way to describe what is going on is that SVD reorganizes the matrix data in a more efficient manner, [extracting “concepts/categories”](http://en.wikipedia.org/wiki/Latent_semantic_indexing#Rank-Reduced_Singular_Value_Decomposition) from the matrix, and, paraphrasing the Wikipedia article on Latent Semantic Indexing, U can be seen as a User-to-Category matrix and Vt as a Category-to-Dish matrix – and the Singular Values in between represent the “importance” of each extracted categories.

Let’s see if we can illustrate this. First, let’s compute the “user-to-category” matrix, U x S:

``` fsharp
let userToCategory = U * S |> pretty
``` 

We get the following, where rows map to users, and columns to the extracted “categories”:

```
-2.43 -0.32 -1.15 -2.48 -4.66  0.21 -0.19  0.79 -0.21 -0.20  0.07 
-1.10  0.98  4.39 -0.55 -0.36 -0.37  1.25  0.23 -0.06  1.13  0.26 
-2.31  1.16 -0.51  0.32 -0.88 -1.56 -2.10 -1.36  0.13  0.66  0.07 
-6.13  1.45 -2.17 -0.31 -0.27  1.62  1.26 -1.37 -0.30  0.39 -0.18 
-7.22  3.18 -2.23  1.71  1.32 -0.01 -0.51  1.65  0.21  0.30  0.04 
-1.94 -5.42  1.05  3.68 -0.75 -0.45 -0.11  0.27 -1.16  0.18 -0.12 
-5.49  2.97  3.66  0.28 -0.23 -1.72  0.53 -0.36  0.02 -1.04 -0.09 
-1.23  0.51  4.63 -0.97  0.18  2.30 -1.54  0.25  0.04  0.09 -0.20 
-0.50 -1.86  0.64  3.81 -1.87  0.84  0.33 -0.26  1.40 -0.08  0.04 
-2.87 -5.58 -0.04 -2.73  0.70 -1.31  0.29  0.33  0.78  0.40 -0.27 
-5.05 -4.84  0.10 -1.20  1.45  0.88 -0.37 -0.44 -0.04 -0.54  0.39 

val userToCategory : unit = ()
```

This suggests that users with Id 3, 4 and 6 (highlighted values in rows 4, 5 and 7) are strongly tied to Category 1 (the first column). Looking back at the original data matrix, we can see that all 3 gave high ratings to the first and third dish, and two of them rated the second dish high as well. So we would expect Category 1 to map to “liked dish 1, 2 and 3”.

Let’s now compute the “category-to-dish” matrix S x Vt:

``` fsharp
let categoryToDish = S * Vt |> pretty
``` 

We get the following result:

```
-7.30 -4.55 -7.08 -1.78 -2.53 -1.15 -1.32 -1.11 -3.35 -3.76 -2.89 
 2.97  1.46  2.27 -2.17 -0.17 -0.72 -3.91  0.39 -3.68 -7.51  2.07 
 -0.89 -2.15 -0.61 -0.57 -1.35  2.29  1.04 -0.59 -0.51  0.67  7.19 
 0.56  0.93  0.87 -2.80 -1.75 -0.91  5.26 -0.04 -2.37 -0.19 -0.76 
 -1.16  1.30  1.34 -2.70 -3.22  0.65 -2.09 -0.25  1.44  1.25 -0.40 
 -1.71  1.38  0.32 -0.53  1.60  2.67  0.69  0.41  0.38 -1.06 -0.30 
 -1.76  0.26  1.17 -0.08  0.80 -2.10  0.22  0.13  0.67 -0.29  0.83 
 -0.58  1.33  0.16  1.34 -0.50  0.04 -0.14 -1.47 -1.13  0.29  0.13 
  0.12  0.05 -0.09  0.71 -0.88  0.04  0.57 -0.23  1.16 -1.04 -0.02 
   0.12  1.13 -1.14 -0.08 -0.08 -0.39 -0.03  0.77  0.12  0.10  0.43 
    0.12  0.06 -0.18 -0.26  0.20 -0.06  0.01 -0.45  0.17 -0.02  0.03 

val categoryToDish : unit = ()
```

Sure enough, the first row, which maps to our first Category, shows 3 high amplitude values (highlighted), in the first three columns. Category 1 could be described as “like Dish 1 and Dish 3, and also to some extent Dish 2”.

To summarize, what the SVD gave us is a reorganization of our data, restating the original matrix in terms of “Categories”, and transforming the feature space into a more “informative” one, mapping users to dishes through categories which combine features and have an associated strength, represented by the singular values.

One way this can be exploited is to simplify data: the larger Singular Values are responsible for most of the shape of our matrix (the “important” categories), so we could drop the smaller ones without losing too much information.

Let’s see this in action – suppose we kept only a subset of the singular values, and dropped the smallest ones. We could simply set the diagonal value in the S matrix to 0, but, as the net effect of multiplying the matrices together will be to produce rows and columns of zeroes where we have a 0 value in the diagonal, we might as well drop these rows and columns from S altogether, and to maintain dimension consistency, drop the corresponding rows/columns from U and Vt. That way, we work with smaller matrices – winning!

The modification can be done like this – we drop the last columns of U, the last rows and columns of S, and the last rows of Vt, and we are set:

``` fsharp
let subset = 10
let U' = U.SubMatrix(0, U.RowCount, 0, subset)
let S' = S.SubMatrix(0, subset, 0, subset)
let Vt' = Vt.SubMatrix(0, subset, 0, Vt.ColumnCount)
``` 

Keeping the 10 largest out of 11 values, we can now approximate data as U’ x S’ x Vt’. How does that look?

``` fsharp
U' * S' * Vt' |> pretty
``` 

The results looks very similar to our original data matrix:

```
1.99 -0.01  0.02  4.03  3.98  0.01  0.00  0.05 -0.02  0.00 0.00 
-0.05 -0.02  0.07  0.10 -0.08  0.03  0.00  0.18 -0.07  0.01  4.99 
3.99 -0.01  0.02  0.03 -0.02  0.01  0.00  1.05 -0.02  0.00  0.00 
3.03  3.02  3.95 -0.07  3.06 -0.02  0.00  1.87  2.05 -0.01  0.01 
4.99  5.00  5.01  0.01 -0.01  0.00  0.00  0.03 -0.01  0.00  0.00 
0.02  0.01 -0.03 -0.05  0.04 -0.01  5.00 -0.08  0.03  5.00  0.01 
4.02  0.01  3.97 -0.04  0.03 -0.01  0.00 -0.06  0.02  0.00  5.00 
0.04  0.02 -0.06 -0.08  0.07  3.98  0.00 -0.15  0.06 -0.01  4.01 
-0.01  0.00  0.01  0.02 -0.01  0.00  5.00  0.03 -0.01  0.00  0.00 
0.05  0.03 -0.08  2.89  0.09 -0.03  0.00 -0.20  4.07  4.99  0.01 
0.92  0.96  2.11  1.16  0.87  2.04  1.00  0.28  3.89  5.01 -0.02 

val it : unit = () 
```

One common approach to decide how much too keep is to look at the “energy” contributed by each singular value, measured as the square of that value. Let’s see this in action:

``` fsharp
let totalEnergy = sigmas.DotProduct(sigmas)
printfn "Energy contribution by Singular Value"
sigmas.ToArray() 
|> Array.fold (fun acc x ->
       let energy = x * x
       let percent = (acc + energy)/totalEnergy
       printfn "Energy: %.1f, Percent of total: %.3f" energy percent
       acc + energy) 0. 
|> ignore
``` 

Running this produces the following:

```
Energy contribution by Singular Value
Energy: 171.7, Percent of total: 0.364
Energy: 111.1, Percent of total: 0.599
Energy: 66.9, Percent of total: 0.741
Energy: 47.5, Percent of total: 0.842
Energy: 31.2, Percent of total: 0.908
Energy: 16.9, Percent of total: 0.943
Energy: 10.9, Percent of total: 0.967
Energy: 7.7, Percent of total: 0.983
Energy: 4.1, Percent of total: 0.992
Energy: 3.6, Percent of total: 0.999
Energy: 0.4, Percent of total: 1.000

val totalEnergy : float = 472.0
```

The largest value contributes to 36% of the energy, and the 5 first ones together are responsible for 90% of the shape of our matrix. Let’s see how an approximation using only 5 values looks like, by setting the value of `**subset**` to 5:

```
2.16 -0.31 -0.10  3.74  3.98 -0.30  0.07  0.51  0.46 -0.14  0.07 
0.45 -0.79  0.32  0.04 -0.18  1.29  0.02 -0.17 -0.23 -0.09  4.38 
1.88  0.94  1.37  0.41  0.94 -0.16  0.31  0.31 -0.12 -0.41  0.32 
4.09  2.80  3.68  0.95  1.76 -0.16 -0.33  0.75  1.23  0.49 -0.22 
5.02  4.07  5.29 -0.85  0.52 -0.28  0.07  0.82  0.63 -0.13 -0.02 
-0.11 -0.04  0.08  0.18 -0.21  0.26  5.43 -0.10  0.86  4.24 -0.06 
3.57  1.34  3.31 -0.12  0.47  1.24  0.21  0.32 -0.01 -0.30  5.00 
0.22 -0.81  0.35  0.05 -0.39  1.52 -0.28 -0.21  0.23  0.44  4.54 
0.39 -0.17 -0.15 -0.24  0.14 -0.37  4.43 -0.01 -1.06  1.00  0.02 
-0.34  0.03  0.17  2.31  0.94  1.06  0.01  0.03  3.80  5.02 -0.25 
1.04  1.23  1.87  1.46  0.50  1.13  0.85  0.19  3.76  5.26  0.28 
val it : unit = ()
```

Obviously, this is not quite as close to the original matrix as before, but it’s still pretty good – and that, in spite of the fact that we just dropped 6 out of our 11 features. Not bad! Instead of storing 11 x 11 = 121 values, we now need only 11 x 5 + 11 x 5 + 5 = 115 values (we only need to store the diagonal values of S, because the rest is 0).

Of course, with 11 dishes and 11 users, it’s hardly worth the effort. However, imagine that we had 1,000 users, and that 5 singular values was still the magic number. In that case, our data matrix would be 1,000 x 11 = 11,000 values, whereas the reduced version would require 1,000 x 5 + 11 x 5 + 5 = 5,060 values, only 46% of the initial matrix. In this case, being able to reduce the set of features suddenly becomes a much more interesting proposition.

I’ll stop here for today - I hope this post conveyed first that Linear Algebra with Math.NET and F# is pretty easy, and then a sense for what Singular Value Decomposition does. Next time, we’ll look at how we could go about providing recommendations to users by analyzing the similarities between dish ratings – and then how we can take advantage of the SVD decomposition to reduce the features into a simplified representation and improve the process.

## Additional Resources

[The script in its current state](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/blob/2d3d78a95b8c88227bcea29a87b1441f55272890/MachineLearningInAction/MachineLearningInAction/Chapter14.fsx) on GitHub.

For more on the math behind Singular Value Decomposition, check [Wikipedia](http://en.wikipedia.org/wiki/Singular_value_decomposition) and [Wolfram MathWorld](http://mathworld.wolfram.com/SingularValueDecomposition.html). I also found the page on [Latent Semantic Indexing](http://en.wikipedia.org/wiki/Latent_semantic_indexing#Rank-Reduced_Singular_Value_Decomposition) useful in getting a less mathematical but more intuitive sense of what is going on.

[Using Math.NET Numerics in F#](http://msdn.microsoft.com/en-us/library/hh304363(v=vs.100).aspx): a very nice intro tutorial by [Tomas Petricek](http://tomasp.net/).

The [Math.NET repository on GitHub](https://github.com/mathnet).
