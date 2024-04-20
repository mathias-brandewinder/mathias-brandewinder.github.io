---
layout: post
title: Quipu 0.2.2, a Nelder-Mead solver with a side of NaN
tags:
- F#
- Optimization
- Algorithms
use_math: true
---

The main reason I created [Quipu][1] is that I needed a Nelder-Mead solver for a 
real-world project. And, as I put Quipu through its paces on real-world data, 
I ran into some issues, revolving around "Not a Number" floating point values, 
aka `NaN`.  

> tl;dr: the latest release of [Quipu, version 0.2.2][2], available on 
[nuget][3], should handle `NaN` values decently well, and has some minor 
performance improvements, too.  

In this post, I will go over some of the changes I made, and why. Fixing the 
main issue made me realize that I didn't know floating point numbers as well as 
I thought, even though I have been using them every working day for years. I 
will take some tangents to discuss some of my learnings.  

So let's dig in. My goal with Quipu was to implement the 
[Nelder-Mead algorithm in F#][4]. The purpose of Nelder-Mead is to find a 
numeric approximation of values that minimize a function. As an illustration, 
if we took the function $f(x) = x ^ 2$, we would like to know what value of $x$ 
produces the smallest possible value for $f(x)$, which happens to be $x = 0$ in 
this case.  

Quipu handles that case just fine:  

``` fsharp
open Quipu.NelderMead

let f x = x ** 2.0
f
|> NelderMead.minimize
|> NelderMead.solve

val it: Solution = Optimal (0.0, [|0.0|])
```

So far, so good. Now, what about a function like $f(x) = \sqrt{x}$?  

That function is interesting for 2 reasons:  
- $f(x)$ has a minimum, for $x = 0$.  
- $f(x)$ is defined only for $x \ge 0$: it is a partial function.  

Sadly, the previous version of Quipu, version 0.2.1, failed to find it. It 
would go into an infinite loop instead.  

<!--more-->

## The Weird World of Floating Point Numbers

Why is that? Assuming we are working with real numbers (as opposed to imaginary 
ones), from the mathematician standpoint, the function $\sqrt{x}$ is not 
defined for strictly negative real numbers. Negative numbers are not 
part of the [function domain][5]: a negative number is not a "valid input", and so 
there is no output for such a number.  

However, in code, we don't work with real numbers. We use floating point 
numbers. As a result, this will run:  

``` fsharp
> sqrt -1.0;;
val it: float = nan
```

From that standpoint, `nan`, or Not a Number, could be thought of as an 
implicit encoding of the function domain of definition. Where a mathematician 
would say "$f$ is defined only for this subset of real numbers", with floating 
point numbers, we have "if $f(x) = nan$, then $x$ is not part of the domain of 
definition".  

At first glance, one would think that floating point 
numbers are more or less equivalent to real numbers. However, floating point 
numbers are an interesting beast. If you look up [`System.Double`][6], you will 
notice a few fields:  

- `NaN`
- `PositiveInfinity`, `NegativeInfinity`
- `MaxValue`, `MinValue`

`PositiveInfinity` and `NegativeInfinity` are sensible, and correspond to the 
extended real number line.  

`MaxValue` and `MinValue` make sense from a practical standpoint, but are 
amusing:  

``` fsharp
> let x = System.Double.MaxValue;;
val x: float = 1.797693135e+308
> x = x + 1.0;;
val it: bool = true
> x + x
val it: float = infinity
```

... which reminded me of [this toot][7]:  

<iframe src="https://mathstodon.xyz/@andrewt/111850193169329487/embed" width="400" allowfullscreen="allowfullscreen" sandbox="allow-scripts allow-same-origin allow-popups allow-popups-to-escape-sandbox allow-forms"></iframe>


> As a side note, I could not quite figure out what the rules were to go from 
`MaxValue` to `PositiveInfinity`.  

But the one that is really interesting is `NaN`. If floating point numbers were 
representing real numbers, then by definition `NaN` could not be part of it, 
because, well, `NaN` is not a number. `NaN` makes the whole idea of floats 
representing reals a very weird can of worms. For instance, what are we saying 
when we write, for instance, `NaN + NaN`? How is that akin to a real number?  

So `NaN` is weird, but it is also convenient. Contrast floats with integers: 
where ```1 / 0``` will throw an expensive exception, ```1.0 / 0.0``` will 
return `NaN`, fast. Speed is good - the price we have to pay for it is, it is 
up to us to remember that floats are a lie that could result in `NaN` 
potentially anywhere, and it is up to us to deal with it.  

My mental picture for floats at that point is that they are not that far off an 
`Option` type, where `NaN` is the `None` case, and everything else is a 
"proper number". Overall, they propagate through float function in a way that 
is similar to `Option.map`: once a `NaN` enters the flow of calculations, it 
will flow through and remain a `NaN`.  

> This is not entirely true. An odd tidbit of floating point trivia: 
`nan ** 0.0` is equal to... `1.0`. While it is true that any real number raised 
to the power 0 is 1, why `NaN` has been included here is a little bizarre!  

Anyways, after this long digression on floating point numbers, let's go back to 
the original topic, the solver bug. If you are interested in the topic of 
floats, I enjoyed reading this section on the [design rationale of IEEE 754][8].

## The bug and the fix

So to summarize the long meandering tangent above: floating point numbers `NaN` 
signal that a function inputs are outside of its domain of definition, and can 
arise anywhere floating point calculations are involved.  

In the case of the Nelder-Mead algorithm, this is something we want to take 
into account, in case the function we are trying to minimize is partially 
defined, like $f(x) = \sqrt{x}$.  

We can break down how the algorithm works in a few steps:  

1) It maintains a set of candidate points, the simplex,  

