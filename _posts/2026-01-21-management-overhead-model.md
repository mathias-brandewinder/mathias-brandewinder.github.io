---
layout: post
title: "How much of a burden is management?"
tags:
- F#
- Modeling
- Economics
use_math: true
---

From time to time, a small and usually unimportant question gets stuck in my 
head, and won't stop nagging me until I spend the time to figure out the 
answer. This post is about one of these.  

[Last December, I mentioned in a post][1] that "bigger teams require more 
coordination", which would lead to diminishing returns to scale. As a team 
grows, it requires managers to coordinate activities. Grow the team more, and 
managers themselves require coordination, and another layer of managers, and so 
on and so forth. My intuition was that, ignoring other effects, larger teams 
would progressively become less and less productive, because of the increased 
burden of management.  

The question that got stuck in my head was, how does this burden grow? What 
shape does it have, and can I express it as a mathematical function? This is 
the question I will be investigating in this post.  

The way I approached the question started by formulating a simplistic model, 
without being too concerned about the finer details. In my world, any time we 
form a group of a certain size, a coordinator (a manager, if you will) is 
needed. These coordinators do not directly contribute to the actual work, but 
they are necessary for the workers to perform their work.  

As an illustration, let's imagine that this group size is 5. In this case,  

- 1 worker can work without coordination,
- 4 workers can work without coordination,
- 5 workers require 1 coordinator (we reached a group size of 5),
- 6 workers require 1 coordinator (we have 1 group of 5, and an unsupervised 
worker),
- 25 workers require 5 coordinators, who themselves require 1 coordinator.

... and so on and so forth: 125 workers (`5*5*5`) require another layer of 
coordinators, 625 yet another layer, etc...  

So how does it look? Let's write a function, computing the coordination 
overhead needed for a given number of `workers`:  

``` fsharp
let groupSize = 5

let overhead (workers: int) =
    workers
    |> Seq.unfold (fun population ->
        if population >= groupSize
        then
            let managers = population / groupSize
            Some (managers, managers)
        else None
        )
```

<!--more-->

We start with the population of `workers`. If that population is less than the 
`groupSize`, we stop. If we have more than the `groupSize`, at least one 
coordinator is needed. We create a manager for each group of `groupSize`, and 
repeat for these managers, checking if they too need managers, until we are 
done.  

Let's confirm that it works first:  

``` fsharp
overhead 1
> seq []

overhead 4
> seq []

overhead 5
> seq [1]
overhead 6
seq [1]

overhead 25
seq [5; 1]

overhead 125
seq [25; 5; 1]

overhead 625
seq [125; 25; 5; 1]
```

The `overhead` function calculates how many coordinators are needed, by layer. 
For example, `overhead 125` calculates that `125` workers will require `25` 
direct coordinators, who will themselves require `5` coordinators, who will 
require `1` last coordinator.  

Now that we have this function in place, we can plot how many people we need 
for any number of workers. Let's do that, using [Plotly.NET][2]:  

``` fsharp
#r "nuget: Plotly.NET"
open Plotly.NET

let totalStaff (workers: int) =
    let totalOverhead =
        overhead workers
        |> Seq.sum
    workers + totalOverhead

[ 1 .. 1000 ]
|> List.map (fun workers -> workers, totalStaff workers)
|> Chart.Line
|> Chart.withXAxisStyle "Workers"
|> Chart.withYAxisStyle "Total"
|> Chart.show
```

The resulting chart is as follows:  

![Plot of workers against total staff needed]({{ site.url }}/assets/2026-01-21/workers-overhead.png)

This chart caught me by surprise. I was expecting the curve to bend upwards, 
and show diminishing returns to scale. It doesn't - this looks like a straight 
line, with a roughly constant ratio of coordinators to workers. In other words, 
in this model, teams scale perfectly fine.  

Does this make sense? Hindsight being 20/20, it does. Zooming in a bit on just 
the number of managers needed in isolation helps understand better what is 
happening:  

``` fsharp
[ 1 .. 200 ]
|> List.map (fun workers ->
    workers,
    overhead workers |> Seq.sum
    )
|> Chart.Line
|> Chart.withXAxisStyle "Workers"
|> Chart.withYAxisStyle "Managers"
|> Chart.show
```

![Plot of workers against managers needed]({{ site.url }}/assets/2026-01-21/workers-managers.png)

The number of managers as a function of the number of workers grows as a 
"staircase" function. To be more specific, it is a stack of staircase 
functions: every 5 workers, we add a manager, every 25 workers, we add 1 extra, 
every 125 we add 1 extra, and so on and so forth.  

In other words, as an approximation, the overhead for `x` workers is:  

$overhead(x) = x \times \frac{1}{5}  + x \times \frac{1}{5 \times 5} + x \times \frac{1}{5 \times 5 \times 5} ...$  

This is a sum of linear functions, that is, a linear function. We can even 
compute its slope, recognizing that `1/5 + 1/5*5 + 1/5*5*5...` is a 
[geometric series][3], which gives us a limit of  

$overhead(x) \approx \frac {x} {5 - 1}$  

This happens to match the last chart, where we see that for 200 workers, we 
need approximately 50 managers.  

Long story short, as long as a group needs less direct managers than the group 
size, the overhead cost grows linearly with the number of workers needed.  

Now that model also assumes that the cost of a manager is the same as a worker, 
which is not exactly realistic. However, if we assume that each level of the 
hierarchical pyramid gets a geometric paid increase, that is, each level is 
paid for instance 20% more than the previous, the results remain the same. The 
overhead function becomes something like this:  

$overhead(x) = x \times \frac{1}{5} \times 1.2 + x \times \frac{1}{5 \times 5} \times 1.2^2 + x \times \frac{1}{5 \times 5 \times 5} \times 1.2^3...$  

We still have a geometric series pattern at play, and the overall behavior 
remains the same.  

## Parting thoughts

I really did not expect the model to turn out linear! I suspect it is because 
I assumed that adding a pyramid of managers would introduce inefficiencies and 
diminishing returns to scale, which blinded me to the geometric series pattern. 
So... question your assumptions, build a simple model, and plot your data!  

[1]: https://brandewinder.com/2025/12/11/goal-seek-for-santa/
[2]: https://plotly.net/
[3]: https://en.wikipedia.org/wiki/Geometric_series