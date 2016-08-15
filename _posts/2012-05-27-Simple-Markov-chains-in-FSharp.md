---
layout: post
title: Simple Markov chains in F#
tags:
- F#
- Markov
- Simulation
- Probability
- Sequence
- Array
- Fixed-Point
---

![A A Markov]({{ site.url }}/assets/2012-05-27-AAMarkov.jpg)

[Markov chains](http://en.wikipedia.org/wiki/Markov_chain) are a classic in probability model. They represent systems that evolve between states over time, following a random but stable process which is memoryless. The memoryless-ness is the defining characteristic of Markov processes,&#160; and is known as the Markov property. Roughly speaking, the idea is that if you know the state of the process at time T, you know all there is to know about it – knowing where it was at time T-1 would not give you additional information on where it may be at time T+1.  

While Markov models come in multiple flavors, Markov chains with finite discrete states in discrete time are particularly interesting. They describe a system which is changes between discrete states at fixed time intervals, following a transition pattern described by a transition matrix.  

Let’s illustrate with a simplistic example. Imagine that you are running an Airline, AcmeAir, operating one plane. The plane goes from city to city, refueling and doing some maintenance (or whatever planes need) every time.  

Each time the plane lands somewhere, it can be in three states: early, on-time, or delayed. It’s not unreasonable to think that if our plane landed late somewhere, it may be difficult to catch up with the required operations, and as a result, the likelihood of the plane landing late at its next stop is higher. We could represent this in the following transition matrix (numbers totally made up):  

Current \ Next | Early | On-time | Delayed 
--- | --- | --- | ---
Early | 10% | 85% | 5% 
On-Time | 10% | 75% | 15% 
Delayed | 5% | 60% | 35% 

<!--more-->

Each row of the matrix represents the current state, and each column the next state. The first row tells us that if the plane landed Early, there is a 10% chance we’ll land early in our next stop, an 80% chance we’ll be on-time, and a 5% chance we’ll arrive late. Note that each row sums up to 100%: given the current state, we have to end up in one of the next states.  

How could we simulate this system? Given the state at time T, we simply need to “roll” a random number generator for a percentage between 0% and 100%, and depending on the result, pick our next state – and repeat.   

Using F#, we could model the transition matrix as an array (one element per state) of arrays (the probabilities to land in each state), which is pretty easy to define using [Array comprehensions](http://en.wikibooks.org/wiki/F_Sharp_Programming/Arrays#Array_comprehensions)

``` fsharp
let P = 
   [| 
      [| 0.10; 0.85; 0.05 |];
      [| 0.10; 0.75; 0.15 |];
      [| 0.05; 0.60; 0.35 |]
   |]
``` 

*Note: the entire code sample is also posted on [fsSnip.net](http://fssnip.net/ch)*

To simulate the behavior of the system, we need a function that given a state and a transition matrix, produces the next state according to the transition probabilities:

``` fsharp
// given a roll between 0 and 1
// and a distribution D of 
// probabilities to end up in each state
// returns the index of the state
let state (D: float[]) roll =
   let rec index cumul current =
      let cumul = cumul + D.[current]
      match (roll <= cumul) with
      | true -> current
      | false -> index cumul (current + 1)
   index 0.0 0

// given the transition matrix P
// the index of the current state
// and a random generator,
// simulates what the next state is
let nextState (P: float[][]) current (rng: Random) =
   let dist = P.[current]
   let roll = rng.NextDouble()
   state dist roll

// given a transition matrix P
// the index i of the initial state
// and a random generator
// produces a sequence of states visited
let simulate (P: float[][]) i (rng: Random) =
   Seq.unfold (fun s -> Some(s, nextState P s rng)) i
``` 

The `state` function is a simple helper; given an array D which is assumed to contain probabilities to transition to each of the states, and a “roll” between 0.0 and 1.0, returns the corresponding state. `nextState` uses that function, by first retrieving the transition probabilities for the current state i, “rolling” the dice, and using state to compute the simulated next state. `simulate` uses `nextState` to create an infinite sequence of states, starting from an initial state i.

We need to `open System` to use the `System.Random` class – and we can now use this in the F# interactive window:

``` fsharp
> let flights = simulate P 1 (new Random());;

val flights : seq<int>

> Seq.take 50 flights |> Seq.toList;;

val it : int list =
  [1; 0; 1; 1; 1; 1; 1; 1; 1; 1; 1; 1; 1; 0; 1; 1; 2; 2; 2; 1; 1; 1; 1; 1; 1;
   1; 1; 2; 1; 1; 1; 1; 1; 1; 1; 1; 2; 1; 1; 1; 1; 1; 2; 1; 1; 1; 1; 1; 1; 1]
>
``` 

Our small sample shows us what we expect: mostly on-time (Fly AcmeAir!), with some episodical delayed or early flights.

How many delays would we observe on a 1000-flights simulation? Let’s try:

``` fsharp
> Seq.take 1000 flights |> Seq.filter (fun i -> i = 2) |> Seq.length;; 
val it : int = 174
> 
``` 

We observe about 17% of delayed flights. This is relevant information, but a single simulation is just that – an isolated case. Fortunately, Markov chains have an interesting property: if it is possible to go from any state to any state, then the system will have a stationary distribution, which corresponds to its long term equilibrium. Essentially, regardless of the starting point, over long enough periods, each state will be observed with a stable frequency.

One way to understand better what is going on is to expand our frame. Instead of considering the exact state of the system, we can look at it in terms of probability: at any point in time, the system has a certain probability to be in each of its states.

For instance, imagine that given current information, we know that our plane will land at its next stop either early or on time, with a 50% chance of each. In that case, we can determine the probability that its next stop will be delayed by combining the transition probabilities:

```
p(delayed in T+1) = p(delayed in T) x P(delayed in T+1 | delayed in T) +&#160; p(on-time in T) x P(delayed in T+1 | on-time in T) + p(early in T) x P(delayed in T+1 | early in T)

p(delayed in T+1) = 0.0 x 0.35 + 0.5 x 0.15 + 0.5 x 0.05 = 0.1
```

This can be expressed much more concisely using Vector notation. We can represent the state as a vector S, where each component of the vector is the probability to be in each state, in our case

```
S(T) = [ 0.50; 0.50; 0.0 ]
```

In that case, the state at time T+1 will be:

```
S(T+1) = S(T) x P
```

Let’s make that work with some F#. The product of a vector by a matrix is the [dot-product](http://en.wikipedia.org/wiki/Dot_product) of the vector with each column vector of the matrix:

``` fsharp
// Vector dot product
let dot (V1: float[]) (V2: float[]) =
   Array.zip V1 V2
   |> Array.map(fun (v1, v2) -> v1 * v2)
   |> Array.sum

// Extracts the jth column vector of matrix M 
let column (M: float[][]) (j: int) =
   M |> Array.map (fun v -> v.[j])

// Given a row-vector S describing the probability
// of each state and a transition matrix P, compute
// the next state distribution
let nextDist S P =
   P 
   |> Array.mapi (fun j v -> column P j)
   |> Array.map(fun v -> dot v S)
``` 

We can now handle our previous example, creating a state s with a 50/50 chance of being in state 0 or 1:

``` fsharp
> let s = [| 0.5; 0.5; 0.0 |];;

val s : float [] = [|0.5; 0.5; 0.0|]

> let s' = nextDist s P;;

val s' : float [] = [|0.1; 0.8; 0.1|]

> 
``` 

We can also easily check what the state of the system should be after, say, 100 flights:

``` fsharp
> let s100 = Seq.unfold (fun s -> Some(s, nextDist s P)) s |> Seq.nth 100;;

val s100 : float [] = [|0.09119496855; 0.7327044025; 0.1761006289|]
``` 

After 100 flights, starting from either early or on-time, we have about 17% of chance of being delayed. Note that this is consistent with what we observed in our initial simulation. Given that our Markov chain has a stationary distribution, this is to be expected: unless our simulation was pathologically unlikely, we should observe the same frequency of delayed flights in the long run, no matter what the initial starting state is.

Can we compute that stationary distribution? The typical way to achieve this is to bust out some algebra and solve `V = P x V`, where `V` is the stationary distribution vector and `P` the transition matrix.

Here we’ll go for a numeric approximation approach. Rather than solving the system of equations, we will start from a uniform distribution over the states, and apply the transition matrix until the distance between two consecutive states is under a threshold Epsilon:

``` fsharp
// Euclidean distance between 2 vectors
let dist (V1: float[]) V2 =
   Array.zip V1 V2
   |> Array.map(fun (v1, v2) -> (v1 - v2) * (v1 - v2))
   |> Array.sum
   
// Evaluate stationary distribution
// by searching for a fixed point
// under tolerance epsilon
let stationary (P: float[][]) epsilon =
   let states = P.[0] |> Array.length
   [| for s in 1 .. states -> 1.0 / (float)states |] // initial
   |> Seq.unfold (fun s -> Some((s, (nextDist s P)), (nextDist s P)))
   |> Seq.map (fun (s, s') -> (s', dist s s'))
   |> Seq.find (fun (s, d) -> d < epsilon)
``` 

Running this on our example results in the following stationary distribution estimation:

``` fsharp
> stationary P 0.0000001;;
val it : float [] * float =
  ([|0.09118958333; 0.7326858333; 0.1761245833|], 1.1590625e-08)
``` 

In short, in the long run, we should expect our plane to be early 9.1% of the time, on-time 73.2%, and delayed 17.6%.

*Note: the fixed point approach above should work if a unique stationary distribution exists. If this is not the case, the function may never converge, or may converge to a fixed point that depends on the initial conditions. Use with caution!*

Armed with this model, we could now ask interesting questions. Suppose for instance that we could improve the operations of AcmeAir, and reduce the chance that our next arrival is delayed given our current state. What should we focus on – should we reduce the probability to remain delayed after a delay (strategy 1), or should we prevent the risk of being delayed after an on-time landing (strategy 2)?

One way to look at this is to consider the impact of each strategy on the long-term distribution. Let’s compare the impact of a 1-point reduction of delays in each case, which we’ll assume gets transferred to on-time. We can then create the matrices for each strategy, and compare their respective stationary distributions:

``` fsharp
> let strat1 = [|[|0.1; 0.85; 0.05|]; [|0.1; 0.75; 0.15|]; [|0.05; 0.61; 0.34|]|]
let strat2 = [|[|0.1; 0.85; 0.05|]; [|0.1; 0.76; 0.14|]; [|0.05; 0.60; 0.35|]|];;

val strat1 : float [] [] =
  [|[|0.1; 0.85; 0.05|]; [|0.1; 0.75; 0.15|]; [|0.05; 0.61; 0.34|]|]
val strat2 : float [] [] =
  [|[|0.1; 0.85; 0.05|]; [|0.1; 0.76; 0.14|]; [|0.05; 0.6; 0.35|]|]

> stationary strat1 0.0001;;
val it : float [] * float =
  ([|0.091; 0.7331333333; 0.1758666667|], 8.834666667e-05)
> stationary strat2 0.0001;;
val it : float [] * float = ([|0.091485; 0.740942; 0.167573|], 1.2698318e-05)
> 
``` 

The numbers tell the following story: strategy 2 (improve reduction of delays after on-time arrivals) is better: it results in 16.6% delays, instead of 17.6% for strategy 1. Intuitively, this makes sense, because most of our flights are on-time, so an improvement in this area will have a much larger impact in the overall results that a comparable improvement on delayed flights.

There is (much) more to Markov chains than this, and there are many ways the code presented could be improved upon – but I’ll leave it at that for today, hopefully you will have picked up something of interest along the path of this small exploration!

I also posted the complete code sample on [fsSnip.net/ch](http://fssnip.net/ch).
