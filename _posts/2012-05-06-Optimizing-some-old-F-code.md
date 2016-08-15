---
layout: post
title: Optimizing some old F# code
tags:
- F#
- Algorithms
- Performance
---

I am digging back into the Bumblebee code base, to clean it up before talking at the [New England F# user group in Boston](http://fsug.org/) in June. As usual for me, it’s a humbling experience to face my own code, 6 months later, or, if you are an incorrigible optimist, it’s great to see that I am so much smarter today than a few months ago…  

In any case, while toying with one of the samples, I noted that performance was degrading pretty steeply as the size of the problem was increasing. Most of the action revolved around producing random shuffles of a list, so I figured it would be interesting to look into it and see <strike>where I messed up</strike> how this could be improved upon.  

Here is the original code, a quick-and-dirty implementation of the [Fisher-Yates shuffle](http://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle#The_modern_algorithm):  

``` fsharp
open System

let swap fst snd i =
   if i = fst then snd else
   if i = snd then fst else
   i

let shuffle items (rng: Random) =
   let rec shuffleTo items upTo =
      match upTo with
      | 0 -> items
      | _ ->
         let fst = rng.Next(upTo)
         let shuffled = List.permute (swap fst (upTo - 1)) items
         shuffleTo shuffled (upTo - 1)
   let length = List.length items
   shuffleTo items length

[<EntryPoint>]
let main argv = 
     let test = [1..10000]
     let random = new Random()
     let shuffled = shuffle test random
     System.Console.WriteLine("done...")
     0
``` 

<!--more-->

Running the test case in **fsi**, using `#time`, produces the following:

```
Real: 00:00:42.735, CPU: 00:00:42.734, GC gen0: 2307, gen1: 6, gen2: 0
```

*(Digression: [`#time`](http://msdn.microsoft.com/en-us/library/dd233175.aspx) is absolutely awesome – just typing `#time;;` in a fsi session will automatically display performance information, allowing to quickly tweak a function and fine-tune it “on the fly”. I wish I had known about it earlier.)*

My initial assumption was that the problem revolved around performing multiple permutations of a List. However, I figured it would be interesting to take the opportunity and use the Performance Analysis tools provided in VS11 – and here is what I got:

![Performance Analysis]({{ site.url }}/assets/2012-05-06-image_thumb_16.png)

Uh-oh. Looks like the shuffle is spending most of its time doing comparisons in the swap function – and what the hell is `HashCompare.GenericEqualityIntrinsic` doing in here? Something is off.

Looking into the swap function provides a hint:

![swap function]({{ site.url }}/assets/2012-05-06-image_thumb_17.png)

F# has identified that the function could be [made generic](http://msdn.microsoft.com/en-us/library/dd233183.aspx). It’s great, but in our case it comes with overhead, because we simply want to compare integers. Let’s mark the function as [`inline`](http://msdn.microsoft.com/en-us/library/dd548047.aspx), to avoid that problem (we could also make the function non-generic, by marking one of the inputs as integer):

![Profiler]({{ site.url }}/assets/2012-05-06-image_thumb_18.png)

Shuffling a list of 10,000 elements is now down to 3 seconds, instead of 43:

```
Real: 00:00:03.361, CPU: 00:00:03.359, GC gen0: 793, gen1: 2, gen2: 0
```

… and most of the work is happening where we would expect it, that is, in permutations. However, it also looks like `List.ofArray` is pretty busy, and we don’t have a single reference to Array in the code – what’s going on there? Turns out, [List.permute actually converts the List to an Array](https://github.com/fsharp/fsharp/blob/master/src/fsharp/FSharp.Core/list.fs#L404) ([thanks, StackOverflow](http://stackoverflow.com/a/10251808/114519)), permutes it and converts it back, which makes sense given that List is a linked list. This means that for a list of n elements, we are converting n times from list to array and back, maybe we can avoid some of that noise and do all the permutation work on an Array:


``` fsharp
let inline swap fst snd i =
   if i = fst then snd else
   if i = snd then fst else
   i

let shuffle items (rng: Random) =
   let rec shuffleTo items upTo =
      match upTo with
      | 0 -> items
      | _ ->
         let fst = rng.Next(upTo)
         let shuffled = Array.permute (swap fst (upTo - 1)) items
         shuffleTo shuffled (upTo - 1)
   let array = List.toArray items
   let length = Array.length array
   shuffleTo array length |> Array.toList
``` 

`#time` tells us we are now down to 1 second:

```
Real: 00:00:01.188, CPU: 00:00:01.250, GC gen0: 159, gen1: 2, gen2: 1
```

And the bulk of the work is now in `Array.permute`:

![Profiler]({{ site.url }}/assets/2012-05-06-image_thumb_19.png)

At that point, I can’t think of obvious ways to improve this, except by trying to avoid `Array.permute`. Let’s do that, and see if we can shuffle indexes in place in a single array, instead of applying multiple permutations:

``` fsharp
let shuffle items (rng: Random) =
   let rec shuffleTo (indexes: int[]) upTo =
      match upTo with
      | 0 -> indexes
      | _ ->
         let fst = rng.Next(upTo)
         let temp = indexes.[fst]
         indexes.[fst] <- indexes.[upTo] 
         indexes.[upTo] <- temp
         shuffleTo indexes (upTo - 1)
   let length = List.length items
   let indexes = [| 0 .. length - 1 |]
   let shuffled = shuffleTo indexes (length-1)
   List.permute (fun i -> shuffled.[i]) items
``` 

We are now down to under 1/100 seconds, and garbage collection is down to nothing:

```
Real: 00:00:00.008, CPU: 00:00:00.015, GC gen0: 0, gen1: 0, gen2: 0
```

At that point, I am out of ideas on how to make this better – which is fine, because this looks good enough to me! If you have ideas on how to make this better, I am all ears…

And thank you for people who answered [here](http://stackoverflow.com/questions/10251744/performance-of-list-permute) and [here](http://stackoverflow.com/questions/10475079/f-automatic-generalization-and-performance) on StackOverflow!
