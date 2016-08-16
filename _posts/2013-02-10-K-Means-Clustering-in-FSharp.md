---
layout: post
title: K-Means clustering in F#
tags:
- F#
- Machine-Learning
- Clustering
- K-Means
---

{% include ml-in-action-series.html %}

And the Journey converting “[Machine Learning in Action](http://www.manning.com/pharrington/)” from Python to F# continues! Rather than following the order of the book, I decided to skip chapters 8 and 9, dedicated to regression methods (regression is something I spent a bit too much time doing in the past to be excited about it just right now), and go straight to Unsupervised Learning, which begins with the K-means clustering algorithm. So what is clustering about? In a nutshell, clustering focuses on the following question: given a set of observations, can the computer figure out a way to classify them into “meaningful groups”? The major difference with Classification methods is that in clustering, the Categories / Groups are initially unknown: it’s the algorithm’s job to figure out sensible ways to group items into Clusters, all by itself (hence the word “unsupervised”). Chapter 10 covers 2 clustering algorithms, k-means , and bisecting k-means. We’ll discuss only the first one today. The underlying idea behind the k-means algorithm is to identify k “representative archetypes” (k being a user input), the Centroids. The algorithm proceeds iteratively:   

> Starting from k random Centroids,   
> Observations are assigned to the closest Centroid, and constitute a Cluster,   
> Centroids are updated, by taking the average of their Cluster,   
> Until the allocation of Observation to Clusters doesn’t change any more.   

When things go well, we end up with k stable Centroids (minimal modification of Centroids do not change the Clusters), and Clusters contain Observations that are similar, because they are all close to the same Centroid (The [wikipedia page](http://en.wikipedia.org/wiki/K-means_clustering#Standard_algorithm) for the algorithm provides a nice graphical representation). 

<!--more-->

## F# implementation 

The Python implementation proposed in the book is both very procedural and deals with Observations that are vectors. I thought it would be interesting to take a different approach, focused on functions instead. The current implementation is likely to change when I get into bisecting k-means, but should remain similar in spirit. Note also that I have given no focus to performance – this is my take on the easiest thing that would work. The entire code can be found [here on GitHub](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/blob/463cc43a5870cc8253bbf8b608800cb8380404b6/MachineLearningInAction/MachineLearningInAction/KMeansClustering.fs). Here is how I approached the problem. First, rather than restricting ourselves to vectors, suppose we want to deal with any generic type. Looking at the pseudo-code above, we need a few functions to implement the algorithm:  

* to assign Observations of type `'a` to the closest Centroid `'a`, we need a notion of Distance, 
* we need to create an initial collection of k Centroids of type `'a`, given a dataset of `'a`s, 
* to update the Centroids based on a Cluster of `'a`s, we need some aggregation function. 

Let’s create these 3 functions:

``` fsharp
// the Distance between 2 observations 'a is a float
// It also better be positive - left to the implementer
type Distance<'a> = 'a -> 'a -> float
// CentroidsFactory, given a dataset, 
// should generate n Centroids
type CentroidsFactory<'a> = 'a seq -> int -> 'a seq
// Given a Centroid and observations in a Cluster,
// create an updated Centroid
type ToCentroid<'a> = 'a -> 'a seq -> 'a
``` 

We can now define a function which, given a set of Centroids, will return the index of the closest Centroid to an Observation, as well as the distance from the Centroid to the Observation:

``` fsharp
// Returns the index of and distance to the 
// Centroid closest to observation
let closest (dist: Distance<'a>) centroids (obs: 'a) =
    centroids
    |> Seq.mapi (fun i c -> (i, dist c obs)) 
    |> Seq.minBy (fun (i, d) -> d)
``` 

Finally, we’ll go for the laziest possible way to generate k initial Centroids, by picking up k random observations from our dataset:

``` fsharp
// Picks k random observations as initial centroids
// (this is very lazy, even tolerates duplicates)
let randomCentroids<'a> (rng: System.Random) 
                        (sample: 'a seq) 
                        k =
    let size = Seq.length sample
    seq { for i in 1 .. k do 
            let pick = Seq.nth (rng.Next(size)) sample
            yield pick }
``` 

We have all we need – we can now write the algorithm itself:

``` fsharp
// Given a distance, centroid factory and
// centroid aggregation function, identify
// the k centroids of a dataset
let kmeans (dist: Distance<'a>) 
           (factory: CentroidsFactory<'a>) 
           (aggregator: ToCentroid<'a>)
           (dataset: 'a seq) 
           k =
    // Recursively update Centroids and
    // the assignment of observations to Centroids
    let rec update (centroids, assignment) =
        // Assign each point to the closest centroid
        let next = 
            dataset 
            |> Seq.map (fun obs -> closest dist centroids obs)
            |> Seq.toList
        // Check if any assignment changed
        let change =
            match assignment with
            | Some(previous) -> 
                Seq.zip previous next    
                |> Seq.exists (fun ((i, _), (j, _)) -> not (i = j))
            | None -> true // initially we have no assignment
        if change 
        then 
            // Update each Centroid position:
            // extract cluster of points assigned to each Centroid
            // and compute the new Centroid by aggregating cluster
            let updatedCentroids =
                let assignedDataset = Seq.zip dataset next
                centroids 
                |> Seq.mapi (fun i centroid -> 
                    assignedDataset 
                    |> Seq.filter (fun (_, (ci, _)) -> ci = i)
                    |> Seq.map (fun (obs, _) -> obs)
                    |> aggregator centroid)
            // Perform another round of updates
            update (updatedCentroids, Some(next))
        // No assignment changed, we are done
        else (centroids, next)

    let initialCentroids = factory dataset k
    let centroids = update (initialCentroids, None) |> fst |> Seq.toList        
    let classifier = fun datapoint -> 
        centroids 
        |> List.minBy (fun centroid -> dist centroid datapoint)
    centroids, classifier
``` 

The meat of the algorithm is the update function. It takes in a set of current Centroids, and an optional Assignment of Observations to Centroids, represented as a list, mapping each Observation to Centroid indexes and corresponding distance. Note that we could drop the distance for the assignment – it’s never used afterwards, I added it prematurely because it is needed in the bissecting k-means algorithm.

The update function is recursive – it computes what Centroid / Cluster each observation will be assigned to next, checks whether any Observation has been assigned to a different Cluster than before (or if there is an assignment at all, to cover the initial case when no assignment has been computed yet). If a change occurred, new Centroids are computed and we go for another round, and otherwise we are done.

The outer function calls update, and once it terminates, returns the Centroids that have been identified, as well as a Classifier function, which will return the closest Centroid to an Observation.

## The algorithm in action

I created two small examples illustrating the algorithm in action: one classic, with numeric observations, and one “just for kicks”, attempting to cluster a collection of strings. Both can be found in the file [Chapter10.fsx](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/blob/463cc43a5870cc8253bbf8b608800cb8380404b6/MachineLearningInAction/MachineLearningInAction/Chapter10.fsx).

The classic case operates on an artificially created dataset: we generate 3 points in 3 dimensions, and a collection of 50 points randomly generated in spheres around these 3 points:

``` fsharp
let rng = new System.Random()
let centroids = [ [| 0.; 0.; 0. |]; [| 20.; 30.; 40. |]; [| -40.; -50.; -60. |] ]
// Create 50 points centered around each Centroid
let data = [ 
    for centroid in centroids do
        for i in 1 .. 50 -> 
            Array.map (fun x -> x + 5. * (rng.NextDouble() - 0.5)) centroid ]
``` 

If everything works correctly, we expect the algorithm to identify 3 Centroids close to the 3 points we used as anchor points for our data sample. We need to define 2 functions, which are included in the main module: a Distance, and a function to compute a Centroid from a Cluster of Observations:

``` fsharp
// Euclidean distance between 2 points, represented as float []
let euclidean x y = 
    Array.fold2 (fun d e1 e2 -> d + pown (e1 - e2) 2) 0. x y 
    |> sqrt

// Recompute Centroid as average of given sample
let avgCentroid (current: float []) (sample: float [] seq) =
    let size = Seq.length sample
    match size with
    | 0 -> current
    | _ ->
        sample
        |> Seq.reduce (fun v1 v2 -> 
               Array.map2 (fun v1x v2x -> v1x + v2x) v1 v2)
        |> Array.map (fun e -> e / (float)size)
``` 

Armed with this, we can run the algorithm:

``` fsharp
let factory = randomCentroids<float[]> rng
let identifiedCentroids, classifier = kmeans euclidean factory avgCentroid data 3
printfn "Centroids identified"
identifiedCentroids 
|> List.iter (fun c -> 
    printfn ""
    printf "Centroid: "
    Array.iter (fun x -> printf "%.2f " x) c)
``` 

On my machine, this produces the following:
```
Centroids identified  
Centroid: 19.93 30.32 39.89  
Centroid: -39.98 -50.10 -59.69  
Centroid: -0.28 0.43 -0.01
```

The 3 centroids are exactly what we expect – 3 points close to {20; 30; 40}, {-40; –50; -60} and {0; 0; 0}. Things seem to be working.

Now I was curious to see if this would be usable on something completely different, like strings. As usual, in order to make that work, we need a Distance, and a way to reduce a Cluster to a Centroid. The most obvious choice for a Distance between strings is the [Levenshtein distance](http://en.wikipedia.org/wiki/Levenshtein_distance), which measures how many edits are required to transform a string into another. Fortunately for me, someone already provided an [implementation in F#](http://en.wikibooks.org/wiki/Algorithm_implementation/Strings/Levenshtein_distance#F.23), which I shamelessly lifted.

The Centroid update question required a bit of thinking. Obviously, computing the average of strings isn’t going to work – so how could we find a good “representative string” from a Cluster? I decided to go for something fairly simple: pick the string in the Cluster which has the least worst-case distance to all the others (as an alternative, I also tried picking the string with the lowest sum of squares distance, which produced similar results).

Finally, I created a sample, using a collection of 53 words sharing three different roots: “GRAPH”, “SCRIPT” and “GRAM”. Results vary from run to run (not surprisingly, the algorithm often struggles to separate GRAPH and GRAM words), but overall I was pleasantly surprised by the results:

```
Words identified
TELEGRAPHIC
RADIOGRAM
PRESCRIPTIVE

Classification of sample words
AUTOBIOGRAPHER -> TELEGRAPHIC
AUTOBIOGRAPHICAL -> TELEGRAPHIC
AUTOBIOGRAPHY -> TELEGRAPHIC
AUTOGRAPH -> RADIOGRAM
BIBLIOGRAPHIC -> TELEGRAPHIC
BIBLIOGRAPHY -> TELEGRAPHIC
CALLIGRAPHY -> TELEGRAPHIC
CARTOGRAPHY -> RADIOGRAM
CRYPTOGRAPHY -> RADIOGRAM
GRAPH -> TELEGRAPHIC
HISTORIOGRAPHY -> TELEGRAPHIC
PARAGRAPH -> TELEGRAPHIC
SEISMOGRAPH -> TELEGRAPHIC
STENOGRAPHER -> TELEGRAPHIC
TELEGRAPH -> TELEGRAPHIC
TELEGRAPHIC -> TELEGRAPHIC
BIBLIOGRAPHICAL -> TELEGRAPHIC
STEREOGRAPH -> TELEGRAPHIC
DESCRIBABLE -> PRESCRIPTIVE
DESCRIBE -> PRESCRIPTIVE
DESCRIBER -> PRESCRIPTIVE
DESCRIPTION -> PRESCRIPTIVE
DESCRIPTIVE -> PRESCRIPTIVE
INDESCRIBABLE -> PRESCRIPTIVE
INSCRIBE -> PRESCRIPTIVE
INSCRIPTION -> PRESCRIPTIVE
POSTSCRIPT -> PRESCRIPTIVE
PRESCRIBE -> PRESCRIPTIVE
PRESCRIPTION -> PRESCRIPTIVE
PRESCRIPTIVE -> PRESCRIPTIVE
SCRIBAL -> RADIOGRAM
SCRIBBLE -> PRESCRIPTIVE
SCRIBE -> PRESCRIPTIVE
SCRIBBLER -> RADIOGRAM
SCRIPT -> PRESCRIPTIVE
SCRIPTURE -> PRESCRIPTIVE
SCRIPTWRITER -> PRESCRIPTIVE
SUPERSCRIPT -> PRESCRIPTIVE
TRANSCRIBE -> PRESCRIPTIVE
TYPESCRIPT -> PRESCRIPTIVE
TRANSCRIPTION -> PRESCRIPTIVE
DESCRIPTOR -> PRESCRIPTIVE
ANAGRAM -> RADIOGRAM
CABLEGRAM -> RADIOGRAM
CRYPTOGRAM -> RADIOGRAM
GRAMMAR -> RADIOGRAM
GRAMMARIAN -> RADIOGRAM
GRAMMATICAL -> RADIOGRAM
MONOGRAM -> RADIOGRAM
RADIOGRAM -> RADIOGRAM
TELEGRAM -> TELEGRAPHIC
UNGRAMMATICAL -> TELEGRAPHIC
AEROGRAM -> RADIOGRAM
```

That’s it for today! In our next “ML in Action” episode, we’ll look into the bissecting k-means algorithm, which is a variation on today’s algorithm, and probably revisit the implementation. In the meanwhile, feel free to leave comments or feedback!

## Resources

[Source code on GitHub](https://github.com/mathias-brandewinder/Machine-Learning-In-Action/tree/463cc43a5870cc8253bbf8b608800cb8380404b6): the relevant code is in the files KMeansClustering.fs and Chapter10.fsx.

[K-means algorithm on Wikipedia](http://en.wikipedia.org/wiki/K-means_clustering#Standard_algorithm).

[Levenshtein distance on Wikipedia](http://en.wikipedia.org/wiki/Levenshtein_distance), and an [F# implementation of Levenshtein distance](http://en.wikibooks.org/wiki/Algorithm_implementation/Strings/Levenshtein_distance#F.23).

[Interesting discussion on the Levenshtein distance](http://richardminerich.com/2012/09/levenshtein-distance-and-the-triangle-inequality/) on [@Rickasaurus](https://twitter.com/rickasaurus)’ blog.

Another [K-means implementation in F#,](http://tech.blinemedical.com/k-means-step-by-step-in-f/) from [@DevShorts](https://twitter.com/devshorts).

[Root Words](http://www.learnthat.org/pages/view/roots.html): an intriguing web page, providing help to learn words and vocabulary, which contains a list of words roots. It has one incredibly annoying feature – you can’t copy paste text from the page.
