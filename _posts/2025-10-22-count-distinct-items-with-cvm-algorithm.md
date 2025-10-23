---
layout: post
title: Count distinct items with the CVM algorithm
tags:
- F#
- Algorithms
use_math: true
---

I came across this [post on the fediverse][1] the other day, pointing to an 
[interesting article][2] explaining the [CVM algorithm][3]. I found the 
algorithm very intriguing, and thought I would go over it in this post, and try 
to understand how it works by implementing it myself.  

The CVM algorithm, named after its creators, is a 
procedure to count the number of distinct elements in a collection. In most 
situations, this is not a hard problem. For example, in F#, one could write 
something like this:  

``` fsharp
open System

let rng = Random 42
let data = Array.init 1_000_000 (fun _ -> rng.Next(0, 1000))
data
|> Array.distinct
|> Array.length

val it: int = 1000
```

We create an array filled with 1 million random numbers between `0` and `999`, 
and directly extract the distinct values, which we then count. Easy peasy.  

However, imagine that perhaps your data is so large that you can't just open it 
in memory, and perhaps even the distinct items you are trying to 
count are too large to fit in memory. How would you go about counting the 
distinct items in your data then?  

The CVM algorithm solves that problem. In this post, we will first write a 
direct, naive implementation of the algorithm as presented in the paper, and 
try to discuss why it works. Then we'll test it out on the same example used in 
the article, counting the words used in Hamlet.  

<!--more-->

## Naive F# implementation of the CVM algorithm

Rather than discussing the pseudo-code presented in the paper, which uses dense 
notation, we will present directly our F# implementation. This implementation 
is rather inefficient, and could easily be optimized - our goal was to follow 
the pseudo-code closely, to quickly get a testable version going.  

Without further ado, here is our implementation:  

``` fsharp
let cvm (rng: Random) memorySize stream =

    let memory = Set.empty
    let proba = 1.0

    ((memory, proba), stream)
    ||> Seq.fold (fun (memory, proba) item ->
        let memory = memory |> Set.remove item
        let memory =
            if rng.NextDouble () < proba
            then memory |> Set.add item
            else memory
        let memory, proba =
            if memory.Count = memorySize
            then
                memory
                |> Set.filter (fun _ ->
                    rng.NextDouble () < 0.5
                    ),
                proba / 2.0
            else memory, proba
        memory, proba
        )
    |> fun (memory, proba) ->
        float memory.Count / proba
```

The code is not overly complicated. It takes 3 inputs:  

- `stream`: the data we are counting items from (a sequence),  
- `memorySize`: the number of items we can keep in memory,  
- `rng`: a random number generator.  

At a high level, the algorithm goes over the `stream` item by item, and adds new 
items to a set of distinct items, `memory`. However, instead of just adding 
them one by one and counting how many we have at the end (as one would 
typically do), it does something different. When the `memory` is full, that is, 
we have reached `memorySize`, it flushes roughly half of the items from `memory` 
at random (hence the random number generator), and starts a new round, filling 
in `memory` again, but keeping new items with a probability of one half only. The 
algorithm keeps going until the end of the stream is reached, halving the 
probability that an item is kept each time the `memory` is filled, that is, 
each time a round completes.  

Before considering why this might even work, let's test it out on our original 
`data`. We will use a `memorySize` of `100`: at any given time we will 
keep track of only `100` distinct items at most:  

``` fsharp
cvm (Random 0) 100 data

val it: float = 1056.0
```

We do not get an exact count. Instead of the correct value, `1000`, we get an 
estimate, `1056` (about 6% off). The part that is interesting is that to 
estimate the count of these `1000` items, we only had to keep track of up to 
`100` items.  

> Note: the paper also discusses bounds on the estimate. We did not have the 
time or energy to look into that part, check out the article for details!  

## Why does it even work?

Let's sketch out an argument. First, let's consider the case where the 
algorithm terminates within round `0`. In that case, we simply add distinct 
items one by one to the `memory`. If we don't reach round `1`, it means we 
never reached the condition `memory.Count = memorySize`, that is, we never 
filled the `memory`, and `proba = 1`. In that case, the algorithm is correct: 
our `memory` contains every distinct item, and, as `proba = 1`, the result
`float memory.Count / proba` simply returns the count of distinct items.  

Now imagine that the algorithm terminates in round `1`, that is, we filled the 
`memory` during round `0`, flushed half of it randomly, and started re-filling 
it, with `proba = 0.5`.  

What is the probability then that an item shows up in `memory` when the 
algorithm terminates? We have 3 cases to consider:  

