---
layout: post
title: Simple simulation with F# Sequences
tags:
- F#
- Sequence
- Simulation
- Probability
---

One of my initial goals for 2011 was to get my feet wet with Python, but after the last (and excellent) [San Francisco F# user group](http://www.sfsharp.org/) meetup, dedicated to F# for Python developers, I got all excited about F# again, and dug back my copy of [Programming F#](http://oreilly.com/catalog/9780596153656).  

The book contains a Sequence example which I found inspiring:

``` fsharp 
open System

let RandomSequence =
  let random = new Random()
  seq { 
    while true do
    yield random.NextDouble() }
``` 

What’s nice about this is that it is a lazy sequence; each element of the Sequence will be pulled in memory “on demand”, which makes it possible to work with Sequences of arbitrary length without running into memory limitation issues.

![Horse_simulator_WWI]({{ site.url }}/assets/2011-04-10-Horse_simulator_WWI.jpg)

This formulation looks a lot like a simulation, so I thought I would explore that direction. What about modeling the weather, in a fictional country where 60% of the days are Sunny, and the others Rainy?

Keeping our weather model super-simple, we could do something along these lines: we define a `Weather` type, which can be either Sunny or Rainy, and a function `WeatherToday`, which given a probability, returns the adequate Weather.

``` fsharp
type Weather = Sunny | Rainy

let WeatherToday probability =
  if probability < 0.6 then Sunny
  else Rainy
``` 

<!--more-->

Copying our code in the F# interactive window, we can now start running code live, and do things like this:

``` fsharp
> open System

let RandomSequence =
  let random = new Random()
  seq { 
    while true do
    yield random.NextDouble() }

type Weather = Sunny | Rainy

let WeatherToday probability =
  if probability < 0.6 then Sunny
  else Rainy;;

val RandomSequence : seq<float>
type Weather =
  | Sunny
  | Rainy
val WeatherToday : float -> Weather

> let simulation = RandomSequence |> Seq.map WeatherToday |> Seq.take 20 |> Seq.toList;;

val simulation : Weather list =
  [Sunny; Sunny; Sunny; Sunny; Sunny; Rainy; Sunny; Sunny; Rainy; Rainy; Rainy;
   Sunny; Sunny; Rainy; Sunny; Sunny; Rainy; Sunny; Sunny; Sunny]

>
``` 

Take a sequence of random numbers, map it to the function we just defined, take 20 of these, and spit out the list – and we have a simulation! If you wanted to run 100 days instead of 20, you’d just have to type `Seq.take 100` in the interactive window and let it run immediately, without any compilation involved. Pretty nice for exploration.

Suppose now that we wanted to figure out how many Very Rainy periods take place in our Sunny country. To do this, we need to identify sequences of 3 rainy days. One way to do this is to use pattern-matching: given an array of `Weather`, if the array matches 3 consecutive Rainy days, we have a match, otherwise we don’t:

``` fsharp
let VeryRainy days = 
  match days with 
    | [|Rainy;Rainy;Rainy|] -> true 
    |_ -> false
``` 

We can immediately check whether this works in the Interactive window:

``` fsharp
> VeryRainy [|Rainy;Rainy;Rainy|];;
val it : bool = true
> VeryRainy [|Sunny|];;
val it : bool = false
> VeryRainy [|Rainy;Sunny;Rainy|];;
val it : bool = false
> 
``` 

Now the only thing we need to do is to let our simulation run, break it into chunks of 3 days, using the `Seq.windowed` method, and count the elements of the sequence which match:

``` fsharp
> let rainyDays = RandomSequence |> Seq.map WeatherToday |> Seq.windowed 3 |> Seq.take 100 |> Seq.filter VeryRainy |> Seq.length;;

val rainyDays : int = 7
``` 

In this particular run of the simulation, out of 100 sequences of 3 days, we got 7 Very Rainy periods. Granted, it’s not a very complicated simulation to run – but at the same time, the code we had to write to get it to work is pretty simple, too, as well as easy to follow, and the Interactive window makes exploration very easy.

The piece which I had a harder time with was representing a country with a more complex Weather system, something like: when it’s rainy today, it’s likely to rain tomorrow, whereas when it’s sunny today, the sun is likely to shine tomorrow. We’ll explore that next time!
