---
layout: post
title: Study notes&#58; constraints in Quipu Nelder-Mead solver
tags:
- F#
- Optimization
- Algorithms
use_math: true
---

In my previous post, I went over the recent changes I made to my 
[F# Nelder-Mead solver, Quipu][1]. In this post, I want to explore how I could 
go about handling constraints in Quipu.  

First, what do I mean by constraints? In its basic form, the solver takes a 
function, and attempts to find the set of inputs that minimizes that function. 
Lifting the example from the previous post, you may want to know what values of 
$(x,y)$ produce the smallest value for $f(x,y)=(x-10)^2+(y+5)^2$. The solution 
happens to be $(10,-5)$, and Quipu solves that without issues:  

``` fsharp
#r "nuget: Quipu, 0.2.0"
open Quipu.NelderMead

let f (x, y) = (x - 10.0) ** 2.0 + (y + 5.0) ** 2.0
NelderMead.minimize f
|> NelderMead.solve

val it: Solution = Optimal (2.467079917e-07, [|9.999611886; -4.999690039|])
```

However, in many situations, not every value will do. There might be 
restrictions on what values are valid, such as "x must be positive", or "y must 
be less than 2". These are known as **constraints**, and typically result in 
an inequality constraint, in our case something like $g(x,y) \leq 0$. How could 
we go about handling such constraints in our solver?  

<!--more-->

In this post, I will look into some possible approaches to minimize a function 
under a set of constraints. I will do it the hard way, manually, hoping that 
the exercise will provide some direction on how to modify the library to make 
that easy in the future.  

## First take: a crude penalty

Let's keep the original function, $f(x,y)=(x-10)^2+(y+5)^2$, but imagine that 
we have one constraint: $x \leq 5$. Our original solution $(10,-5)$ is not 
valid in that case: $x > 5$, or, in technical terms, the constraint is not 
satisfied.  

For any value of $x > 5$, we have a problem. One approach here is to add a 
penalty to our function, such that any value that does not satisfy a constraint 
will cause the objective to increase. In that case, the Nelder-Mead solver will 
avoid movements towards these values. Let's try that:  

``` fsharp
let g (x, y) =
    f (x, y)
    +
    // we incorporate the constraint in the objective
    (if x <= 5.0 then 0.0 else infinity)
```

We keep the original objective function, $f$, but we add in a penalty term as 
well, creating a modified objective function, $g$. If the constraint is not 
satisfied, apply a penalty of $+\infty$, otherwise ignore the constraint and 
simply return $0$. Does this work?  

``` fsharp
let solution1 =
    g
    |> NelderMead.minimize
    |> NelderMead.solve

val it: Solution = Optimal (25.00000157, [|4.999999857; -5.000363939|])
```

It does! The optimal solution is now $(5,-5)$, which does indeed satisfy the 
constraint. We could easily expand on this idea, adding a penalty function for 
any other constraint we might have.  

Are we done, then? Well, not quite. By default, Quipu will start its search 
around $0$, here $(0,0)$. However, what happens if we started around, say, 
$(20,0)$?  

``` fsharp
let problem =
    g
    |> NelderMead.minimize
    |> NelderMead.startFrom (StartingPoint.fromValue [ 20.0; 0.0 ])
    |> NelderMead.solve
```

Sadly, the solver goes into an endless loop that never terminates. The problem 
here is that when we start around $(20,0)$, we are in a region where the 
constraint is not satisfied. Every search direction results in $+\infty$, and 
the solver has nowhere to go - every direction looks equally bad.  

In other words, if we happen to start from a position where constraints are not 
satisfied, we are going to run into trouble.  

Another related problem: this approach will not work well to handle equality 
constraints. Besides inequality constraints, a common constraint type is an 
equality. For instance, we might want something like $x+y=20$.  

A common trick in optimization to handle equality constraints is to turn them 
into 2 inequalities. A perhaps counter-intuitive way to state $x+y=20$ is the 
following: $x+y \leq 20$ and $x+y \geq 20$. While this might appear weird, it 
is convenient. If we can handle inequality constraints, we get equality 
constraints for free, by converting equalities into pairs of inequalities.  

However, this will be causing our penalty function issues. By definition, 
unless we are exactly on the values that satisfy our constraint, one of the two 
inequalities will result in a penalty of $+\infty$. Like in the previous 
situation we discussed, every move by the solver will look equally terrible.  

## Second take: better penalties

So what can we do? One approach is to use a progressive penalty. We want a 
function that will return $0$ when the constraint is satisfied, and a value 
that becomes increasingly larger as we move further away from it being 
satisfied.  

We could for instance do something like this:  

``` fsharp
let simplePenalty (x, y) =
    f (x, y)
    +
    (if x <= 5.0 then 0.0 else ((x - 5.0) ** 2.0))
```

Now the penalty term will return $0$ if the constraint is satisfied, and 
$(x-5)^2$ otherwise. For values close to $5$, the penalty will be small, but as 
$x$ moves further away from $5$, the penalty will become steeper and steeper.  

Let's try this out, starting our search from the point that was giving us 
trouble before, $(20,0)$:  

``` fsharp
simplePenalty
|> NelderMead.minimize
|> NelderMead.startFrom (StartingPoint.fromValue [ 20.0; 0.0 ])
|> NelderMead.solve

val it: Solution = Optimal (12.50000014, [|7.500152792; -4.999694746|])
```

Does this work? Well, sort of, but not really. On the one hand, the solver does 
not get stuck, and returns an optimal solution, $(7.5,-5)$. On the other hand, 
the solution is neither optimal (it should be $(5,-5)$), nor the constraint 
satisfied either ($7.5 > 5$). Instead of no answer, we get a pretty bad answer.  

The issue here is that the constraint is "soft". A minor violation of the 
constraint will result in a small penalty. In other words, if our solution does 
not satisfy the constraint, but is close to the limit, the penalty is small 
enough to be acceptable, so to speak.  

What we could do then is make the penalty steeper. Let's make it 100 times 
steeper:  

``` fsharp
let steeperPenalty (x, y) =
    f (x, y)
    +
    (if x <= 5.0 then 0.0 else 100.0 * ((x - 5.0) ** 2.0))

val it: Solution = Optimal (24.75247568, [|5.049540943; -5.000552666|])
```

Still not quite right, but much better. How about 10,000 steeper?  

``` fsharp
Optimal (24.99750049, [|5.000501938; -4.999554925|])
```

As we crank up the aggressiveness of the penalty, we get solutions that are 
closer and closer to the correct answer. This suggests a possible strategy: 
solve iteratively, starting with a soft constraint, and make it progressively 
steeper, until we are close enough.

Here is a quick sketch of how this might look like. First, we create a penalty 
that takes in a coefficient, describing how aggressive the penalty is:  

``` fsharp
let penalty coeff =
    let f (x, y) =
        f (x, y)
        +
        (if x <= 5.0 then 0.0 else coeff * ((x - 5.0) ** 2.0))
    f
```

Then, we solve our problem, starting with a coefficient of 1, and increasing it 
by a factor 10 each iteration, starting from the solution identified during the 
previous pass:  

``` fsharp
let rec solve (i: int, startingPoint: seq<float>) =
    printfn $"Iteration {i}"
    let coeff = 10.0 ** i
    let solution =
        penalty coeff
        |> NelderMead.minimize
        |> NelderMead.startFrom (StartingPoint.fromValue startingPoint)
        |> NelderMead.solve
    if i >= 5
    then solution
    else
        let nextStart =
            match solution with
            | Optimal (_, x) -> x
            | _ -> failwith "Ooops"
        printfn $"{List.ofArray nextStart}"
        solve (i + 1, nextStart)

solve (0, [ 20.0; 0.0 ])
```

```
Iteration 0
[7.500152791643328; -4.999694746077196]
Iteration 1
[5.454595839229248; -4.999507451495937]
Iteration 2
[5.049548981640678; -5.000000777860209]
Iteration 3
[5.00499712795882; -5.000337947630191]
Iteration 4
[5.000501780625028; -5.000266170674201]
Iteration 5
```

This is a sketch, and would need some refinements. In particular, stopping 
after 5 iterations is totally arbitrary. We should probably stop once the 
constraints are all within certain bounds (and figure out pesky details like 
what to do if we never manage to satisfy the constraints...).  

With that caveat, things do appear to work as expected. As we make the 
constraint iteratively stiffer, $x$ gets progressively closer and closer to 
$5$. I also tried out an equality constraint, and the results were what I expected.  

For the sake of completeness, I also need to point out an odd result. If you 
run the algorithm for a little longer, you might observe that the $y$ values 
oscillate between $5$ and $4.06$. I am not sure what is going on at that point. 

## Parting words

As I was doing some reading on constrained optimization, I came across another 
approach, barrier functions. Where penalty functions add a penalty to the 
objective when a constraint is not satisfied, barrier functions create a 
penalty inside the feasible domain. The closer you approach a penalty, the 
steeper the penalty.  

This is an interesting approach, but after some thinking, I believe it won't 
work for Nelder-Mead. A barrier should work well if the search algorithm relies 
on gradients, because the step size depends on the gradient. However, 
Nelder-Mead does not rely on gradients (which is one of its advantages). While 
the step direction depends on the function, the step size depends only on the 
geometry of the current simplex. As a result, a barrier would have no direct 
impact: the standard algorithm could still take steps leading outside of the 
feasible domain, where all constraints are satisfied, and we would encounter 
the same exact issue we had with our original, crude penalty function.  

I imagine you could modify the algorithm to perhaps take more adaptive steps, 
but in the meantime, the penalty direction seems more promising. I will 
probably take a stab at incorporating constraints in the current solver using 
penalties in the next few weeks - we'll see how that goes!

In the meantime, you can find the current code here:  

[<i class="fa-brands fa-github"></i>Code on GitHub][2].

[1]: https://brandewinder.com/2023/11/11/quipu-nelder-mead-solver-version-0-2/
[2]: https://github.com/mathias-brandewinder/Quipu/tree/e7f5294fc2aef26c5c4171d449edfe53e8f0e38b