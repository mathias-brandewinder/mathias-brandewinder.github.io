---
layout: post
title: Using FSI to execute F# code from a .NET app
tags:
- FSI
- REPL
- F#
- Add-In
- Script
- Scripting
- C#
---

I have been obsessing about the following idea lately – what if I could run a FSI session from within Excel? The motivation behind this is double. First, one thing Excel is good at is creating and formatting charts. If I could use F# for data manipulation, and Excel for data visualization, I would be a happy camper. Then, I think F# via FSI could provide an interesting alternative for Excel automation. I’d much rather leverage existing .NET libraries to, say, grab data from the internet, than write some VBA to do that – and the ability to write live code in FSI would be less heavy handed that VSTO automation, and closer to what people typically do in Excel, that is, explore data. Having the ability to execute F# scripts would be, at least for me, very useful. 

Seeing [Tim Robinson](https://twitter.com/1tgr)’s awesome job with [**FsNotebook.net**](https://fsnotebook.net/) kicked me out of procrastination. Even though FsNotebook is still in early development, it provides a very nice user experience – on the web. If something that nice can be done on the web, it should be feasible on a local machine. 

*As an aside, Tim is looking for feedback and input on FsNotebook – go try it out, it’s really fun:*

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">Anyone want to help me test my new <a href="https://twitter.com/hashtag/fsharp?src=hash">#fsharp</a> project? <a href="https://t.co/7u2lLROb">https://t.co/7u2lLROb</a></p>&mdash; Tim Robinson (@1tgr) <a href="https://twitter.com/1tgr/status/272497483186323456">November 25, 2012</a></blockquote> <script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

Anyways – this is the grand plan, now we need to start with baby steps. If I want to embed FSI in Excel (presumably via a VSTO add-in), I need a way to talk to FSI from .NET, so that I can create a Session and send arbitrary strings of code to be evaluated. 

<!--more-->

As usual, StackOverflow provided two good starting points ([this answer](http://stackoverflow.com/a/4638482/114519), and [this answer](http://stackoverflow.com/a/1563095/114519)) – so I set out to look into the **`Process`** class, which I didn’t know much about, and attempted to spawn a FSI.EXE process, redirecting input and output. Turns out it’s not overly complicated – here are the 34 lines of code I ended up with so far ([see it on GitHub](https://github.com/mathias-brandewinder/FsiRunner/blob/5795a06b9580affb321b1b13f359aa8600a8c91a/FsiRunner/FsiRunner/Session.fs))


``` fsharp
namespace ClearLines.FsiRunner

open System.Diagnostics

type public FsiSession(fsiPath: string) =

    let info = new ProcessStartInfo()
    let fsiProcess = new Process()

    do
        info.RedirectStandardInput <- true
        info.RedirectStandardOutput <- true
        info.UseShellExecute <- false
        info.CreateNoWindow <- true
        info.FileName <- fsiPath

        fsiProcess.StartInfo <- info

    [<CLIEvent>]
    member this.OutputReceived = fsiProcess.OutputDataReceived

    [<CLIEvent>]
    member this.ErrorReceived = fsiProcess.ErrorDataReceived

    member this.Start() =
        fsiProcess.Start()
        fsiProcess.BeginOutputReadLine()

    member this.AddLine(line: string) =
        fsiProcess.StandardInput.WriteLine(line)

    member this.Evaluate() =
        this.AddLine(";;")
        fsiProcess.StandardInput.Flush()

``` 

This is a fairly straightforward class. The constructor expects the path to FSI.EXE, and sets up the process in the constructor (the **`do`** block) to run headless and redirect the stream of inputs and outputs. **`Start`**() simply starts the process, and begins reading asynchronously the output of FSI, **`AddLine`**(line) is used to add an arbitrary string of F# code, and **`Evaluate`**() sends all lines currently buffered to FSI for evaluation – and flushes the buffer. The 2 events **`OutputReceived`** and **`ErrorReceived`** are provided for the client to listen to the FSI results.

So how would you use this? I put together a quick-and-dirty C# Console app to demonstrate ([see the code on GitHub](https://github.com/mathias-brandewinder/FsiRunner/blob/2911b7ff557eeca2fba486165121503771a7cd2c/FsiRunner/ConsoleDemo/Program.cs)):

``` fsharp
namespace ConsoleDemo
{
    using System;
    using System.Diagnostics;
    using ClearLines.FsiRunner;

    public class Program
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("Beginning");
            // This is the path to FSI.EXE on my machine, adjust accordingly
            var fsiPath = @"C:\Program Files (x86)\Microsoft F#\v4.0\fsi.exe";
            var session = new FsiSession(fsiPath);

            // start the session and hook the listeners
            session.Start();
            session.OutputReceived += OnOutputReceived;
            session.ErrorReceived += OnErrorReceived;

            // Send some trivial code to FSI and evaluate
            var code = @"let x = 42";
            session.AddLine(code);
            session.Evaluate();

            // Send a code block of 4 lines, using whitespace
            // note how x, which was declared previously,
            // is used in f as a closure, and still available.
            var line1 = @"let f y = x + y";
            var line2 = @"let z =";
            var line3 = @"   [ 1; 2; 3]";
            var line4 = @"   |> List.map (fun e -> f e)";

            session.AddLine(line1);
            session.AddLine(line2);
            session.AddLine(line3);
            session.AddLine(line4);
            session.Evaluate();

            // random "code" which is definitely not F#
            // nothing crashes but we don't get any output?
            var error1 = "Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn";
            session.AddLine(error1);
            session.Evaluate();

            // In spite of invoking Cthulhu before,
            // our session is still healthy and evaluates this
            var code2 = @"let c = 123";
            session.AddLine(code2);
            session.Evaluate();

            // wait for user to type [ENTER] to close
            Console.ReadLine();
        }

        private static void OnOutputReceived(object sender, DataReceivedEventArgs e)
        {
            Console.WriteLine("FSI has happy news:");
            Console.WriteLine(e.Data);
        }

        private static void OnErrorReceived(object sender, DataReceivedEventArgs e)
        {
            Console.WriteLine("FSI has bad news:");
            Console.WriteLine(e.Data);
        }
    }
}
``` 

We start our session, and start passing “blocks” of code as strings to FSI, in 4 “passes”. In the first step, we simply declare x to be 42; then we pass in a block of 4 lines of code, re-using x as a closure and proving the point that x is still “alive” in the session. We send in some random string for good measure, and then back some code. Running this should produce something along these lines in your Console window:

```
Beginning
FSI has happy news:

FSI has happy news:
Microsoft (R) F# 2.0 Interactive build 4.0.40219.1
FSI has happy news:
Copyright (c) Microsoft Corporation. All Rights Reserved.
FSI has happy news:

FSI has happy news:
For help type #help;;
FSI has happy news:
FSI has happy news:
>
FSI has happy news
val x : int = 42
FSI has happy news:

FSI has happy news:
>
FSI has happy news:
val f : int -> int
FSI has happy news:
val z : int list = [43; 44; 45]
FSI has happy news:

FSI has happy news:
> 
FSI has happy news:
val c : int = 123
FSI has happy news:
```

This is pretty much what you would get if you had pasted that code directly in FSI – except that we sent all that from a C# application.

## A few comments

In my sample, I pointed the Session to the FSI.EXE which ships with Visual Studio. I actually tried it also with the one in the F# open-source on GitHub – it worked, but was significantly slower. Given that I am not embedding anything, I don’t think there is any license issue there.

When I passed in the string "Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn" as code, I expected to get some form of response from FSI, either an error or some form of message signaling that this wasn’t quite right. I got Zilch. The good news is, the session didn’t go down in flames – but I would like to get the same error message I get from FSI in Visual Studio. Maybe I need to pass an argument to FSI when I start it?

*Edit, Dec 4, 2012: see Leaf’s comment below – displaying the errors simply requires redirecting Standard Errors, in a fashion similar to Standard Output. Added to [this commit](https://github.com/mathias-brandewinder/FsiRunner/commit/e9b504f02c7cd185838cd7bed95dcb63e769c24b), it works like a charm. Thanks [Leaf](https://twitter.com/leafgarland)!*

I struggled a bit with triggering the evaluation. I might have missed something, but I originally tried out the synchronous route, and failed: `fsiProcess.StandardInput.Flush()` would simply not do anything (to be more specific, `fsiProcess.StandardOutput.ReadToEnd()` would never return), and the only way I managed to trigger an evaluation was to do `fsiProcess.StandardInput.Close()`, which is obviously problematic. I am fine for now with the async version, but if anybody knows how to get the other approach working (essentially passing code for evaluation, and blocking until FSI is done) I would be very interested.

Disclaimer: I have made zero effort to clean up after the session finishes – I don’t even know if it matters, and will look into it later. Now you are warned.

## So what?

As I said earlier, baby steps! We managed to start a FSI session from within a C# application, and send arbitrary strings to FSI, letting it work its magic. Now the next step will be to create a simple editor Control where users can type in that code and send it to FSI – that shouldn’t be too hard. 

I’d love to hear comments or criticism – this is the first time I ventured into Diagnostics.Process, so it’s perfectly possible that things could be done better.

You can find the code [here on GitHub](https://github.com/mathias-brandewinder/FsiRunner/tree/2911b7ff557eeca2fba486165121503771a7cd2c).

I would also be very interested in hearing any feedback on the idea of a FSI session in Excel. There is obviously still quite a bit of work to be done until I am there, but any thoughts on the topic (how you might use it, if you think it’s the worst idea of the year, whether it would be better to have an add-in inside Excel or an app controlling an Excel instance…) would help me make this something that could, you know, even be useful?
