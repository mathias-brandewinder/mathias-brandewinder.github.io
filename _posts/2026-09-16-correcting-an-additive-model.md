---
layout: post
title: "Correcting an additive correction model"
tags:
- F#
- Modeling
---

As part of a project I am working on, I ran into a small issue that, while not 
of consequence, bothered me. Being prone to obsessing over details, I ended up 
digging into it to figure out if I could address the issue. In this post, I 
will go over the solution I ended up with.  

In a nutshell, here is the problem. Suppose you are working on an application 
where you need information such as "how long does it take to go from point 
A to point B". You have an external service available, which you can call to 
get estimates. So far, so good.  

Now suppose that you look at the data, and realize that the time it takes to go 
from A to B depends on when the trip takes place. This is not entirely 
unexpected. Roads are typically busier at certain times of the day, or certain 
days of the week.  

To avoid getting bogged down in unimportant details, let's simplify a bit, and 
ignore the time of the day part. You look at the data, and notice that trips 
taking place on different days of the week behave differently.  

As an example, you might observe something like "on Mondays, trips take 1 extra 
minute on average than what the service predicts; on Sundays, trips take 2 
minutes less on average."  

An easy way to model this would be to layer a simple correction on top of the 
estimate you obtain from the service, adding an error correction value (a bias 
term), based on the day of the week, along these lines:  

``` fsharp
let driveTime (origin, destination, dateTime) =
    // use the external service to get a baseline
    let estimate = averageDriveTime(origin, destination)
    // get a correction for the day of the week
    let correction = dayCorrection dateTime
    // apply the correction
    estimate + correction
```

So for instance, a trip predicted to last 7 minutes taking place on a Sunday 
would end up being corrected to 7 minutes - 2 minutes = 5 minutes. Converserly, 
the same trip happening on a Monday would be predicted to take 7 minutes + 1 
minute = 8 minutes. Simple enough.  

<!--more-->

## What is the problem here?

While this approach is reasonable for most trips, there is a problem 
for short trips. As an obvious example, the function above would predict that a 
trip that takes 1 minute on average would take - 1 minute on Sundays. Unless 
time travel is an available option, this is clearly not possible.  

That specific problem can be solved with a trivial fix. No matter what, a trip 
will always take a positive time to complete, so let's make every trip 
positive, like so:  

```fsharp
estimate + correction |> max 0.0
```

And, because a chart is worth a thousand words, in graphic form:  

``` fsharp
#r "nuget: plotly.net, 5.1.0"
open Plotly.NET

[
    [ 0.0 .. 0.01 .. 7.0 ]
    |> List.map (fun t -> t, t + 1.0 |> max 0.0)
    |> Chart.Line
    |> Chart.withTraceInfo "Monday"

    [ 0.0 .. 0.01 .. 7.0 ]
    |> List.map (fun t -> t, t - 2.0 |> max 0.0)
    |> Chart.Line
    |> Chart.withTraceInfo "Sunday"
]
|> Chart.combine
|> Chart.withXAxisStyle "Baseline"
|> Chart.withYAxisStyle "Corrected"
|> Chart.show
```

![Chart displaying the corrections for trips on Monday and Sunday]({{ site.url }}/assets/2026-09-16/simple-correction.png)

This is better, but doesn't address all issues. For example, here are two 
problems that remain with the updated model:  

- A trip that takes 2 minutes on average is estimated to take 0 minutes on 
Sundays, which isn't right, unless teleportation is an option,  
- A trip from A to A (no movement) that takes 0 minutes is estimated to take 1 
minute on Mondays.  

This is not quite as bad as our earlier time travel problem, but it is still a 
bit problematic. Can we fix that? Let's try!  

First, let's simplify notation a bit. Fundamentally, what we are after is a 
function that,  
- given a drive time `t` (provided by the external service),  
- and a desired correction `c` (for instance `1` for Mondays),  
- returns a corrected drive time. 

Let's name that function `f(t, c)`.  

Taking a step back, what properties would we want our correction function `f` 
to have? I can think of a few:  

- (1) Corrected drive times should always be positive.  
- (2) If the original drive time `t` is 0, the corrected drive time should be 0.  
- (3) When `t` increases, `f(t, c)` should increase too (strictly).  

Our initial attempt, `f0`, was simply `f0(t, c) = t + c`, and did not pass (1) 
or (2). Our first modification, `f1(t, c) = max(t + c, 0)`, failed (2) and (3).  

Condition (2) is interesting, because it creates a tension, if not a 
contradiction. Our initial goal was to create a function that corrects the 
value `t` we get from the service, by adding a bias term `c` to match the 
average error for a given day of the week. However, now we are also saying that 
`f(0, c) = 0`. We can't have both `f(0, c) = 0` and `f(0, c) = c`, except for 
the case `c = 0`. How can we reconcile these 2 things?  

Going back to the original diagnosis suggests a direction. Our initial model 
had a problem for **small** values of `t`, so we could do something along these 
lines:  

