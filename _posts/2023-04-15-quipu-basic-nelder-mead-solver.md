---
layout: post
title: Quipu, a simple Nelder Mead solver in F#
tags:
- F#
- Algorithms
- Optimization
---

Some time back, I wrote a small post digging into the 
[mechanics behind the Nelder Mead solver][2]. As it turns out, I had a use for 
it recently, and after copy-pasting my own code a few times, I figured it would 
make my life easier to turn that into a [NuGet package, Quipu][3].  

So what does it do, and why might you care?  

A code example might be the quickest explanation here. Suppose that, for 
whatever reason, you were interested in the function `f(x) = x ^ 2`, and wanted 
to know for what value of `x` this function reaches its minimum.  

That is easy to solve with the Quipu Nelder-Mead solver:  

``` fsharp
open Quipu
open Quipu.NelderMead

let f x = x ** 2.0
let solution =
    NelderMead.solve Configuration.defaultValue (Objective.from f) [ 100.0 ]
printfn $"{solution}"
```

... which produces the following result:

```
Optimal (0.0001556843433, [|0.01247735322|])
```

The function `f` reaches a minimum of `0.0001`, for `x = 0.0124`.

<!--more-->

`NelderMead.solve` expects 3 arguments:
- The `Configuration` describes how the solver should behave,
- The `Objective` is the function we are trying to minimize,
- The starting value, `[ 100.0 ]`, is our initial guess.

Now the mathematically inclined reader might point out that surely, this is 
not correct. `f` reaches a minimum of `0.0`, for `x = 0.0`. The 
[Nelder-Mead algorithm][4] is a numerical method which will produce an 
approximation for the answer.  

If the accuracy is insufficient, you can set up a tighter tolerance:  

``` fsharp
let config = {
    Configuration.defaultValue with
        Termination = {
            Tolerance = 0.000_0001
            MaximumIterations = None
        }
    }

let closerSolution =
    NelderMead.solve config (Objective.from f) [ 100.0 ]

printfn $"{closerSolution}"
```
```
Optimal (6.663562871e-08, [|0.000258138778|])
```

This is closer, and the minimum value, `6.663e-8`, is within `0.000_0001`, or 
`1e-07`, of the correct answer, `0.0`.

While we are discussing caveats, Nelder-Mead is not guaranteed to find the 
global minimum. It might give you a local minimum only.  

So what would happen if we gave the solve a function that does not have a 
minimum, like `f(x) = x`?

``` fsharp
let f x = x
let solution =
    NelderMead.solve 
        Configuration.defaultValue
        (Objective.from f) [ 100.0 ]
printfn $"{solution}"
```
```
Unbounded
```

In circumstances where abnormal situations are encountered (for instance, `nan` 
value during the search), the solver will return `Abnormal`, with the values 
that caused the error.  

What if you had a more complicated function, say, `g(x, y) = sin x * cos y`?  

``` fsharp
let g (x, y) = sin x * cos y
let solution =
    NelderMead.solve 
        Configuration.defaultValue
        (Objective.from g) [ 0.0; 0.0 ]
printfn $"{solution}"
```

```
Optimal (-0.9995738601, [|-1.59440106; -0.01718172454|])
```

Note how the starting value is now `[ 0.0; 0.0 ]`. Because `g` expects 2 
arguments, we need to provide an initial value for both.  

Functions of 3 arguments follow the same pattern. After 4, you are on your own, 
and will need to do a little manual wrapping, converting the function into a 
form `Objective.from` can handle: `(int: dimension, f: float [] -> float)`, 
like so:  

``` fsharp
// convert f(a,b,c,d) = sin a + cos b + (c * d) ^ 2
// into a function that takes an array of floats:
let h (args: float[]) =
    sin args.[0] + cos args.[1] + (args.[2] * args.[3]) ** 2.0

// call Objective.from (4, h), where 4 is the dimension,
// that is, the number of arguments we expect in the array:
let solution =
    NelderMead.solve
        Configuration.defaultValue
        (Objective.from (4, h)) [ 0.0; 0.0; 0.0; 0.0 ]
printfn $"{solution}"
```

```
Optimal
  (-1.99962865, [|-1.559102568; 3.117602262; 0.7363555181; 0.005298690767|])
```

And... that's what I got at the moment! It is version `0.1.0` for a reason: it 
works on my machine, for the problem I needed it for. There is obviously quite 
a bit that can be improved around usability, too. So your mileage may vary, tut 
it was useful to me, so I figured I would share!  

If you have comments or questions, hit me up on [Mastodon][5]!

[Full code here on GitHub][1]

[1]: https://github.com/mathias-brandewinder/Quipu/tree/e03bc510a298202536c06d48ed32a433e54cc012
[2]: https://brandewinder.com/2022/03/31/breaking-down-Nelder-Mead/
[3]: https://www.nuget.org/packages/Quipu
[4]: https://en.wikipedia.org/wiki/Nelder%E2%80%93Mead_method
[5]: https://hachyderm.io/@brandewinder
