---
layout: post
title: FizzBuzz, the hard way
tags:
- Task
- Recursion
- FizzBuzz
- Continuation
- C#
---

I have been digging into the Task Parallel library lately, and enjoying it a lot. As an exercise, I wondered if I could implement the classic [**FizzBuzz**](http://www.codinghorror.com/blog/2007/02/why-cant-programmers-program.html) problem, using only Tasks, no loop-related keyword, and no method or property. To enforce this is, we’ll get FizzBuzz to run in the `Main()` method of a simple console, using only variables created locally.   

*Note: this is clearly a totally preposterous way to use the Task Parallel library. There is absolutely no benefit in using it in this context, I am doing this only for the sake of exploring how tasks work.*  

So how would we go about that?  A Task represents an asynchronous operation; it wraps a block of code, waiting to be executed. For instance, the following code queues up work to print out “Starting” to the console, and begins execution when we request the Task to start:  

``` csharp
private static void Main(string[] args)
{
   var rootTask = new Task(
      () =>
         {
            Console.WriteLine("Starting");
         });
   rootTask.Start();
   Console.ReadLine();
}
``` 

We clearly need something more for FizzBuzz. If we want to avoid looping constructs, we need to have a form of recursion going on, so that we can work on increasing integers, until we reach the limit we set to our FizzBuzz.

Fortunately, Tasks are about more than simply executing a block of code; they can be composed, defining what tasks can be started when some precursor tasks are finished. In particular, Tasks allow [**Continuations**](http://en.wikipedia.org/wiki/Continuation-passing_style): what to do once a specific task terminates can be defined, by using [`Task.ContinueWith()`](http://msdn.microsoft.com/en-us/library/dd270696.aspx), as in this example:

``` csharp
private static void Main(string[] args)
{
   var rootTask = new Task(
      () =>
      {
         Console.WriteLine("Starting");
      });

   var nextTask = new Task(
      () =>
      {
         Console.WriteLine("Next task!");
      });

   rootTask.ContinueWith(it => nextTask.Start());

   rootTask.Start();
   Console.ReadLine();
}
``` 

Here we define our root task, still printing “Starting”, and another task, which will print “Next task!”, and we pass that nextTask as a follow-up task to the rootTask via ContinueWith. Running this code will execute first the rootTask, and upon completion, kickstart the second one, and print both expected lines to the Console.

<!--more-->

Now what? First, we need to iterate over all integers from 1 to 100 (or whatever the upper limit is) – we will do that using Continuations, creating tasks recursively based on the last integer we worked with, until the upper limit is reached.

Here is what I ended up with:

``` csharp
private static void Main(string[] args)
{
   var max = 100;
   Func<int, Task> createNextTask = null;
   createNextTask = new Func<int, Task>(
      i =>
      {
         if (i < max)
         {
            var j = i + 1;
            var nextTask = new Task(() => Console.WriteLine(j));
            nextTask.ContinueWith(it => createNextTask(j).Start());
            return nextTask;
         }
         return new Task(() => Console.WriteLine("Finished"));
      });

   var rootTask = new Task(
      () =>
      {
         Console.WriteLine("Begin");
      });

   rootTask.ContinueWith(it => createNextTask(0).Start());
   rootTask.Start();
   Console.ReadLine();
}
``` 

Starting from the bottom of the code, we create our usual rootTask, and continue it by calling `createNextTask` for integer 0, our first integer, and starting it.

`CreateNextTask` is a function which, given an integer, returns a task. If the integer is greater that the upper limit, we simply return a Task with no continuation, stating that we are done. For integers under the limit, we create a task that prints out the next number, and creates its continuation, recursively calling `CreateNextTask` so that once it completes, it keeps going.

Running this code will simply write out all integers from 1 to 100 – we can proudly say that we have what is likely to be the most complicated way to create the equivalent of a for loop iterating from 1 to 100. 

Note how the `Func<int, Task>` createNextTask is first initialized, and then defined. This is required, because C# doesn’t support the classic [one-line declaration for recursive functions](http://stackoverflow.com/questions/1079164/c-recursive-functions-with-lambdas) (an interesting tidbit I learnt through this exercise).

The last piece is now trivial. FizzBuzz requires that we write Fizz for multiples of 3, Buzz for multiples of 5, and FizzBuzz for multiples of both – let’s do it:

``` csharp
private static void Main(string[] args)
{
   var max = 100;
   var fizzBuzz = new Action<int>(
      i =>
      {
         if (i % 3 == 0 && i % 5 == 0) Console.WriteLine("FizzBuzz");
         else if (i % 3 == 0) Console.WriteLine("Fizz");
         else if (i % 5 == 0) Console.WriteLine("Buzz");
         else Console.WriteLine(i);
      });

   Func<int, Task> createNextTask = null;
   createNextTask = new Func<int, Task>(
      i =>
      {
         if (i < max)
         {
            var j = i + 1;
            var nextTask = new Task(() => fizzBuzz(j));
            nextTask.ContinueWith(it => createNextTask(j).Start());
            return nextTask;
         }
         return new Task(() => Console.WriteLine("Finished"));
      });

   var rootTask = new Task(
      () =>
      {
         Console.WriteLine("Begin");
      });

   rootTask.ContinueWith(it => createNextTask(0).Start());
   rootTask.Start();
   Console.ReadLine();
}
``` 

If you have followed that far, I don’t think I need to comment on the last bit of code I just added – so we are done for today: we wrote an absurdly complicated implementation of FizzBuzz, using only tasks and no loops. The resulting code is perfectly useless, but I hope that you found it interesting nevertheless!
