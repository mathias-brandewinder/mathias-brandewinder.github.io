---
layout: post
title: Bumblebee 2.0&#58; Traveling Santa
tags:
- Bumblebee
- Traveling-Salesman
- Algorithms
---

Last week I posted some screen captures of [Bumblebee](http://bit.ly/bmblebee) in action on the Traveling Salesman Problem. One thing was bugging me, though – the algorithm didn’t seem to handle crossings very well. I ended up adding a de-crossing routing, which ended up speeding up the process quite a bit. The full C# demo, illustrating how to use Bumblebee from C#, has been pushed as version 0.2 to CodePlex.  

Below is an illustration of the algorithm in action, in a nice seasonal color scheme. Santa needs to travel through 200 random cities: starting from a terrible initial route, the algorithm progressively disentangles them and ends up with a pretty good-looking solution under 2 minutes, significantly reducing the carbon footprint of those reindeers:  

<iframe width="420" height="315" src="https://www.youtube.com/embed/PWbRBYKz4tw" frameborder="0" allowfullscreen></iframe>

*TSP with 200 cities running for 2 minutes*

So what was the issue with line crossings? Consider the following route, in perfect order:  

![image]({{ site.url }}/assets/2011-12-26-image_thumb_5.png)  

Now imagine that while searching, the algorithm discovers the following path:  

![image]({{ site.url }}/assets/2011-12-26-image_thumb_6.png)

<!--more-->

Overall, this is a pretty good solution - too good for the algorithm’s overall good, actually. We have two perfectly ordered sub-sequences (D, C, B and E, F, A), and the only thing getting in the way of finding the perfect solution is to connect A to B instead of D, and D to E instead of A. Unfortunately, the neighbor search proceeds by moving a single city in the route, which will cause the solution to degrade:  

**[A]**, D, C, B, E, F -> D, C, B, [**A]**, E, F  

Looking at a longer sequence of 10 cities organized following the same pattern explains better what is going on:  

![10-cities-with-one-crossing]({{ site.url }}/assets/2011-12-26-image_thumb_7.png)  

The sequence of letters reads A, B, C, D, E, J, I, H, G, F. Again we have two perfect sub-sequences, but because of the crossing, the two sequences progress in opposite directions, and removing the crossing while keeping the path closed requires to completely flip the second sub-sequence. That re-organization of the sequence cannot happen in a single permutation, and will require a long – and unlikely – step-by-step reversal of one of the two sequences, going through worse solutions to finally find the correct once. As an illustration, here would be the first step, moving from E to F instead of E to J:  

![Reordering-circuit-one-by-one]({{ site.url }}/assets/2011-12-26-image_thumb_8.png)

Note that the “naïve” algorithm, changing the order of one city at a time, will get there, eventually – eventually being the key word. To quote [Keynes](http://en.wikipedia.org/wiki/John_Maynard_Keynes), *“The long run is a misleading guide to current affairs. In the long run we are all dead.”* – so I decided to add a small tweak to the neighborhood search: with a certain probability, the algorithm takes a random leg of the circuit, searches the following steps it until it finds one that intersects with it, and removes the crossing, reversing all the path between the two intersecting segments.  

You’ll find the details of the implementation in the [Bumblebee C# TspDemo project](http://bumblebee.codeplex.com/releases/view/79220); the trickiest part was to figure out how to [determine whether two segments intersect](http://stackoverflow.com/a/3842157/114519) in an efficient manner. The improvement is pretty drastic. In my previous post, I had a demo of the algorithm, before the de-crossing was added; it visibly gets stuck when there are crossings, even for small problems. With de-crossing, it finds pretty good solutions to 100 cities routes under 30 seconds.  

That’s it for now! Any feedback on Bumblebee – whether on the F# code, or the API – is highly welcome. In the meanwhile, wish you all a happy new year!
