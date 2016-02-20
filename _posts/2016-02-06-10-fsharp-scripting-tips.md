---
layout: post
title: 10 Tips for Productive F# Scripting
tags:
- F#
- Script
- FSI
- REPL
---

Scott Hanselman recently had a [nice post on C# and F# REPLs][1], which reminded me of the time I started using F# scripts. Over time, I found out a couple of small tricks, which helped make the experience productive. I found about them mainly by accident, so I figured, let's see if I can list them in one place! Some of these are super simple, some probably a bit obscure, but hopefully, one of them at least will make your path towards scripting nirvana an easier one...

> Note: these tips are not necessarily ordered by usefulness. For that matter, there might or might not be exactly 10 of them :)

<!--more-->

## Tip 1: Use `.fsx` Files for Interactive Coding

You can use the F# Interactive 2 ways: you can directly type code into FSI, the F# Interactive window, or you can write code in an `.fsx` file, and select pieces of the code you want to execute. I recommend the second approach, for at least two reasons. First, FSI is a very primitive environment, `.fsx` files provide a much richer experience (IntelliSense). Then this encourages writing clean scripts you can reuse later.

> This is not specific to scripts, but... if you are on Visual Studio, do yourself a service and install the [Visual F# Power Tools][13] - you'll get nice things such as better code highlighting, refactoring, and more.

To execute code interactively, simply type code in an `.fsx` file, select a block of code, and hit <kbd>Alt</kbd> + <kbd>Enter</kbd>. The selected code will be evaluated, and the result will show up in the FSI window. In Visual Studio, you can also select code and right-click "Execute in Interactive", but shortcuts are way faster.

> You can also execute a single-line with <kbd>Alt</kbd> + <kbd>'</kbd>. I rarely use this option, but this can save you time because you don't need to select the entire line of code.

> In case the keyboard shortcuts to send code to FSI do not work anymore (ReSharper used to over-write them in the past), you can reset them in Visual Studio, by going to Tools / Options / Environment / Keyboard. The 2 commands you need to map are **EditorContextMenus.CodeWindow.ExecuteInInteractive** and **EditorContextMenus.CodeWindow.ExecuteLineInInteractive**.

You can also use these shortcuts from a regular `.fs` file, which can be handy if you want to validate that a piece of code is behaving the way you want.

> Interactive coding is by far my main usage for scripts - I use it extensively to prototype designs, run dumb tasks, or explore data or libraries. I realized recently that a few of my C# friends use LinqPad for the same purpose.  

## Tip 2: What is `it`?

While I encourage working primarily from `.fsx` files, the FSI window is also very helpful. I use it primarily for small verifications. For instance, I might have in my script file code like this:

``` fsharp
let add x y =
  x + y
```

Once I send it for evaluation into FSI, I will see the following show up in FSI:

``` fsharp
val add : x:int -> y:int -> int
>
```

My function `add` is now in memory, in my FSI session; I can start typing in the FSI window and use it:

``` fsharp
> add 1 2;;
val it : int = 3
>
```

<kbd>Enter</kbd> does not trigger execution in FSI. The `;;` indicates to FSI "Please execute everything I just typed, up to that point". This is useful if you want to type multiple lines of code in FSI, and execute them as a block.

> `it`: in our `add 1 2` example, the result showed up as `it`. We simply ran add, but didn't assign the result to anything. `it` now contains the result, until we run another expression. If you want to re-use that value, you can assign it in FSI, by doing for instance `let x = it;;`.

> Once a value is loaded in your FSI session, it will remain there, available to you until you shadow it (in the example above, `x` will remain available, until I run for instance `let x = 42;;`). This is extremely convenient: for instance, you can load a data file once `let data = File.ReadAllLines path`, and keep using `data` for as long as you want, without having to reload it between code changes.

> FSI often shows an abbreviated version of values for large items. For instance, `[1..999]` will show up as `val it : int list =
  [1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15; 16; 17; 18; 19; 20; 21;
   22; 23; 24; 25; 26; 27; 28; 29; 30; 31; 32; 33; 34; 35; 36; 37; 38; 39; 40;
   41; 42; 43; 44; 45; 46; 47; 48; 49; 50; 51; 52; 53; 54; 55; 56; 57; 58; 59;
   60; 61; 62; 63; 64; 65; 66; 67; 68; 69; 70; 71; 72; 73; 74; 75; 76; 77; 78;
   79; 80; 81; 82; 83; 84; 85; 86; 87; 88; 89; 90; 91; 92; 93; 94; 95; 96; 97;
   98; 99; 100; ...]` - note the ... at the end, which indicate that there is more.

What if you inadvertently started a very long computation, or an infinite loop? In Visual Studio, you can either kill the session entirely, by right-clicking over the FSI window and selecting "Reset Interactive Session" or <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>R</kbd>, or cancel the latest evaluation you requested ("Cancel Interactive Evaluation", or <kbd>Ctrl</kbd> + <kbd>Break</kbd>.).

## Tip 3: Run Scripts from the Command Line

Besides interactive scripting, you can also run a script from the command line, by using `FSI.exe`:

```>fsi.exe "C:\myscript.fsx"```

> `FSI.exe` is typically located at `C:\Program Files (x86)\Microsoft SDKs\F#\4.0\Framework\v4.0`. You can also install it separately, see [fsharp.org/use][2] section for instructions for various platforms.

You can define different behaviors in your script, depending on whether it is run interactively or from the command line, like this:

``` fsharp
#if INTERACTIVE
    let msg = "Interactive"
#else
    let msg = "Not Interactive"
#endif

printfn "%s" msg
```

For more information on FSI from the command line, [check the reference page here][3].

*Updated, Feb 20: [Ramon Soto Mathiesen](https://twitter.com/genTauro42) points out that [Tip 9 also applies to the command line](https://twitter.com/genTauro42/status/696407757835132928).*

## Tip 4: Use Relative Paths

Sometimes, your script will reference another resource; for instance, you need to read the contents of a `.txt` file somewhere. You can use absolute path, as in:

``` fsharp
File.ReadAllLines @"C:/data/myfile.txt"
```

> Pre-pending a string with `@` makes it a verbatim string, and ignore escape sequences, such as `\`.

> Use `/` rather than `\`, so that path work both on Windows and Mono.

However, if that resource lives in a location relative to your script, consider using relative path, so that you can move your script folder around without breaking it.

Relative paths can be a bit tricky; for instance, running the following code interactively...

``` fsharp
System.Environment.CurrentDirectory
```

... produces a potentially unexpected result in FSI:

```
val it : string = "C:\Users\Mathias Brandewinder\AppData\Local\Temp"
>
```

You can avoid these issues by using built-in constants, which refer respectively to the directory where the script lives, the script file name, and the current line of the script:

```
__SOURCE_DIRECTORY__
__SOURCE_FILE__
__LINE__
```

So if your folder structure was along these lines...

```
root
  /src/script.fsx
  /data/data.txt
```

... you could refer to the data file `data.txt` from your script like this:

``` fsharp
let path = System.IO.Path.Combine(__SOURCE_DIRECTORY__,"..","data/data.txt")
System.IO.File.ReadAllText path
```

## Tip 5: Including Assemblies

By default, FSI loads `FSharp.Core` and nothing else. If you want to use `System.DateTime`, you will need to first `open System` in your script. If you want to use an assembly that is not part of the standard .NET distribution, you will need to reference it first using `#r`. Imagine for instance that you installed the Nuget package `fsharp.data`; to use it in your script, you would do something like:

``` fsharp
#r @"../packages/FSharp.Data.2.2.5/lib/net40/FSharp.Data.dll"
open FSharp.Data
```

> When you execute `open System` in interactive, don't worry if nothing seems to happen: the only result is a new `>` showing up in FSI.

For assemblies that are part of .NET but not referenced by default, you can use a shorter version:

``` fsharp
#r @"System.Xaml"
open System.Xaml
```

> In Visual Studio, you can right-click a reference from Solution Explorer, and send to F# interactive. You can then directly open it, and start using it in FSI.

*Updated, Feb 20: [Sergey Tihon](https://twitter.com/sergey_tihon) shared an interesting comment, explaining where Tip 5 can sometimes go wrong. I'd say, try Tip 5 first, but be aware that this might at times not quite work:*

<blockquote class="twitter-tweet" data-conversation="none" data-cards="hidden" data-partner="tweetdeck"><p lang="en" dir="ltr"><a href="https://twitter.com/brandewinder">@brandewinder</a> don&#39;t load assemblies like in Tip 5 ) <a href="https://t.co/Owft1NmPoo">https://t.co/Owft1NmPoo</a></p>&mdash; Sergey Tihon (@sergey_tihon) <a href="https://twitter.com/sergey_tihon/status/696395229285523456">February 7, 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

*Updated, Feb 20: [F# open source contributor Don Syme](https://twitter.com/dsyme) share a related nice trick:*

<blockquote class="twitter-tweet" data-conversation="none" data-cards="hidden" data-partner="tweetdeck"><p lang="en" dir="ltr"><a href="https://twitter.com/jeroldhaas">@jeroldhaas</a> <a href="https://twitter.com/sergey_tihon">@sergey_tihon</a> <a href="https://twitter.com/brandewinder">@brandewinder</a> Use <a href="https://twitter.com/hashtag/I?src=hash">#I</a> __SOURCE_DIRECTORY__, it is wondrous, very satisfying. All relative paths then work</p>&mdash; Don Syme (@dsyme) <a href="https://twitter.com/dsyme/status/696429115184955393">February 7, 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

## Tip 6: Use `Paket`

The Nuget package manager is useful to consume existing packages. However, by default, Nuget stores assemblies in a folder that includes the package version number. This is very impractical for a script. In our example above, if `fsharp.data` gets an update, our script reference will be broken once we update the Nuget package:

`#r @"../packages/FSharp.Data.2.2.5/lib/net40/FSharp.Data.dll"`

Fixing the script requires manually editing the version number in the path, which quickly becomes a pain. [**Paket**][4] provides a better experience, because it stores packages without the version number, in this case, under:

`#r @"../packages/FSharp.Data/lib/net40/FSharp.Data.dll"`

Your scripts will now gracefully handle version number changes.

If you end up consuming numerous packages, you can make your life even easier, by referencing paths where assemblies might be searched for, using `#I`:

``` fsharp
#I @"../packages/
#r @"FSharp.Data/lib/net40/FSharp.Data.dll"
```

> If your primary goal is to "just script", consider using [Atom][5] or [VSCode][6], with the [Ionide plugin][7]. You can create and run free-standing F# scripts, with beautiful [Paket integration][8].

## Tip 7: Include Files

You might want to use the code from an existing file in your script. Suppose that we have a code file `Code.fs` somewhere, looking like this:

``` fsharp
namespace Mathias

module Common =
  let hello name = sprintf "Hello, %s" name
```

You can use that code from your script, by using the `#load` directive:

``` fsharp
#load "Code.fs"
open Mathias.Common
hello "World"
```

> You might have to close and re-open the script file if you end up changing the contents of the file.

> If the file you are attempting to load contains references to other assemblies or files, you might get an error on the `#load` statement: "One or more errors in loaded files. The namespace or module ... is not defined". Simply reference the missing assemblies above the `#load` statement, so that your script uses the same dependencies as the file it refers to.

## Tip 8: Profile your Code with &#35;time

Another handy directive, `#time`, turns on basic profiling. Once it is executed, for every block of code you send for execution you will see timing and garbage collection information. For instance, running this code...

``` fsharp
#time
[| 1 .. 10000000 |] |> Array.map (fun x -> x * x)
```

... will produce the following in FSI:

```
--> Timing now on

Real: 00:00:00.887, CPU: 00:00:00.828, GC gen0: 2, gen1: 2, gen2: 2
val it : int [] =
  [|1; 4; 9; 16; 25; 36; 49; // snipped for brevity
```

We get the wall time and CPU time it took, as well as some information about garbage collection in generations 0, 1 and 2. This would not replace a full-blown profiler, but this is an awfully convenient tool to figure out quickly if there are obvious ways to improve a piece of code.

Note that every time you execute `#time`, the timer will be switched from on to off, or vice-versa. This is not always convenient; you can also explicitly set it to the desired state, like this:

```
#time "on"
// everything now is timed
#time "off"
```

> If you are interested in profiling, you should take a look at [PrivateEye][9]; check out [Greg Young](https://twitter.com/gregyoung)'s [talk at NDC Oslo 2015](https://vimeo.com/131637366) to get a feel for what it does.

## Tip 9: Turn 64-bits on

Hat tip to [Rick Minerich](https://twitter.com/rickasaurus) for that one. I'll refer you to his blog post to see how to [set FSI to 64 bits to handle large datasets][10].

## Tip 10: Bonus Material

Did you know that you could...

* [debug an F# script? (around 0:12:35 in)][11]
* [inspect the objects in your FSI session with **FsEye**?][12]
* change the FSI font size in Tools/Options/Environment/Fonts and Colors/Show Settings for/F# Interactive?
* add your own pretty-printer to FSI, [like this](https://github.com/mathnet/mathnet-numerics/blob/master/src/FSharp/MathNet.Numerics.fsx)?
* mess with your coworkers' mental sanity, by executing `(*` (opening a multiline comment) in FSI? (credit: [Tomas](https://twitter.com/tomaspetricek))
* simplify loading references with Visual Studio and Power Tools? (credit: [Kit Eason](https://twitter.com/kitlovesfsharp), see details in comments section).

And again... if you are not using the [Visual F# Power Tools][13], you are missing out:

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">&quot;Don&#39;t let your friends try <a href="https://twitter.com/hashtag/fsharp?src=hash">#fsharp</a> without installing <a href="https://twitter.com/FSPowerTools">@FSPowerTools</a>.&quot; <a href="https://twitter.com/dsyme">@dsyme</a> at <a href="https://twitter.com/hashtag/ndclondon?src=hash">#ndclondon</a></p>&mdash; Tomas Petricek (@tomaspetricek) <a href="https://twitter.com/tomaspetricek/status/687934127627186176">January 15, 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

That's what I got! I am sure I forgot some - do you have a useful or favorite trick to share?


[1]: http://www.hanselman.com/blog/InteractiveCodingWithCAndFREPLsScriptCSOrTheVisualStudioInteractiveWindow.aspx
[2]: http://fsharp.org/
[3]: https://msdn.microsoft.com/en-us/library/dd233175.aspx
[4]: https://fsprojects.github.io/Paket/
[5]: https://atom.io/
[6]: https://code.visualstudio.com/
[7]: http://ionide.io/
[8]: http://ionide.io/#paket-integration
[9]: http://www.privateeye.io/
[10]: http://richardminerich.com/2013/03/setting-up-fsharp-interactive-for-machine-learning-with-large-datasets/
[11]: https://channel9.msdn.com/Events/Visual-Studio/Visual-Studio-2015-Final-Release-Event/Six-Quick-Picks-from-Visual-F-40
[12]: http://www.swensensoftware.com/fseye
[13]: http://fsprojects.github.io/VisualFSharpPowerTools/
