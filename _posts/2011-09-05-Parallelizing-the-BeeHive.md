---
layout: post
title: Parallelizing the BeeHive
tags:
- Bee-Colony
- Algorithms
- F#
- Parallelism
- Task
- Queue
- Search
---

Back in April, inspired by an [MSDN article](http://msdn.microsoft.com/en-us/magazine/gg983491.aspx), I began looking into converting a [Simulated Bee Colony]({{ site.url }}/2011/04/24/Simulated-Bee-Colony-in-F/) algorithms from C# to F#; I thought this would be an interesting exercise on my slow path to learning F#, and I got a rough implementation going. Attention-disorder deficit and life in general got me side-tracked, but, better late than never, I am now ready to get back to it.  

One aspect I am interested in, is to figure out how the original algorithm could be modified for parallelization. In its original form, the algorithm followed a turn-based approach: given the current state of the hive, process sequentially every bee (active, inactive, and scout bees), and repeat until the pre-set number of iterations is reached.  

How could we approach parallelization? At a high level, two operations are taking place:      

* some bees are **searching** from new solutions to the problem, either by creating brand-new solutions (Scout bees), or by finding a solution close to an initial Solution (Active bees),    
* bees that have completed a search come back to the Hive, and **share** the Solution they found to the Inactive bees via a Waggle Dance; Inactive bees can update their state based on that new information.   

The first part, the Search, is easily parallelizable: while searching, a Bee shares no data with other bees. Therefore, multiple bees could be searching for new solutions, each on its own thread. On the other hand, the information sharing part is trickier: if multiple bees were to share their new solution with inactive bees at the same time, concurrency problems would likely arise.  

One approach to resolve the issue is to avoid the concurrency problem, and make sure that by design, the information-sharing part is taking place sequentially, one bee at a time. Here is how we will achieve this:  

![ParallelBees]({{ site.url }}/assets/2011-09-05-ParallelBees_thumb.png)

A queue will hold bees returning from a Search with a new Solution, and process bees from the queue one by one, passing their information to the current inactive bees. Once it has shared its information with the inactive bees, the bee (or one of the inactive bees) is sent to Search again in parallel – and when its search completes, it returns to the queue, where it goes back in line and wait until it can be processed.  

<!--more-->

Today, we will just implement an outline of the algorithm, focusing on getting the bees moving the way they are supposed to; later on, we will implement the actual search part, reusing some of the bits we have written earlier.  

The Task Parallel Library makes is fairly easy to make this work. We’ll use the [`ConcurrentQueue`](http://msdn.microsoft.com/en-us/library/dd267265.aspx) to hold the bees returning from a search, so that we can safely add bees returning at the same time, and dequeuing bees going to share their information. We will use it for the Inactive bees as well for convenience, even though this isn’t necessary (we will likely change that later). We will have one [`Task`](http://msdn.microsoft.com/en-us/library/system.threading.tasks.task.aspx) running to manage the queue, permanently checking if bees are waiting in line, and sending the bee in front of the line to share its information with its colleagues. Every time a bee finished sharing its information, we will spawn a new Task, sending a new bee on a Search for a new solution.  

Let’s break the code step-by-step. First, we create a F# Console App, import the TPL namespaces we will use, and declare two super-simple types, a Status discriminated union to identify Active, Scout and Inactive bees, and a Bee record type, with an integer Id and a Status:  

``` fsharp
open System
open System.Collections.Concurrent
open System.Threading
open System.Threading.Tasks

type Status = Active | Scout | Inactive
type Bee = { Id:int; Status:Status }
``` 

We can now begin work on the Main method, and instantiate our 2 queues, one for the Inactive bees, one for the bees that returned:

``` fsharp
let Main =
   Console.WriteLine("Starting")

   let inactives = new ConcurrentQueue<Bee>()
   let returned = new ConcurrentQueue<Bee>()
``` 

We then define a `StartSearch` function, which takes in a bee and a queue as arguments. The queue is the returning bee queue: its purpose is to provide a “location” for the bee to arrive to, once the search is complete. We could also have used a Task Continuation, which would probably be more elegant, with a separation of the search and the enqueuing process. No elegance for now.

``` fsharp
let StartSearch bee (queue:ConcurrentQueue<Bee>) =
   Console.WriteLine("Bee {0} starting search", bee.Id)
   Thread.Sleep(100) // actual search goes here!
   queue.Enqueue(bee)
   Console.WriteLine("Bee {0} returned from search, in queue: {1}", bee.Id, queue.Count)
``` 

Now to the main course – the management of the returned bees Queue. We need to start a Task which will keep going until we tell it to stop. To achieve this, we’ll have a while loop scanning the queue for bees as long as a [`CancellationTokenSource`](http://msdn.microsoft.com/en-us/library/system.threading.cancellationtokensource.aspx) does not indicate that a cancellation has been requested. If no cancellation has been requested, and if the queue is not empty, we grab the bee in front of the line, and if we succeed, we “share” information with the inactive bees, add the bee to the inactive queue, and launch one of the inactive bees on a Search (we will probably reorganize that part later).

``` fsharp
let cancel = new CancellationTokenSource()

let ProcessReturning = Task.Factory.StartNew(new Action(fun () -> 
   while cancel.IsCancellationRequested = false do
      match returned.IsEmpty with
      | false -> 
         let success, bee = returned.TryDequeue()
         match success with
         | true -> 
            Console.WriteLine("Bee {0} doing waggle dance", bee.Id)
            Thread.Sleep(10) // information sharing goes here!
            Console.WriteLine("Bee {0} completed waggle dance", bee.Id)
            inactives.Enqueue(bee)
            let success, active = inactives.TryDequeue()
            Task.Factory.StartNew(new Action(fun () -> 
               StartSearch active returned))
            |> ignore
         | false -> ignore()
      | true -> ignore()), cancel.Token)
``` 

Note the `TryDequeue` syntax. In C#, `TryDequeue` returns a `bool`, and requires passing the candidate for dequeuing as an out argument. By contrast, F# takes no arguments and returns a `Tuple`, with the first element indicating whether the operation succeeded, and the second the dequeued item. Isn’t it much nicer?

And we are now ready to pump some bees into the system, and see the whole process run. We create a few inactive bees, launch a few active bees on the search – and we are ready to go:

``` fsharp
for i in 1 .. 10 do inactives.Enqueue({ Id=i; Status=Inactive })

for i in 11 .. 40 do
   Task.Factory.StartNew(new Action(fun () -> 
      StartSearch {Id=i; Status=Active} returned)) |> ignore

Console.WriteLine("Press Enter to stop bees processing")
Console.ReadLine() |> ignore

Console.WriteLine("Processing of bees stopped")
cancel.Cancel()

Console.WriteLine("Press Enter to Close")
Console.ReadLine()
``` 

Hit F5, and you should see something like this:

![BeesRunning]({{ site.url }}/assets/2011-09-05-BeesRunning_thumb.png)

In this particular case, you can see that activities are not sequential: on the 3rd line, Bee 11 begins its search, and much activity is taking place until it returns later, starts performing its Waggle Dance and completes it. 

If you tweak the time it takes to complete a Search and a Waggle, you’ll see different patterns for the queue profile; as the Waggle takes more time, it will get backed up.

That’s where we will leave for today – with a nicely buzzing hive of bees, enthusiastically flying around doing nothing, all in 54 lines of code (provided below in once piece). One aspect I find intriguing is that in this form, the algorithm behaves in a way which is pretty similar to a real hive, much more so than the turn-based algorithm. 

In the next installments, we’ll look into searching for actual solutions, as well as into the somewhat tricky problem of using a random number generator with parallelism. In the meanwhile, take care, and please do let me know if you have comments or criticisms!

``` fsharp
open System
open System.Collections.Concurrent
open System.Threading
open System.Threading.Tasks

type Status = Active | Scout | Inactive
type Bee = { Id:int; Status:Status }

let Main =
   Console.WriteLine("Starting")

   let inactives = new ConcurrentQueue<Bee>()
   let returned = new ConcurrentQueue<Bee>()

   let StartSearch bee (queue:ConcurrentQueue<Bee>) =
      Console.WriteLine("Bee {0} starting search", bee.Id)
      Thread.Sleep(100) // actual search goes here!
      queue.Enqueue(bee)
      Console.WriteLine("Bee {0} returned from search, in queue: {1}", bee.Id, queue.Count)

   let cancel = new CancellationTokenSource()

   let ProcessReturning = Task.Factory.StartNew(new Action(fun () -> 
      while cancel.IsCancellationRequested = false do
         match returned.IsEmpty with
         | false -> 
            let success, bee = returned.TryDequeue()
            match success with
            | true -> 
               Console.WriteLine("Bee {0} doing waggle dance", bee.Id)
               Thread.Sleep(10) // information sharing goes here!
               Console.WriteLine("Bee {0} completed waggle dance", bee.Id)
               inactives.Enqueue(bee)
               let success, active = inactives.TryDequeue()
               Task.Factory.StartNew(new Action(fun () -> 
                  StartSearch active returned))
               |> ignore
            | false -> ignore()
         | true -> ignore()), cancel.Token)

   for i in 1 .. 10 do inactives.Enqueue({ Id=i; Status=Inactive })

   for i in 11 .. 40 do
      Task.Factory.StartNew(new Action(fun () -> 
         StartSearch {Id=i; Status=Active} returned)) |> ignore

   Console.WriteLine("Press Enter to stop bees processing")
   Console.ReadLine() |> ignore

   Console.WriteLine("Processing of bees stopped")
   cancel.Cancel()

   Console.WriteLine("Press Enter to Close")
   Console.ReadLine()
``` 