2) It tries to replace the worst point with a better one, to move to a "more 
promising search area",  

3) If that fails, the points are possibly surrounding the optimum value, so it 
shrinks them towards the best candidate and narrows down the "search area",  

4) When the "search area" is small enough, it stops the search.  

If, as in the case of $f(x) = \sqrt{x}$, the function is partially defined, we 
will run into a couple of issues. We cannot reach step (3), because if we have 
points around 0 (the optimum value), then some points will be negative. These 
points will be outside the domain of definition (`NaN`), and we won't be able 
to evaluate if that point is better or worse than others.  

In other words, we need to ensure that at every step, every point in our 
simplex remains within the domain of definition, so we can evaluate whether it 
is better or worse.  

This also means that our simplex will never be surrounding the optimum value. 
However, assuming the function is not too degenerate, it can work at finding a 
local minumum. Instead of finding a good area and shrinking, it will move 
towards a better area, until it gets too close to the boundaries of the domain, 
shrink, then move again closer towards the optimum, taking a smaller step, and 
possibly get close enough to the optimum to stop.  

One interesting aspect of Nelder-Mead is how the steps are taken. Where a 
method like gradient descent decides on the direction and amplitude of the step 
based on the objective function, Nelder-Mead proceeds differently:  

1) It tries a few candidate steps that depend only on the simplex. The direction 
and amplitude of the step does not depend on the objective function.  

2) It evaluates each candidate step using the objective function.  

This is helpful. It implies that all we have to do is make sure that in (2) we 
never take a step outside of the domain of definition, which only requires 
checking that the value of the objective function is not `NaN`.

Another potential issue is making sure that the simplex itself always remains 
"clean", that is, we need to ensure that points in the simplex never contains 
`NaN` values. The nice thing here is that, if you look at the way the candidate 
steps are computed, they are all linear combinations of the simplex points. As 
adding and multiplying numbers that are not `NaN` will always produce a value 
that is not `NaN`, all we need to do is check once that the initial values 
contain no `NaN`. If that is the case, then mechanically every step taken will 
also result in a `NaN`-free simplex.  

And that is pretty much what I did. I added a pre-check to enforce a valid 
initial simplex, and tracked down every evaluation of the objective function, 
removing candidate steps that would lead outside of the domain of definition.  

Does it work? I am pretty sure it will not always work (Nelder-Mead does not 
guarantee a global optimum anyways), but it does work on some examples, like 
our starting problem:  

``` fsharp
let f x = sqrt x
f
|> NelderMead.minimize
|> NelderMead.startFrom (StartingPoint.fromValue [ 1.0 ])
|> NelderMead.solve

val it: Solution = Optimal (1.490116119e-08, [|2.220446049e-16|])
```

That's what I got for today! Hope you found something interesting in this post.
If you are interested in the code or the specific changes I made, you can find 
it on [GitHub][1]. Cheers!

[1]: https://github.com/mathias-brandewinder/Quipu
[2]: https://github.com/mathias-brandewinder/Quipu/releases/tag/0.2.2
[3]: https://www.nuget.org/packages/Quipu
[4]: https://en.wikipedia.org/wiki/Nelder%E2%80%93Mead_method
[5]: https://en.wikipedia.org/wiki/Domain_of_a_function
[6]: https://learn.microsoft.com/en-us/dotnet/api/system.double?view=net-8.0
[7]: https://mathstodon.xyz/@andrewt/111850193169329487
[8]: https://en.wikipedia.org/wiki/IEEE_754#Design_rationale