- The item is encountered during round `0`, and not during round `1`. In this case, 
it will be added to `memory` during round `0`, and with probability 0.5, it is 
discarded when we start round `1`, so there is a 0.5 probability that it ends in 
`memory` when the algorithm finishes during round `1`.  
- The item is encountered during round `0` and during round `1`. During round `1`, 
when we encounter the item, we remove it from `memory`, and add it back with a 
probability of 0.5, so again there is a 0.5 probability that the item ends up 
in `memory` when the algorithm terminates during round `1`.
- The item is encountered during round `1`, and not round `0`. We simply add the 
item with a probability of 0.5 to `memory` during round `1`.  

In other words, if the algorithm terminates during round `1`, any distinct item 
has a probability of 0.5 to be listed in `memory` when we terminate.  

Now if we have `N` distinct items in our `stream`, how many distinct items should 
we observe in `memory` when the algorithm terminates? Each item has a 
probabiliy of 0.5 to be there, so on average we should have `N * 0.5` items 
listed. Or, conversely, if we end up with `M` items in `memory`, this means we 
had around `M / 0.5` distinct items in the overall `stream`.

With a bit of hand-waving, the same reasoning can be applied to the case where 
the algorithm terminates in `k` rounds. In that case, by construction, each 
item has a probability of `0.5 ^ k` of being listed in `memory` in the end, 
which leads to the complete algorithm.  

## Hamlet

The [Quanta magazine article][2] mentions applying the algorithm to the text of 
Hamlet, which I thought would be a fun experiment to reproduce. Of course, 
Hamlet is not large enough to warrant using such a jackhammer, but... it is 
fun! So let's do this.  

First, we need the book as a text file, which fortunately enough is available 
on [Project Gutenberg][4]. Let's download that as a string, using [FsHttp][5]:  

``` fsharp
open FsHttp

let hamlet =
    http {
        GET @"https://www.gutenberg.org/files/1524/1524-0.txt"
        }
    |> Request.send
    |> Response.toText
```

Next, we need to break that string into words, which we will lowercase to avoid 
double counting capitalized words. Time for some Regular Expressions:  

``` fsharp
let pattern = @"(\w+)"
let regex = Regex(pattern)

let words =
    hamlet
    |> regex.Matches
    |> Seq.cast<System.Text.RegularExpressions.Match>
    |> Seq.map (fun m -> m.Value.ToLowerInvariant())
    |> Array.ofSeq
```

We can directly count the words we have in this array, thereby also proving 
that we don't really need the CVM artillery for this case:  

``` fsharp
words.Length
val it: int = 33176

words
|> Array.distinct
|> Array.length
val it: int = 4610
```

For the record, the article mentions `3,967` distinct words - they were perhaps 
more careful than I was removing extraneous information. Anyways, let's see 
what CVM says:  

``` fsharp
cvm (Random 0) 100 words
val it: float = 4608.0
```

CVM produces an estimate of `4608` distinct words, where the correct value is 
`4610` - not bad at all! Note that depending on the seed you use for the random 
number generator, your mileage may vary.  

## Parting thoughts

Like the original poster, I was super excited by this algorithm. It's not that 
I really need it for practical purposes (although I might some day), but more 
that I find the approach very interesting. I understand why the math works, and 
still, it feels like a clever magic trick.  

My implementation is clearly not optimized at all. I struggled a bit with the 
notation in the paper, and aimed for clarity. As an obvious example, instead of 
removing and maybe re-adding an item, it is very likely faster to check first 
if the item is already listed, and perform a single set operation then. Using 
a `HashSet` instead of a `Set` would probably be faster as well. But again, 
speed was not my goal here!  

Finally, I think there is a minor bug in my implementation. If the number of distinct 
items equals the size of `memory`, the algorithm will terminate in round 0, and 
`memory` should contain exactly the distinct items. However, what happens is 
that the condition `memory.Count = memorySize` is triggered, flushing half the 
items at random. Just like speed optimizations, I'll leave that as an exercise 
to the interested reader!  

And that's where I will leave things for today, hope you found the approach as 
interesting as I did!  

[1]: https://hachyderm.io/@rain/112475838747712100
[2]: https://www.quantamagazine.org/computer-scientists-invent-an-efficient-new-way-to-count-20240516/
[3]: https://arxiv.org/pdf/2301.10191
[4]: https://www.gutenberg.org/files/1524/1524-0.txt
[5]: https://fsprojects.github.io/FsHttp/
