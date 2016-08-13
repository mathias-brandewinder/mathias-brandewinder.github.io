---
layout: post
title: Simulating a Markov Chain with F# Sequences
tags:
- F#
- Simulation
- Markov
- Probability
- Sequence
---

In my last post, I looked into running a [simple simulation using F# sequences]({{ site.url }}2011-04-10-Simple-simulation-with-F-Sequences/); our model mapped a sequence of random numbers to 2 states, Rainy and Sunny.  What if we wanted to model something a bit more realistic, like a system where the weather tomorrow depends on the weather today? Let’s say, for instance, that if the weather is Sunny today, there is a 60% chance that it’s still Sunny tomorrow, but if it’s Rainy today, we have a 70% chance that tomorrow is Rainy.  

*Technicality: we will also assume that if we know today’s weather, what happened yesterday brings us no additional information on the probability of rain or sun tomorrow.*  

Let’s start like last time, and define first a `Weather` type, with 2 states, `Rainy` and `Sunny`, and represent the transitions from state to state, using pattern matching:  

```  fsharp
type Weather = Sunny | Rainy

let NextDay today proba =
    match today with
    | Rainy -> if proba < 0.7 then Rainy else Sunny
    | Sunny -> if proba < 0.6 then Sunny else Rainy
``` 

Armed with this, starting from an initial state, we want to generate the next state, based on the current state and the next probability coming from the sequence of random numbers. This part got me stumped for a while. Using a [`Sequence map`](http://msdn.microsoft.com/en-us/library/ee370346.aspx) is clearly not going to work, because, unlike in the previous post, we can’t determine the `Weather` based on the probability alone, we need both the probability and the previous `Weather`. Conversely, [`Sequence unfold`](http://msdn.microsoft.com/en-us/library/ee340363.aspx) has the opposite problem: it generates a sequence of states based on the previous State, but doesn’t take in another Sequence as input.

<!--more-->

One way to go around that issue is to bake the missing part – the random number sequence – into the state itself, and use unfold. My first take on the problem looked like this:


``` fsharp
let NextState (today, (random:Random)) =
  let proba = random.NextDouble()
  let nextDay = NextDay today proba
  Some (nextDay, (nextDay, random))
``` 

The state is expanded into a Tuple, formed of today’s weather and the instance of the Random that provides the random numbers, and the `NextState` function, given a `Weather` and the `Random`, returns the next `Weather` with the same instance. We can then use this to generate sequences, using unfold:

``` fsharp
> let random = new Random()
let days = Seq.unfold NextState (Sunny, random)
let listOfDays = days |> Seq.take 10 |> Seq.toList;;

val random : Random
val days : seq<Weather>
val listOfDays : Weather list =
  [Sunny; Sunny; Sunny; Rainy; Rainy; Sunny; Rainy; Rainy; Rainy; Rainy]
``` 

However, I wasn’t very happy with this solution. It works, but the random number sequence is completely tied to the simulation, whereas I would much prefer to have the two separate – if only to be able to test or replay specific random number sequences and validate that the simulation is doing what it should.

Via [StackOverflow](http://stackoverflow.com/questions/5615184/sequence-constructed-from-the-previous-element-of-the-sequence-and-another-sequen), I came upon a cleaner approach, using [`Sequence Scan`](http://msdn.microsoft.com/en-us/library/ee340364.aspx), which combines some of the aspects of Map and Unfold all in one. Scan takes 3 arguments: a function which generate the next state using each element of an input sequence, an initial state, and a sequence. Exactly what we need. In our case, here is how it looks:

``` fsharp
let Days firstDay probas =
    List.scan (fun day proba -> NextDay day proba) firstDay probas
``` 

probas will be a sequence of probabilities, firstDay is the initial `Weather`, and the function takes a day (the current state), a proba, pulled from the sequence of probabilities, and applies the `NextDay` function we defined above.

We can now directly use this to apply any sequence of probabilities to our weather model, and simulate the results. We can generate an infinite sequence of days, and take a sample of any length, like this:

``` fsharp
> open System

type Weather = Sunny | Rainy

let NextDay today proba =
    match today with
    | Rainy -> if proba < 0.7 then Rainy else Sunny
    | Sunny -> if proba < 0.6 then Sunny else Rainy

let Days firstDay probas =
    Seq.scan (fun day proba -> NextDay day proba) firstDay probas

let RandomSequence = 
    let random = new Random()
    seq {
    while true do
        yield random.NextDouble()
    };;

type Weather =
  | Sunny
  | Rainy
val NextDay : Weather -> float -> Weather
val Days : Weather -> seq<float> -> seq<Weather>
val RandomSequence : seq<float>

> let sample = Days Sunny RandomSequence |> Seq.take 5 |> Seq.toList;;

val sample : Weather list = [Sunny; Sunny; Sunny; Sunny; Sunny]
``` 

To verify that the model is behaving properly, we can pass in pre-determined sequences of probabilities, and check that the transitions are happening as expected:

``` fsharp
> let test = [0.9; 0.1; 0.9; 0.1]
let testSeq = List.toSeq test
let days = Days Sunny testSeq |> Seq.toList;;

val test : float list = [0.9; 0.1; 0.9; 0.1]
val testSeq : seq<float> = [0.9; 0.1; 0.9; 0.1]
val days : Weather list = [Sunny; Rainy; Rainy; Sunny; Sunny]
``` 

That’s it for today. At that point, I am not sure where I’ll go next with this. I would like to see if I can make the model a bit mode generic, by replacing the `Weather` type and `NextDay` function by a general `State`, and a function handling transitions between States. I would also like if possible to be a bit more specific about the fact that the input should be a sequence of probabilities, and not any float. And as always, comments and suggestions are welcome!
