---
layout: post
title: Santa&#39; Mailbox
tags:
- F#
- fsAdvent
- Mailbox-Processor
---

_This post is part of the [F# Advent Calendar 2019][1]. Check out other posts in this series, under the [#fsadvent][2] hashtag, and... happy holidays everybody :)_

It is that time of the year again for Santa, Inc. - a time of celebration for most, but for Mister Claus, a time of intense and stressful activity. Every year, keeping up with all these letters coming from kids everywhere, and assigning them to the Elves crew, is a problem. Mister Claus is a diligent CEO, and keeps up with current trends in technology. Perhaps this F# thing he keeps hearing about might help him handle all these letters?

## Setting up the Problem

Instead of cute handwritten kids letters, we will take a much less cute, but conceptually similar problem. Imagine that, at regular intervals, we receive a batch of work items (the letters), which we need to process. We will represent each item as a `Job`, storing its batch number and number within the batch, and a `Value`, representing the job that needs doing:

``` fsharp
type Job = { 
    Batch: int
    Number: int
    Value: int 
    }
```

<!--more-->

What is the `Value` for? We want something that keeps the <del>Elves</del> CPUs busy. Not being particularly imaginative today, we will just take that number, and factorize it into its prime factors:

``` fsharp
let factorize x = 
    let rec factors acc fact rest = 
        if fact > rest
        then acc
        else 
            if rest % fact = 0
            then factors (fact :: acc) fact (rest / fact)
            else factors acc (fact + 1) rest
    factors [ 1 ] 2 x
```

We can test that out:

``` fsharp
> factorize 60;;
val it : int list = [5; 3; 2; 2; 1]
```

And indeed, 60 is equal to 1 * 2 * 2 * 3 * 5. Good. Now, all we need is a number that takes some time to factorize, so we have a nice, CPU bound task, as a proxy for our Elves doing busy work responding to the letters. With a bit of fiddling around, we ended up with 2130093701, a large prime which takes about 5.5 seconds to factorize on Santa's machine:

``` fsharp
> #time "on";;
> factorize 2130093701;;

Real: 00:00:05.695, CPU: 00:00:05.703, GC gen0: 0, gen1: 0, gen2: 0
val it : int list = [2130093701; 1]
```

We can now simulate a busy December for Santa, Inc, with a producer that will create new batches at regular intervals, each batch containing a random number of identical tasks:

``` fsharp
module Producer =

    type Config = {
        MaxBatch: int
        Interval: int
        }

    let start (config: Config) = 
        let rng = Random 0
        let rec loop batch =
            async {
                let batchSize = rng.Next(0, config.MaxBatch + 1)
                printfn "New jobs arriving: batch %i, %i" batch batchSize
                let jobs = 
                    Array.init batchSize 
                        (fun i -> 
                            { 
                                Batch = batch
                                Number = i
                                Value = 2130093701
                            }
                            )
                do! Async.Sleep (config.Interval * 1000)
                return! loop (batch + 1)
            }
        loop 0 |> Async.Start
```

We can now configure our producer, so that every 5 seconds, we have a new batch of 0 to 10 jobs coming in:

``` fsharp
let config : Producer.Config = { 
    Interval = 5
    MaxBatch = 10 
    }

config |> Producer.start
```

... which will result in something like this:

```
New jobs arriving: 7
New jobs arriving: 8
New jobs arriving: 8
```

This was a lot of setup! But, what is the problem we want to solve here, exactly?

The problem is the following: in our particular example, every 5 seconds, we are getting somewhere between 0 and 10 work items, each taking about 5 seconds to solve. Clearly, if only one <del>Elf</del> CPU is handling this, we won't be able to keep up. The poor children! What can Mister Claus do here to make sure they get a response back before Christmas is over?

## Bad Mailbox: A Sad Christmas Story

Mister Claus is no fool, and realizes that, with an average of 5 tasks arriving every 5 seconds, each batch will take nearly half a minute to process. That's no task for a single <del>Elf</del> CPU, he needs to put many of them to work.

To avoid blocking new letters arriving every 5 seconds, we will post them into a `MailboxProcessor`. And, because we are lazy (not the computer sciency type), we will try to process them using `Array.Parallel`:

``` fsharp
let processJob (job: Job) = 
    let task = new Task(fun _ ->        
        printfn "Started batch %i job %i" job.Batch job.Number
        let timer = Stopwatch ()
        timer.Start ()
        let _ = factorize job.Value
        let elapsed = timer.ElapsedMilliseconds / 1000L
        printfn "Completed batch %i job %i in %i secs)" job.Batch job.Number elapsed
        )
    task.Start()

module Parallel = 

    let mailbox = MailboxProcessor<Job[]>.Start(fun inbox ->
        let rec loop () = 
            async {
                let! jobs = inbox.Receive ()
                jobs |> Array.Parallel.iter (processJob)
                return! loop ()
            }
        loop () 
        )
```

All we need to do then is hook that up in our producer, so that every time we have jobs, they get sent to the mailbox. Let's do it, and add `Parallel.mailbox.Post jobs` inside our loop:

``` fsharp
module Producer =

    // same as before

    let start (config: Config) = 
        let rng = Random 0
        let rec loop batch =
            async {
                let batchSize = rng.Next(0, config.MaxBatch + 1)
                printfn "New jobs arriving: batch %i, %i" batch batchSize
                let jobs = 
                    Array.init batchSize 
                        (fun i -> 
                            { 
                                Batch = batch
                                Number = i
                                Value = 2130093701
                            }
                            )
                Parallel.mailbox.Post jobs
                do! Async.Sleep (config.Interval * 1000)
                return! loop (batch + 1)
            }
        loop 0 |> Async.Start
```

Santa is optimistic - he deploys the code in production Friday night, and starts running his mailbox, with 4 busy CPUs at work. Everything looks good, tasks are completed in about 5 seconds each:

```
Started batch 0 job 6
Started batch 0 job Started batch 0 job 0
Started batch 1
0 job 3
Started batch 0 job 2
Completed batch 0 job 1 in 5Completed batch 0 job 0 in 5 secs)
 secs)
New jobs arriving: batch 1, 8
Started batch 0 job 4
Started batch 1 job 7
Completed batch 0Completed batch 0 job 6 in 5 secs)
 job 3 in 5 secs)
...
```

Alas! On Monday, as he comes back from a merry weekend, he finds Elves running all over the place. Soon, as he looks over the logs, his happy "Ho! Ho! Ho!" becomes muffled; and Mister Claus start to grumble, and then curse loudly:

```
New jobs arriving: batch 96Completed batch , 92Completed batch 9Completed batch Completed batch Completed batch  job 92
92 job 1 in 22 secs)
Completed batch 92 job Completed batch 93 job 1 in 22 secs)
Started batch 96 job 1
93 job 93 job  job Started batch Started batch 3Started batch Started batch Started batch 9640 in 4 in 96 job  in 22Completed batch 93Completed batch 9296Started batch 96 in 0 in 96 job Completed batch 8
 secs)
```

22 seconds to handle a 5-seconds Job! This does not look good. And look at this log - what a sorry mess. Santa is not happy, and goes back to the drawing board.

## Throttling the Mailbox

Mister Claus goes into his office, and, as he tries to figure out what is happening, he finds it really hard to follow what is going on in the logs, with all these Elves trying to write down what they are doing at the same time. So he starts by creating a small log using another `MailboxProcessor`:

``` fsharp
module Log = 

    let logger = MailboxProcessor<string>.Start(fun inbox ->        
        let rec loop () = 
            async {
                let! msg = inbox.Receive ()
                printfn "%s" msg
                return! loop ()
            }
        loop () 
        )

    let log msg = 
        sprintf "%A|%s" (DateTime.Now) msg
        |> logger.Post
```

After some more thinking, Mister Claus realizes that maybe it is not such a hot idea to start so many parallel maps before the previous batches have been completed. Perhaps some throttling would help? He fires VS Code and Ionide, and rewrites that mailbox:

``` fsharp
module Queued = 

    type Message = 
        | Batch of Job []
        | Completed of Job

    let processJob (inbox: MailboxProcessor<Message>) (job: Job) = 
        let task = new Task(fun _ ->                    
            sprintf "Started batch %i job %i" job.Batch job.Number 
            |> Log.log
            let timer = Stopwatch ()
            timer.Start ()
            let _ = factorize job.Value
            let elapsed = timer.ElapsedMilliseconds / 1000L
            sprintf "Completed batch %i job %i in %i secs" job.Batch job.Number elapsed 
            |> Log.log
            Completed job |> inbox.Post
            )
        task.Start()

    let mailbox = MailboxProcessor<Message>.Start(fun inbox ->
        
        let parallelism = 4
        let mutable inFlight = 0
        let queue = Queue<Job> ()

        let rec loop () = 
            async {
                let! msg = inbox.Receive ()
                match msg with 
                | Batch jobs ->
                    jobs |> Array.iter (queue.Enqueue)
                | Completed job -> 
                    inFlight <- inFlight - 1

                let rec dequeue () = 
                    if (inFlight < parallelism && queue.Count > 0)
                    then
                        let job = queue.Dequeue ()
                        inFlight <- inFlight + 1
                        processJob inbox job
                        dequeue ()

                dequeue ()
                sprintf "Queue: %i, In Flight: %i" queue.Count inFlight
                |> Log.log
                return! loop ()
            }
        loop () 
        )
```

The mailbox will now run only 4 tasks at the same time at most. When a new `Batch` of jobs arrives, they go into a queue. If less that 4 jobs are currently running, jobs are dequeued and processed, increasing the count of jobs "in flight". When the job is `Completed`, a message is sent back to the mailbox, decreasing the count of jobs currently in flight, and signaling that new jobs can be started.

Mister Claus deploys his updated code, and anxiously looks at the logs:

``` 
12/2/2019 3:49:31 PM|Started batch 22 job 9
12/2/2019 3:49:36 PM|New jobs arriving: batch 40, 5 jobs
12/2/2019 3:49:37 PM|Completed batch 22 job 6 in 5 secs
12/2/2019 3:49:37 PM|Queue: 91, In Flight: 4
12/2/2019 3:49:37 PM|Queue: 90, In Flight: 4
12/2/2019 3:49:37 PM|Started batch 24 job 0
12/2/2019 3:49:37 PM|Completed batch 22 job 7 in 5 secs
12/2/2019 3:49:37 PM|Queue: 89, In Flight: 4
```

What a beautifully formatted log! This pleases Mister Claus greatly. Tasks now get completed at a steady pace, taking 5 seconds each. Unfortunately, this also highlights a serious issue: the queue is building up over time. As batch 40 arrives, the Elves are still busy working on batch 22, and can't keep up. The shoulders of Mister Claus slump again: The children! What about the children? Is this Christmas doomed?

## A Smarter Mailbox

In hindsight, Mister Claus realizes that this was obvious. If he receives an average of 5 letters per batch and processes 4 at most between batch arrivals, the queue _is_ going to get backed up. Now tasks are being processed as fast as possible, but there is a price to pay: New tasks get stuck in the queue, potentially for a very, very long time. Potentially until after Christmas! 

You don't get to stay in business for centuries by giving up at the first headwind. Back to the drawing board for Mister Claus! After giving the problem more thought, Mister Claus has a moment of insight: his two initial approaches are the two sides of the same coin. If he wants to run tasks as quickly as possible, some will have to wait in the queue. If he
wants to process them immediately, then there is a risk of overwhelming the machine by doing too much work at once.

But then, if this is a trade-off, perhaps a compromise is possible? In the end, what matters is not how quickly we run the task itself. What we want is to get as many tasks as possible entirely completed per time interval, _from their arrival in the queue all the way to completion_. 

In other words, we want to maximize throughput, which combines two elements:
- How long does it take to process an individual task, end to end?
- How many tasks are we processing concurrently?

The second part is important, because we care about overall system throughput. In the end, if processing tasks one-by-one takes 5 seconds, but processing them two at a time takes 9 seconds each, we are better off with the second option, which will complete more tasks during the same time window.  

How could we measure how effective our system is, then? If we complete a particular task, end-to-end, in `S` seconds, then we are completing `1/S` of that task per second: A task that takes 5 seconds is 20% completed (1/5) in 1 second. However, if we have `T` tasks concurrently in flight, each of them is moving forward in parallel: Our system is completing `T/S` tasks per second.

Now that Mister Claus knows how to measure how productive his Elves are, he still has a problem. Assuming there is an ideal level of concurrency, how can he find it?

There is, of course, the old-school option of just trying it out. Run the mailbox at various levels of concurrency, measure the throughput, and pick the one that works best. It is a viable approach; However, this is also going to be a painful process. On top of that, the ideal level will be specific to the machine we used, and won't necessarily work for another machine. Mister Claus ponders some more, and wonders - wouldn't it be nice if the machine could learn what works best, all by itself? After all, as the mailbox is running, it can observe its throughput, so all it should take is a mechanism to observe that throughput at various levels, and adjust concurrency automatically, searching for the level that gives us the best results.

Mister Claus is excited. He puts on his noise-cancelling headphones, and starts banging on his keyboard again. First, we need to measure how long a Job stays in the system. That's easy, we just need to keep track of the arrival time:

``` fsharp
type Timed<'T> = { 
    Arrival: DateTime
    Item: 'T
    }

type Message = 
    | Batch of Job []
    | Completed of Timed<Job>
```

Then, we need to keep track of the throughput for each concurrency level, and update it as we observe new tasks being completed. We will use a simple strategy to estimate the throughput for each level: when a task completes, we will measure its duration:

- If we have no estimate for that level yet, we will use that duration as a starting point,
- If we already have an estimate, we will update it like this: `let updated = alpha * duration + (1.0 - alpha) * estimate`

`alpha`, the learning rate, is a number between 0.0 and 1.0. With a value of 0.0, we ignore the new estimate, and always keep the original estimate, learning nothing over time. With a value of 1.0, we ignore the past estimate, and always replace it with the latest observation. Anything in between decides how aggressively we want to update our throughput estimation based on recent observations - the higher the number, the more we take into account new observations, and the faster our estimate will change.

That should take care of estimating the throughput for a given level, but how do we go about trying out different levels? Again, we will go for a simple strategy:

- If there is a better throughput one level up or down, we move up or down towards that,
- Sometimes, we just randomly move up or down, to explore and try out what happens.

The first part is straightforward: if moving concurrency level up or down is an improvement, we just do it. The second part is more interesting: by randomly exploring various levels of concurrency, we should be able to learn about each of them. We should also be able to revisit levels we tried before, and update their througput estimation, if circumstances have changed. 

Mister Claus starts to put all of this together, with some quick-and-dirty code:

``` fsharp
module Throughput = 

    type Config = {
        LearningRate: float
        ExplorationRate: float
        }

    let update config (concurrency, elapsed) (throughput: Map<int, float>) =
        let measure = float concurrency / elapsed
        match throughput |> Map.tryFind concurrency with
        | None -> throughput.Add (concurrency, measure)
        | Some value -> 
            let updated = 
                (1.0 - config.LearningRate) * value
                + config.LearningRate * measure
            throughput.Add (concurrency, updated)

    let rng = Random 0

    let setLevel config (level: int) (throughput: Map<int, float>) =
        let explore = rng.NextDouble () < config.ExplorationRate
        // with a certain probability, we randomly explore
        if explore
        then
            if rng.NextDouble () < 0.5
            then (max 1 (level - 1))
            else level + 1
        // otherwise we adjust up or down if better
        else
            let current = throughput |> Map.tryFind level
            let lower = throughput |> Map.tryFind (level - 1)
            let higher = throughput |> Map.tryFind (level + 1)
            match current with
            | None -> level
            | Some current ->
                match lower, higher with
                | None, None -> level
                | None, Some high -> 
                    if high > current then level + 1 else level
                | Some low, None -> 
                    if low > current then level - 1 else level
                | Some low, Some high -> 
                    if low > current && low > high then level - 1
                    elif high > current then level + 1
                    else level
```

And that's pretty much it - all that is needed is updating our mailbox loop:

``` fsharp
    let mailbox (config: Throughput.Config)= 
        MailboxProcessor<Message>.Start(fun inbox ->
        
            let mutable inFlight = 0
            let queue = Queue<Timed<Job>> ()

            let rec loop (throughput, parallelism) = 
                async {
                    let! msg = inbox.Receive ()
                    
                    // update observed throughput
                    let throughput = 
                        match msg with 
                        | Batch _ -> throughput
                        | Completed job -> 
                            let elapsed = (DateTime.Now - job.Arrival).TotalSeconds
                            throughput |> Throughput.update config (inFlight, elapsed)   
                    // handle the work
                    match msg with 
                    | Batch jobs ->
                        jobs 
                        |> Array.iter (fun job -> 
                            { Arrival = DateTime.Now; Item = job } 
                            |> queue.Enqueue
                            )
                    | Completed _ -> 
                        inFlight <- inFlight - 1

                    // adjust level of parallelism
                    let parallelism = 
                        throughput |> Throughput.setLevel config parallelism
                    
                    let rec dequeue () = 
                        if (inFlight < parallelism && queue.Count > 0)
                        then
                            let job = queue.Dequeue ()
                            inFlight <- inFlight + 1
                            processJob inbox job
                            dequeue ()
                            
                    dequeue ()
                    
                    sprintf "Queue: %i, In Flight: %i, Parallelism: %i" queue.Count inFlight parallelism 
                    |> Log.log

                    return! loop (throughput, parallelism)
                }

            let throughput = Map.empty<int,float> 
            loop (throughput, 1) 
            )
```

_You can find the [complete code here as a gist][4]_

## Trying Our Mailbox

Mister Claus wires everything up, and anxiously pores over the log:

```
> 12/3/2019 3:07:42 PM|New jobs arriving: batch 0, 7 jobs
12/3/2019 3:07:42 PM|Started batch 0 job 0
12/3/2019 3:07:42 PM|Queue: 6, In Flight: 1, Parallelism: 1
12/3/2019 3:07:47 PM|New jobs arriving: batch 1, 8 jobs
12/3/2019 3:07:47 PM|Queue: 14, In Flight: 1, Parallelism: 1
```

Unsurprisingly, the queue starts to build up pretty quickly. 

```
12/3/2019 3:09:02 PM|New jobs arriving: batch 16, 9 jobs
12/3/2019 3:09:02 PM|Queue: 80, In Flight: 2, Parallelism: 2
12/3/2019 3:09:05 PM|Completed batch 2 job 4 in 5 secs (total 73)
12/3/2019 3:09:05 PM|Queue: 79, In Flight: 2, Parallelism: 2
```

CPU time is still at 5 seconds per job, but now jobs spend over a minute in the queue: `Completed batch 2 job 4 in 5 secs (total 73)` indicates a job taking 73 seconds total, with 5 seconds running the task proper.

10 minutes in, and Mister Claus is getting worried. The queue has stopped growing, but the system barely keeps up, and it takes now about 4 minutes to complete jobs:  

```
12/3/2019 3:17:36 PM|New jobs arriving: batch 96, 9 jobs
12/3/2019 3:17:36 PM|Queue: 172, In Flight: 26, Parallelism: 26
12/3/2019 3:17:36 PM|Queue: 181, In Flight: 26, Parallelism: 26
12/3/2019 3:17:36 PM|Started batch 66 job 0
12/3/2019 3:17:37 PM|Completed batch 62 job 2 in 36 secs (total 243)
```

Hooray! Parallelism has been cranked all the way up to 38, and we are starting to make a dent in the queue. Things are looking up:

```
12/3/2019 3:21:36 PM|Completed batch 93 job 4 in 16 secs (total 272)
12/3/2019 3:21:36 PM|New jobs arriving: batch 121, 3 jobs
12/3/2019 3:21:36 PM|Queue: 94, In Flight: 37, Parallelism: 37
12/3/2019 3:21:36 PM|Queue: 96, In Flight: 38, Parallelism: 38
12/3/2019 3:21:36 PM|Started batch 101 job 3
```

And, lo and behold, 20 minutes in, things are looking pretty good: the queue is now empty, and jobs are in-and-out in around 20 seconds:

```
12/3/2019 3:29:20 PM|New jobs arriving: batch 165, 7 jobs
12/3/2019 3:29:20 PM|Queue: 0, In Flight: 22, Parallelism: 40
12/3/2019 3:29:20 PM|Started batch 165 job 6
12/3/2019 3:29:20 PM|Started batch 165 job 0
12/3/2019 3:29:20 PM|Started batch 165 job 1
12/3/2019 3:29:25 PM|Completed batch 162 job 4 in 20 secs (total 21)
```

If we plot the behavior of our mailbox over time, here is what we see. The queue builds up for a while, and then goes down, as it finds a good concurrency level that allows it to make a dent. Later on, we see a temporary spike again. This is not unexpected: we can encounter temporary high activity periods.

![Queue over time]({{ site.url }}/assets/2019-12-04-queue.PNG)

In terms of time in the system, as the queue builds up, we see the overall processing time go up, mostly spent in the queue. As the concurrency increases, the time spent processing the task itself also slowly degrades. Once the mailbox catches up and the queue is resorbed, the number of tasks in flight reduces. The time spent in the queue is negligible, and the end-to-end processing time stabilizes at a low, relatively steady level.

![Performance over time]({{ site.url }}/assets/2019-12-04-throughput.PNG)

## Conclusion

Hooray - with a bit of F#, we rescued Christmas! In and of itself, this is already a nice result. Nobody likes a sad Christmas story.

Beyond that, hopefully you found something interesting in this post! For me, there are two bits of particular interest. First, I thought it would be fun to showcase the mailbox processor, an F# feature that doesn't get too much press. I wish the mailbox processor was a bit easier to us, but even then, it is a nice tool to have in the arsenal. As a side note, I would like to say a big thank you to [Jeremie Chassaing][3], who kindly took the time to show me how to use them some time ago.

Then, perhaps the mechanics behind the self-adjusting mailbox will inspire you! They are a very crude adaptation of ideas borrowed from reinforcement learning. In particular, I find the exploration vs. exploitation approach fascinating. It makes intuitive sense that learning requires making random and potentially bad decisions; And yet, I am always a bit surprised to see how such a simple technique can actually work. More generally, there is one thing that I hope came across in this example: machine learning techniques don't have to be complicated, and can be used to solve many problems besides recognizing whether or not there is a hotdog in a picture.

Note also that, while the approach works in our particular example, this isn't a silver bullet. First, if too much work is coming in, no amount of adaptation will save you: Too much to handle is too much to handle. Then, if the complexity of tasks varies a lot, or if there is a large delay when observing throughput, it might take a while for the system to learn a good level of concurrency.

Finally... I am sure both the code and algorithm can be improved! For instance, I noticed that over longer periods of time, the concurrency level seems to have a tendency to keep increasing, even with a low number of tasks in flight; a mechanism should probably be added to handle that. So, I would love to hear your thoughts or suggestions! The complete code for the final example is [available here as a gist][4]. And, if there is enough interest in the idea, I'd be open to try and turn it into a library?

That's it for now! In the meanwhile, enjoy the Holidays, and until then, keep your eyes out for the other posts in the [F# Advent Calendar 2019][1]!

[1]: https://sergeytihon.com/2019/11/05/f-advent-calendar-in-english-2019/  
[2]: https://twitter.com/search?q=%23fsadvent
[3]: https://twitter.com/thinkb4coding
[4]: https://gist.github.com/mathias-brandewinder/329c1021575858e8247f3dbeebae8c7b
