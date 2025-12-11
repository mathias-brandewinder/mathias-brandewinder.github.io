---
layout: post
title: "Adding Goal Seek to Quipu (and helping Santa with it!)"
tags:
- F#
- Algorithms
- Optimization
use_math: true
---

> This post is part of the [F# Advent 2025][6] series, which already has 
bangers! Check out the whole series, and a big shout out to  
[Sergey Tihon][5] for organizing this once again!  

It is that merry time of the year again! The holidays are approaching, and in 
houses everywhere, people are happily sipping eggnogg and hanging decorations. 
But in one house, the mood is not festive. Every year on December 1st, the 
first day of Advent, Santa Claus begins wrapping gifts for 2 billion children 
worldwide, from his workshop in the North Pole. But this year, Krampus 
unexpectedly decided to impose tariffs on Greenland, throwing the supply chain 
of gifts into chaos. It is now December 11th, and Santa just received the 
goods. Santa is now 11 days behind schedule, and needs to hire many, many more 
Elves than usual to catch up. But... how many Elves does he need to hire?  

Santa runs a tight ship at Santa, Inc., and he knows that adding new Elves to 
the team won't be seamless. Bigger teams require more coordination and 
additional equipment.  

Based on available data, Santa knows that:  

- He needs to hire Elves to wrap `2,000,000,000` gifts,  
- A single Elf can wrap at most `100,000` gifts a day,  
- Instead of the normal `24` Advent days, Santa has only `13` days left,  
- A team of `n` Elves will only be able to produce `n ^ 0.8` as much as a 
single elf, that is, there are [diminishing returns to scale][1].  

> Note: the function `f(elves) = elves ^ 0.8` is largely arbitrary. It has the 
shape we want for our problem: it is always increasing (more `elves` can wrap 
more gifts), but the increase slows down gradually. For instance `f(1)=1.00`, 
whereas `f(2)=1.74`, meaning that `2` `elves` will only be able to wrap `1.74` 
as many gifts as `1` `elf`, instead of twice as many.  

Can we help Santa decide how many Elves to hire? And can we figure out how much 
the Krampus shenanigans are costing Santa, Inc.? We certainly can, and today we 
will do so using the `goalSeek` feature which we just added to [`Quipu`][2].  

<!--more-->

## Expressing the problem

What we are looking for is the number of `elves` we need so that in `13` days, 
they can wrap exactly `2` billion gifts. Let's write a `giftsWrapped` 
function first, computing how many gifts a group of `elves` can wrap over a 
given number of `days`:  

``` fsharp
let giftsPerDay = 100_000.0

let giftsWrapped (days: float) (elves: float) =
    if elves <= 0.0
    then 0.0
    else
    days * giftsPerDay * (elves ** 0.8)
```

> We guard against negative `elves` values to spare us from dealing with `nan`.  

Quick sanity checks! A single elf working a single day should be able to wrap 
`100,000` gifts:  

``` fsharp
giftsWrapped 1.0 1.0
val it: float = 100000.0
```

A single elf working 10 days should be able to wrap `1` million gifts:  

``` fsharp
giftsWrapped 10.0 1.0
val it: float = 1000000.0
```

2 elves should wrap less than `200,000` gifts in a day:  

``` fsharp
giftsWrapped 1.0 2.0
val it: float = 174110.1127
```

So far, so good. Now what we are looking for is the value of `elves` that can 
wrap `2` billion gifts over the `13` days we have left, that is, we want to 
find the value of `elves` such that  

`giftsWrapped 13.0 elves = 2_000_000_000.0`.  

## Solving the problem with Quipu

There are many ways Santa could go about solving that problem. He could do it 
visually, by plotting the `giftsWrapped` function and finding where the curve 
reaches `2` billion. He could roll up his sleeves and do some old-fashioned 
math by hand. He could do a grid search or use the [bisection method][3]. If 
Santa hadn't cancelled his Excel 365 subscription because of the constant 
Copilot AI nagging, he could use the [Excel GoalSeek function][4].  

Or, drumroll, he could use the `goalSeek` function that we just added to 
Quipu!  

``` fsharp
#r "nuget: Quipu, 1.1.0-beta1"
open Quipu

let children = 2_000_000_000.0
let advent = 24.0

giftsWrapped (advent - 11.0)
|> NelderMead.objective
|> NelderMead.goalSeek children
```

This produces the following result:  

``` fsharp
val it: SolverResult =
  Successful {
    Status = Optimal
    Iterations = 49
    Candidate = {
      Arguments = [|9635.146097|]
      Value = 2000000000.0
      }
    Simplex = [|[|9635.146097|]; [|9635.146097|]|] 
    }
```

The solver was `Successful` in its search. After `49` iterations, it found an 
`Optimal` solution, with a `Candidate` solution: `9,635` `elves` will be able 
to wrap exactly `2` billion packages in `13` days. Well, `9,635.146097` `elves` 
to be precise.    

Quick check again:  

``` fsharp
giftsWrapped 13.0 9635.146097
val it: float = 2000000000.0
```

We are good to go! As a bonus, we can also quickly check how many `elves` Santa 
would have needed, without Krampuses' shenanigans, using the full Advent period 
to wrap gifts, instead of performing a rush job in `13` days:  

``` fsharp
giftsWrapped advent
|> NelderMead.objective
|> NelderMead.goalSeek children
```

With the full `24` days of Advent, Santa would have needed only `4477` elves. 
Converted to comparable scales, instead of `24 * 4477 = 107,448` elf-days, we 
now need `13 * 9635 = 125,255` elf-days, a nearly `17%` extra. Thanks, 
Krampus!  

## How does it work?

Under the hood, `NelderMead.goalSeek` uses `NelderMead.minimize`. What 
`goalSeek` does is search for arguments `args` to a function `f` such that 
`f(args)=target`, where `target` is a user-supplied value. This can be restated 
slightly differently as `f(args)-target=0`, which we can convert to a "classic" 
minimization problem, like so: `minimize abs(f(args)-target)`. As Leonhard 
Euler would say, "Nothing takes place in the world whose meaning is not that of 
some maximum or minimum". The smallest possible value for the function 
`abs(x)` is `0`, so if the minimization succeeds, the result will be 
`abs(f(args)-target)=0`, that is, `f(args)=target`.  

This is exactly what the first part of [`Quipu.goalSeek`][7] does:  

``` fsharp
static member goalSeek (target: float) (problem: Problem) =
    { problem with
        Objective =
            { new IVectorFunction with
                member this.Dimension = problem.Objective.Dimension
                member this.Value (args: float []) =
                    abs (target - problem.Objective.Value args)
            }
    }
    |> NelderMead.minimize
```

We convert the original objective function into a new objective, 
`abs (target - problem.Objective.Value args)`, and we just let it rip.  

There is a small problem with that approach, though. As an example, what would 
happen if we tried this?  

``` fsharp
fun x -> x * x
|> NelderMead.objective
|> NelderMead.goalSeek -10.0
```

The function `fun x -> x * x` is always positive, and has a minimum for `x=0`, 
`f(0)=0`. In other words, there is no value `x` such that `f(x)=-10`. I debated 
about how to handle that situation - should the result be a failure? As of this 
version, `1.1.0-beta1`, `Quipu` will return the following result:  

``` fsharp
val it: SolverResult =
  Successful {
    Status = Suboptimal
    Iterations = 11
    Candidate = {
      Arguments = [|0.0|]
      Value = 0.0
      }
    Simplex = [|[|0.0|]; [|-0.0009765625|]|] 
    }
```

The solver declares the result `Successful`, but `Suboptimal`: the search 
completed properly, and the result is as close as we will ever get to the 
target value, but it is NOT exactly what was asked - It is the best we can do. 
I might change my mind (hence the `beta1` release), but it feels better than 
the alternative.  

A related issue ended up being less straightforward than what I expected. I 
initially thought that I could use a simpler termination rule than the regular 
minimization solver, and stop when the objective function value was 
sufficiently close to the target value. This would be much faster than the 
termination rule I use for the "regular" solver, which checks if all function 
values and arguments are within a certain tolerance. The issue, though, is 
that if there is no solution close to the target value, as in the previous 
example, then the solver will never terminate. This is obviously a problem, so 
I ended up using the original termination rule, at least for now. I might try 
to write an alternate version with an early exit if the solver has found a 
sufficiently good candidate.  

## Parting thoughts

Arguably, `goalSeek` is only a minor feature addition to `Quipu`. It is mainly 
a convenient shortcut, making something you could do manually by tinkering with 
the objective function a straightforward call. That being said, it is a useful 
function, in particular for financial calculations, and one I used regularly in 
my Excel days. And, as an added bonus, one thing it does that Excel doesn't 
(if memory serves) is handle functions with more than one argument. Whether 
that would ever be useful is up for debate, but it is a feature!  

Anyways, as always, I am all ears if you have feedback or thoughts! In the 
meantime, I wish you wonderful holidays! And again, check out the other posts 
in the [F# Advent series][6], and a big thanks to [Sergey Tihon][5] for 
organizing F# Advent again this year!  

[1]: https://en.wikipedia.org/wiki/Returns_to_scale
[2]: https://github.com/mathias-brandewinder/Quipu
[3]: https://en.wikipedia.org/wiki/Bisection_method
[4]: https://support.microsoft.com/en-us/office/use-goal-seek-to-find-the-result-you-want-by-adjusting-an-input-value-320cb99e-f4a4-417f-b1c3-4f369d6e66c7
[5]: https://sergeytihon.com/
[6]: https://sergeytihon.com/fsadvent/
[7]: https://github.com/mathias-brandewinder/Quipu/blob/0975b494ddd2898b728dcaab4e539135302808e2/src/Quipu/NelderMead.fs#L67-L90