---
layout: post
title: Recommendation Engine using Math.NET, SVD and F#
tags:
- F#
- Machine-Learning
- Linear-Algebra
- Math.NET
- SVD
- Recommendation-Engine
---

{% include ml-in-action-series.html %}

In our previous post, we began [exploring Singular Value Decomposition (SVD) using Math.NET and F#,]({{ site.url }}/2013/03/25/Simplify-data-with-SVD-and-MathNET-in-FSharp/) and showed how this linear algebra technique can be used to “extract” the core information of a dataset and construct a reduced version of the dataset with limited loss of information. 

Today, we’ll pursue our excursion in Chapter 14 of [Machine Learning in Action](http://www.manning.com/pharrington/), and look at how this can be used to build a collaborative recommendation engine. We’ll follow the approach outlined by the book, starting first with a “naïve” approach, and then using an SVD-based approach. We’ll start from a slightly modified setup from last post, loosely inspired by the [Netflix Prize](http://en.wikipedia.org/wiki/Netflix_Prize). The full code for the example can be found [here on GitHub](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/blob/0948913e61c53cae92d8f8cf016b33aea6919382/MachineLearningInAction/MachineLearningInAction/Chapter14-Recommender.fsx). 

## The problem and setup 

In the early 2000s, Netflix had an interesting problem. Netflix’s business model was simple: you would subscribe, and for a fixed fee you could watch as many movies from their catalog as you wanted. However, what happened was the following: users would watch all the movies they knew they wanted to watch, and after a while, they would run out of ideas – and rather than search for lesser-known movies, they would leave. As a result, Netflix launched a prize: if you could create a model that could provide users with good recommendations for new movies to watch, you could claim a $1,000,000 prize. 

Obviously, we won’t try to replicate the Netflix prize here, if only because the dataset was rather large; 500,000 users and 20,000 movies is a lot of data… We will instead work off a fake, simplified dataset that illustrates some of the key ideas behind collaborative recommendation engines, and how SVD can help in that context. For the sake of clarity, I’ll be erring on the side of extra-verbose. 

Our dataset consists of users and movies; a movie can be rated from 1 star (terrible) to 5 stars (awesome). We’ll represent it with a Rating record type, associating a UserId, MovieId, and Rating:

``` fsharp
type UserId = int
type MovieId = int
type Rating = { UserId:UserId; MovieId:MovieId; Rating:int }
``` 

To make our life simpler, and to be able to validate whether “it works”, we’ll imagine a world where only 3 types of movies exist, say, Action, Romance and Documentary – and where people have simple tastes: people either love Action and hate the rest, love Romance or hate the rest, or love Documentaries and hate the rest. We’ll assume that we have only 12 movies in our catalog: 0 to 3 are Action, 4 to 7 Romance, and 8 to 11 Documentary.

<!--more-->

Let’s create a fictional, synthetic dataset of users:

``` fsharp
// "User Templates":
//                Action .... Romance ... Documentary . 
let profile1 = [| 5; 4; 5; 4; 1; 1; 2; 1; 2; 1; 1; 1 |]
let profile2 = [| 1; 2; 1; 1; 4; 5; 5; 4; 1; 1; 1; 2 |]
let profile3 = [| 1; 1; 1; 2; 2; 2; 1; 1; 4; 5; 5; 5 |]
let profiles = [ profile1; profile2; profile3 ]

// Let's create a fake "synthetic dataset" from these 3 profiles
let rng = Random()
let proba = 0.4 // probability a movie was rated
// create fake ratings for a fake user,
// using the profile and id supplied
let createFrom profile userId =
    profile 
    |> Array.mapi (fun movieId rating -> 
        if rng.NextDouble() < proba 
        then Some({ UserId=userId; MovieId=movieId; Rating=rating }) 
        else None)
    |> Array.choose id
``` 

We create 3 “templates”, representing the taste profiles for our 3 types of users, and a “user factory”, a function `createFrom`. CreateFrom takes a profile, and an Id, and creates fake ratings for that user: with a probability of 40%, the user has seen and rated a movie, otherwise, there is no rating available.

Let’s check that it works in FSI:

```
> let romanceUser = createFrom profile2 42;;
val romanceUser : Rating [] =
  [|{UserId = 42;
     MovieId = 4;
     Rating = 4;}; {UserId = 42;
                    MovieId = 5;
                    Rating = 5;}; {UserId = 42;
                                   MovieId = 9;
                                   Rating = 1;}; {UserId = 42;
                                                  MovieId = 10;
                                                  Rating = 1;}|]
```

Fictional user 42 is created using the “Romance” template; User 42 has seen and enjoyed movies 4 and 5, and disliked movies 9 and 10 – and we have no ratings for the remaining 8 movies. 

*Note: results will be different each run, because we are randomly generating users.*

We can now create a random sample of, say, 100 users: we’ll draw a random profile for each user, and create a collection of “sparse” ratings:

``` fsharp
let sampleSize = 100
let ratings = [
    for i in 0 .. (sampleSize - 1) do 
        yield! createFrom (profiles.[rng.Next(0, 3)]) i 
    ]
``` 

For convenience, we’ll also create a list of all the movie Ids we have in our catalog:

``` fsharp
let movies = 12
let movieIds = [ 0 .. (movies - 1) ]
``` 

We can now get to work. First, we’ll pull these ratings into a Matrix using Math.NET, in a similar fashion as in our last post, denoting a missing rating by a 0.

``` fsharp
let data = DenseMatrix(sampleSize, movies) 
for rating in ratings do
    data.[rating.UserId, rating.MovieId] <- Convert.ToDouble(rating.Rating)
``` 

Running this in FSI should produce something like this:

```
val data : DenseMatrix =
  DenseMatrix 100x12-Double
      0            0            1            2            0 ...        0
      0            4            0            4            1 ...        1
      1            2            0            0            0 ...        2
      0            0            0            0            1 ...        0
      0            0            0            2            0 ...        0
      1            0            0            0            0 ...        0
      1            0            0            0            0 ...        2
      ...          ...          ...          ...          ... ...      ...
      0            1            0            2            2 ...        0
```

Math.NET 2.5.0 now automatically renders matrices in a user-friendly format, abridging the contents; only the first 5 columns and 7 rows, and the last elements, are displayed, which doesn’t clutter (or crash…) FSI when dealing with large datasets. In this particular case, we see that the user in second row is an Action fan, for instance. If we want to see his full profile, we can simply extract the corresponding row:

``` fsharp
> printfn "User 1 ratings: %A" (data.Row(1) |> Seq.toList);;
User 1 ratings: [0.0; 4.0; 0.0; 4.0; 1.0; 0.0; 2.0; 1.0; 0.0; 0.0; 0.0; 1.0]
val it : unit = ()
```

## Collaborative Recommendation Engine outline

So how could we go about creating a recommendation? Imagine for a minute that our dataset looked like this:


    | Movie 1 | Movie 2 | Movie 3 
--- | --- | --- | ---
User 1 | 5 | 5 | 1
User 3 | 1 | 1 | 5
User 4 | 5 | ??? | 1

If I were to guess the missing rating for User 4 / Movie 2, I’d probably guess 5-ish: the ratings for Movie 2 look a whole lot like Movie 1, and User 4 rated Movie 1 a 5; given how similar they are, it’s a reasonable bet to think User 4 would rate Movie 2 similarly to Movie 1. Conversely, Movie 2 and Movie 3 are nothing alike, so I wouldn’t put too much weight on the rating User 4 gave to Movie 3. 

The idea behind a collaborative recommendation engine goes along the same lines: to make a recommendation, we need to:

* extract movies the user hasn’t tasted yet (i.e. movies with a 0 rating),  
* using existing ratings from the user and others, estimate how he might rate them,  
* return the top-rated movies based on our estimate. 

The hard part here is to produce a sensible estimate for how our user might rate an un-tasted movie. The approach we’ll take is the following: for each “candidate” movie, we’ll measure how much it resembles the other already-rated movies, and how the user rated them. If two movies are very similar (determined by how others have rated them, hence the “collaborative” part), we expect the user to rate them in a similar way; if they are very dissimilar, the rating of the other dish doesn’t provide much information. Our final rating will be a weighted average of the known ratings, weighted by their degree of similarity.

We can already write a code outline for how the engine will work. We’ll need to extract the rating a user gave to a movie, which could exist or not (hence the option type), a similarity between two movies, and compute a weighted average of ratings and similarities:

``` fsharp
type userRating = UserId -> MovieId -> float option
type movieSimilarity = MovieId -> MovieId -> float

/// Compute weighted average of a sequence of (value, weight)
let weightedAverage (data: (float * float) seq) = 
    let weightedTotal, totalWeights = 
        Seq.fold (fun (R,S) (r, s) -> 
            (R + r * s, S + s)) (0., 0.) data
    if (totalWeights <= 0.) 
    then None 
    else Some(weightedTotal/totalWeights)
``` 

Using these 3 functions, we can compute an estimated rating for a movie:

``` fsharp
let estimate (similarity:movieSimilarity) 
             (rating:userRating) 
             (sample:MovieId seq) 
             (userId:UserId) 
             (movieId:MovieId) = 
    match (rating userId movieId) with
    | Some(_) -> None // already rated
    | None ->
        sample
        // for all rated movies, get rating
        // and similarity
        |> Seq.choose (fun id -> 
            let r = rating userId id
            match r with
            | None -> None
            | Some(value) -> Some(value, (similarity movieId id)))
        |> weightedAverage
``` 

Given a similarity measure, ratings, and a “catalog” of movie Ids, if the target movie is already rated we don’t produce an estimate; otherwise, we extract the rating of every movie the user rated and how similar it is to our unknown movie, and average it out. From there on, producing a recommendation is straightforward:

``` fsharp
let recommend (similarity:movieSimilarity) 
              (rating:userRating) 
              (sample:MovieId seq) 
              (userId:UserId) =
    sample
    |> Seq.map (fun movieId -> 
        movieId, estimate similarity rating sample userId movieId)
    |> Seq.choose (fun (movieId, r) -> 
        match r with 
        | None -> None 
        | Some(value) -> Some(movieId, value))
    |> Seq.sortBy (fun (movieId, rating) -> - rating)
    |> Seq.toList
``` 

Grab all the movies in the catalog (“sample”), choose the unrated ones, and return a list sorted by decreasing estimated rating.

## A simple recommendation engine

Now that we have a skeleton, we just need to fill the blanks, and supply a similarity and rating function to the recommender.

So how could we measure similarity between two items?

If the only thing we have available is user ratings, one approach is to consider how much other users agree on how they rate items. If everybody else rates the two items in a similar way, chances are, our user will, too. We can now restate our problem as “given these two vectors of ratings, can we define a measure for how similar they are”?

There are multiple ways we could measure that similarity. The book suggests three: similarity based on the distance between ratings, their angle, and their correlation:

``` fsharp
// To make recommendations we need a similarity measure
type similarity = Vector<float> -> Vector<float> -> float

// Larger distances imply lower similarity
let euclideanSimilarity (v1: Vector<float>) (v2: Vector<float>) =
    1. / (1. + (v1 - v2).Norm(2.))

// Similarity based on the angle
let cosineSimilarity (v1: Vector<float>) v2 =
    v1.DotProduct(v2) / (v1.Norm(2.) * v2.Norm(2.))

// Similarity based on the Pearson correlation
let pearsonSimilarity (v1: Vector<float>) v2 =
    if v1.Count > 2 
    then 0.5 + 0.5 * Correlation.Pearson(v1, v2)
    else 1.
``` 

The Math.NET library comes in handy here: the Euclidean similarity is based on the Euclidean distance (a.k.a. “2-Norm”) between the ratings vectors, which is built-in. The cosine similarity measures the [Cosine](http://en.wikipedia.org/wiki/Dot_product) between vectors, and the Pearson similarity the Pearson correlation, which is included in the `MathNet.Numerics.Statistics` namespace. Note that these have all been slightly transformed / rescaled, so that the similarity values range from 0 (dissimilar) to 1 (identical): we need these values to be positive in order to be able to perform a weighted average – and this also makes the interpretation of the “similarity value” fairly straightforward.

Let’s check if it works with FSI.

```
> euclideanSimilarity (data.Column(0)) (data.Column(0));;
val it : float = 1.0
```

Thankfully, it looks like a vector is 100% similar to itself.

```
> pearsonSimilarity (data.Column(0)) (data.Column(1));;
val it : float = 0.6996543371
```

Movie 1 is “69.9% similar” to Movie 0, based on the Pearson correlation similarity.

```
> cosineSimilarity  (data.Column(0)) (data.Column(4));;
val it : float = 0.2226962234
```

Movie 0 and 4 are only “22% similar”, based on Cosine similarity.

Interestingly, the “degree of similarity” we observe varies quite a bit depending on the similarity measure we select – which means that first they don’t measure exactly the same thing, and then that some testing will be required to figure out which one works best on a particular dataset.

Now that we have a similarity measure, we are almost ready to produce recommendations. Given that items that haven’t been rated are denoted by a zero, we want to eliminate them from the comparison (if two movies have a 0 value, it doesn’t mean they are similar) – we’ll compare only two movies across users who have rated both.

Let’s extract the non-zero elements between two vectors:

``` fsharp
// Reduce 2 vectors to their non-zero pairs
let nonZeroes (v1:Vector<float>) 
              (v2:Vector<float>) =
    // Grab non-zero pairs of ratings 
    let size = v1.Count
    let overlap =
        [| for i in 0 .. (size - 1) do
            if v1.[i] > 0. && v2.[i] > 0. 
            then yield (v1.[i], v2.[i]) |]
    // Recompose vectors if there is something left
    if overlap.Length = 0
    then None
    else 
        let v1', v2' = Array.unzip overlap
        Some(DenseVector(v1'), DenseVector(v2'))
``` 

This isn’t the most elegant code ever (probably has something to do with the fact that this isn’t exactly “proper algebra”), but it works: we take 2 vectors, and construct a list of all the elements which are both non-zero. If that list is empty, we return nothing, otherwise we re-hydrate the two corresponding vectors.

We are now ready to wire things up and generate recommendations. 

``` fsharp
// "Simple" similarity: keep only users that
// have rated both movies, and compare.
let simpleSimilarity (s:similarity) =
    fun (movie1:MovieId) (movie2:MovieId) ->
        let v1, v2 = data.Column(movie1), data.Column(movie2)
        let overlap = nonZeroes v1 v2
        match overlap with
        | None -> 0.
        | Some(v1', v2') -> s v1' v2'

// Return rating from data matrix, captured in closure
let simpleRating (userId:UserId) (movieId:MovieId) =
    let rating = data.[userId, movieId]
    if rating = 0. then None else Some(rating)

// Wire everything together: return a function
// that will produce a recommendation, based
// on whatever similarity function it is given
let simpleRecommender (s:similarity) =
    fun (userId:UserId) -> 
        recommend (simpleSimilarity s)
                  simpleRating
                  movieIds 
                  userId
``` 

We capture the data matrix in a closure, and generate two functions with the expected signature, pass them to the recommender, et voila! We have not one, but three shiny functional collaborative recommendation engines:

``` fsharp
let simpleEuclidean = simpleRecommender euclideanSimilarity
let simpleCosine = simpleRecommender cosineSimilarity
let simplePearson = simpleRecommender pearsonSimilarity

let someUser = 42 // random user
let hisProfile = data.Row(someUser) |> Seq.toList
printfn "User ratings: %A" hisProfile
printfn "Simple recommendation"
printfn "Recommendation, Euclidean: %A" (simpleEuclidean someUser)
printfn "Recommendation, Cosine: %A" (simpleCosine someUser)
printfn "Recommendation, Pearson: %A" (simplePearson someUser)
``` 

… which produce the following results in FSI (again, results will vary every run):

```
User ratings: [0.0; 0.0; 0.0; 1.0; 4.0; 5.0; 0.0; 4.0; 0.0; 0.0; 0.0; 2.0]
Simple recommendation
Recommendation, Euclidean: [(6, 3.730860116); (8, 2.91926024); (10, 2.854315682); (1, 2.750941114); (9, 2.707329705); (0, 2.658560996); (2, 2.631763715)]
Recommendation, Cosine: [(6, 3.450248234); (1, 3.031925533); (9, 3.029625064); (10, 3.018568863); (8, 2.90810362); (0, 2.801603274); (2, 2.790866416)]
Recommendation, Pearson: [(6, 3.890147996); (10, 2.929270227); (9, 2.898904058); (1, 2.596823758); (8, 2.355074574); (0, 2.189572398); (2, 2.052913864)]
```

From his profile, we can see that our user is a Romance fan. The only unrated Romance movie is in position 6, so if “it works”, we would expect it to come first, with other movies getting lower ratings. Things seem to work – let’s collect that Million prize…

## The SVD approach

In [our previous post]({{ site.url }}/2013/03/25/Simplify-data-with-SVD-and-MathNET-in-FSharp/), we saw how Singular Value Decomposition provided a method to extract the “core structure” of a matrix, and potentially eliminate redundant or noisy information by only keeping the high-energy components. Let’s apply the idea to our situation: instead of comparing Movies on the raw column ratings, we can apply a SVD to the ratings matrix, and reconstruct the projection of each movie in this new space:

``` fsharp
let valuesForEnergy (min:float) (sigmas:Vector<float>) =
    let totalEnergy = sigmas.DotProduct(sigmas)
    let rec search i accEnergy =
        let x = sigmas.[i]
        let energy = x * x
        let percent = (accEnergy + energy)/totalEnergy
        match (percent >= min) with
        | true -> i
        | false -> search (i + 1) (accEnergy + energy)
    search 0 0.

let energy = 0.9 // arbitrary threshold

let data' =
    let svd = data.Svd(true)
    let U, sigmas = svd.U(), svd.S()
    let subset = valuesForEnergy energy sigmas
    let U' = U.SubMatrix(0, U.RowCount, 0, subset)
    let S' = DiagonalMatrix(subset, subset, sigmas.SubVector(0, (subset)).ToArray())
    (data.Transpose() * U' * S').Transpose()
``` 

The `valuesForEnergy` function, given a vector that contains the diagonal values of the sigma matrix, retains the values that contains the desired percentage of “energy” (or conversely, discard the low-energy, less significant values). This allows us to extract a matrix data’, which arbitrarily retains 90% of the original structure:

```
val data' : Generic.Matrix<float> =  
  DenseMatrix 8x12-Double    
    -367.608     -427.457     -296.135     -392.975     -309.376 ...     -461.066
     97.5907      143.889      150.621      90.3359      20.1748 ...      -226.61
     -149.06     -148.525     -159.405     -122.697      91.3436 ...      39.8916
     58.2771      44.4931      -25.626      18.6963     -8.23773 ...      42.7735
    -57.4704     -22.1324       -79.24      190.661      36.1206 ...     -66.0678
    -72.7155      26.9791       71.833     -29.6119       -49.45 ...     -62.7739
     81.8681       41.083     -99.0433     -17.6046     -36.6457 ...      1.77487
     47.8852      12.8306     -6.18081     -62.0673       109.61 ...     -87.0262
```

Each column represents a movie in that new space. Note that the new matrix is much more compact than the original: we still have 12 columns, but the ratings have now been reduced to 8 values instead of 100 originally.

Instead of computing the similarity off the original matrix data, we’ll now do it off the smaller data’ matrix, and create a new recommendation engine:

``` fsharp
let svdSimilarity (s:similarity) =
    fun (movie1:MovieId) (movie2:MovieId) ->
        let v1, v2 = data'.Column(movie1), data'.Column(movie2)
        s v1 v2

// We can now create a recommender based off SVD similarity
let svdRecommender (s:similarity) =
    fun (userId:UserId) -> 
        recommend (svdSimilarity s)
                  simpleRating
                  movieIds 
                  userId
``` 

How well does this work? Let’s check:

``` fsharp
// Illustration, on same user profile as before
let svdEuclidean = svdRecommender euclideanSimilarity
let svdCosine = svdRecommender cosineSimilarity
let svdPearson = svdRecommender pearsonSimilarity

let sameUser = someUser
let sameProfile = data.Row(sameUser)
printfn "SVD-based recommendation"
printfn "Recommendation, Euclidean: %A" (svdEuclidean someUser)
printfn "Recommendation, Cosine: %A" (svdCosine someUser)
printfn "Recommendation, Pearson: %A" (svdPearson someUser)
``` 

Applied to the same user as before, here is what we get:

```
printfn "SVD-based recommendation"
printfn "Recommendation, Euclidean: %A" (svdEuclidean someUser)
printfn "Recommendation, Cosine: %A" (svdCosine someUser)
printfn "Recommendation, Pearson: %A" (svdPearson someUser);;
SVD-based recommendation
Recommendation, Euclidean: [(6, 3.414024472); (8, 3.261772673); (2, 3.25471558); (9, 3.183325777); (0, 3.171158383); (10, 3.115982233); (1, 3.099122436)]
Recommendation, Cosine: [(6, 3.409898671); (9, 3.197372158); (2, 3.140881218); (1, 3.132099169); (10, 3.119919618); (8, 3.112124369); (0, 3.09197262)]
Recommendation, Pearson: [(6, 3.288590285); (8, 3.223132947); (2, 3.218914852); (10, 3.206663823); (9, 3.20425091); (1, 3.184119819); (0, 3.174545565)]
```

First, in all three cases, the top recommendation is still Movie 6 – which is still the “correct answer”. That’s pretty cool: we got rid of all the annoying discarding of zeroes part altogether, and the algorithm is way more efficient, because we compute similarities on vectors of size 8 instead of 100. 

On the other hand, while the recommendation order is good, the estimated ratings we produce are degraded; the simple model showed a strong difference in ratings between the top recommendation and the rest, where the SVD model shows much less differentiation – which I presume is due to the inclusion of the zeroes in our dataset. On one hand, using raw SVD compensates for the missing values, by essentially extracting factors which aggregate ratings for multiple movies into one broader category, and capturing the direction of the effect; on the other hand, the inclusion of zeroes draws the estimated ratings towards an average rating, and loses predicted rating accuracy.

## Conclusion

I hope these 2 posts gave you a sense for what SVD was, why this was an interesting technique – and that Math.NET and F# together are a pretty nice combo for Linear Algebra. If I have time (a somewhat unlikely hypothesis) I may revisit the question of empty entries and how to deal with them later; [this blog post](http://blog.echen.me/2011/10/24/winning-the-netflix-prize-a-summary/) discusses the Netflix prize and hints at some possible approaches. 

Another interesting question is how to use this approach at scale. If you beef up the sample dataset from this post to more realistic numbers, you’ll notice two things: SVD slows down quite a bit as the dataset expands, and without too much effort you’ll hit unpleasant snags like `System.OutOfMemoryException`, for sample sizes that are nowhere close to “big data” (say, 10,000 users). That’s a problem, if you consider for instance that the Netflix dataset was about half a million users across 20,000 movies – and that’s why I got so interested in the [Azure Cloud Numerics project](http://www.microsoft.com/en-us/sqlazurelabs/labs/numerics.aspx) recently. Cloud Numerics is still in preview, and currently limits cluster sizes to 2 compute nodes (I don’t think a cluster can get any smaller…), but even with such a limited setup, I managed to crank through a SVD on a 100,000 x 1,000 matrix, in about 10 minutes (and all in F#!), which I found promising. I launched a 1,000,000 x 1,000 SVD as well, but after one hour waiting for my results, I got bored and killed it – I am genuinely looking forward to trying it out on a “real” cluster.

By the way, if someone out there has experience with Hadoop and whatever exists on top of it for linear algebra, I’d love to hear about it, and how it performs on similar operations!

That’s it for today – if you have comments or question, I’d love to hear them!