- when `t` is `0`, `f` should be `0`,  
- when `t` is close to `0`, `f` should be close to `t`,  
- as `t` increases, `f` should become closer and closer to `t + c`.  

Stated differently, `f` should return `t` and an added "correction" component:  

`f(t, c) = t + g(t, c)`

where `g` is a function that computes the correction to add. Given the 
properties we listed earlier, we are looking for a function `g` such that  

- `g(0, c) = 0`,  
- `g(t, c)` tends to `c` as `t` increases,  
- `g` is stricly increasing in `t`.  

There are many functions that would satisfy these criteria. A convenient 
building block for this type of transformation is the `exp(-x)` function, which 
has the following properties:  

- `exp(0) = 1`,
- `exp(-x)` tends to `0` as `x` increases,
- `exp(-x)` is strictly decreasing.

This is not the ony option. As an example, another candidate would be 
`1 / 1 + x`.  

![Chart displaying exp(-x) and 1/1+x, transforming inputs into values between 0 and 1]({{ site.url }}/assets/2026-09-16/transformation.png)

These functions are helpful building blocks, in that they map any positive 
value into values in the `[0, 1]` interval. And, once we have values that are 
guaranteed to be in `[0, 1], it is easy to produce values that are guaranteed 
to be in any interval we want.  

In our case, what we want is values that are between `0` and `c`. All we need 
to do is "flip" the functions `exp(-x)` so that instead of decreasing from `1` 
to `0` it increases from `0` to `1`, and multiply by `c` so the limit becomes 
`c` instead of `1`:  

`g(t, c) = c * (1 - exp(-t))`  

Does it work? Let's check.  

``` fsharp
let g(t, c) = c * (1.0 - exp(-t))

[
    [ 0.0 .. 0.01 .. 7.0 ]
    |> List.map (fun t -> t, t + g(t, 1.0))
    |> Chart.Line
    |> Chart.withTraceInfo "Monday"

    [ 0.0 .. 0.01 .. 7.0 ]
    |> List.map (fun t -> t, t + g(t, -2.0))
    |> Chart.Line
    |> Chart.withTraceInfo "Sunday"
]
|> Chart.combine
|> Chart.withXAxisStyle "Baseline"
|> Chart.withYAxisStyle "Corrected"
|> Chart.show
```

![Chart displaying exponential based corrections for trips on Monday and Sunday, with negative values]({{ site.url }}/assets/2026-09-16/correction-take-1.png)  

It _almost_ works. The Monday predictions look exactly like what we are after: 
they start at `0`, and rapidly converge to cling to the line `t + 1`. The part 
that is clearly not right is the Sunday predictions. For larger values of `t`, 
the predictions approach `t - 2`, which is what we want, but again, close to 
`t = 0`, we have negative predictions, which is what we were attempting to fix 
in the first place.  

Hand-waving the details, the root of the issue is that the correction term `g` 
is decreasing too quickly near `0`. In order to make sure that `g` remains 
positive at all times, as the derivative of `t` is `1`, the derivative of `g` 
at `0` must be greater than `-1`.  

> Note: the issue is particularly obvious for values of `c < -1`, which result 
in negative predictions. However, values of `c > 1` are also problematic, but 
in a more subtle way. In this case, near `0`, we get corrections that are 
greater than `t + c`, which is also undesirable.  

We can guaranteed that by making a small modification:  

`let g(t, c) = c * (1.0 - exp(-t / abs (c)))`  

And we finally get a nice and clean prediction function:  

![Chart displaying working exponential based corrections for trips on Monday and Sunday]({{ site.url }}/assets/2026-09-16/correction-take-2.png)  

## Parting thoughts

Realistically I don't think this specific problem will be interesting to many 
beyond me. However, I hope the breakdown of the thought process itself might be 
of interest to some!  

Something I should point out here is that the correction we ended with is not 
perfect. As stated earlier, there is a tension between the 2 imperatives that 
the correction should be `c` minutes, and the correction should be `0` at `0`. 
Our model balances these imperatives, with a correction that starts at `0` and 
gradually gets closer to `c` as `t` increases. But as a result, the average 
correction will not be `c`. How far off we are, and how acceptable the 
correction is, depends on how large `c` is, compared to the range of values we 
expect for `t`. If `c` is comparatively small, the gap will be small. If not, 
less so.  

One valid question about the approach I followed is why I used an additive 
correction, instead of a multiplier. Rather than a model where 
`f(t, c) = t + c`, I could have estimated a model along the lines of 
`f(t, a) = a * t`. One advantage with the latter approach is that we wouldn't 
have any of the problems we had adding a bias term: `f(0, a) = 0`, and for as 
long as `a >= 0`, `f` is positive for all positive values of `t`.  

The reason I did not go that route is that it wasn't a good fit with the 
observations. With a multiplicative model, corrections become larger and larger 
as `t` increases, which was not what I was observing. That being said, the more 
general approach would be a mixture of both, a traditional linear model along 
the lines of `f(t, c, a) = a * t + c`. With a few adjustments, an approach 
similar to the one I followed in this post should work there as well.  

And that's where I will leave things for today!  
