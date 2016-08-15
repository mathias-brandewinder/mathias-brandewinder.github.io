---
layout: post
title: Still obsessing on FSI and Excel
tags:
- F#
- Excel
- FSI
- Scripting
---

I am still toying with the idea of using FSI from within Excel - wouldn't it be nice if, instead of having to resort to VBA or C# via VSTO, I could leverage F#, with unfettered access to .NET and a nice scripting language, while having at my disposal things like the charting abilities of Excel?

Judging from the discussion on Twitter this morning, it seems I am not the only one to like the idea of F# in Excel:

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr"><a href="https://twitter.com/jonharrop">@jonharrop</a> <a href="https://twitter.com/dnesteruk">@dnesteruk</a> <a href="https://twitter.com/7sharp9">@7sharp9</a> <a href="https://twitter.com/dsyme">@dsyme</a> the F# plugin for MonoDevelop &amp; <a href="http://t.co/C81jvUjf">http://t.co/C81jvUjf</a> can provide a foundation, I&#39;d like F# in Excel ;)</p>&mdash; Sean&#39;s dad (@ptrelford) <a href="https://twitter.com/ptrelford/status/293044073126850560">January 20, 2013</a></blockquote> <script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

I am still far from this perfect world, and wouldn't mind some input from the F# community, because I am having a hard time figuring out where the sweet spot is. At that point, what I have is a pretty rudimentary WPF FSI editor, written in C#.

<!--more-->

*Note: yes, I should have written it in F#, shame on me! I am still more comfortable with the WPF/C# combo at the moment, but getting increasingly uncomfortable with XAML and the amount of magic string involved in data binding. [Jon Harrop](https://twitter.com/jonharrop) presented some very stimulating ideas on this topic at the last [San Francisco F# user group](http://www.meetup.com/sfsharp/events/93396482/), I intend to try the NoXAML route at a later point.*

Anyways, you can find my rudimentary editor [here on GitHub](https://github.com/mathias-brandewinder/FsiRunner), with a crude [WPF demo](https://github.com/mathias-brandewinder/FsiRunner/tree/master/FsiRunner/WpfDemo). Running it should produce something like this:

![Editor]({{ site.url }}/assets/2013-01-20-Editor.PNG)

I quite liked how [FsNotebook](https://fsnotebook.net/) organized the code into blocks and separated the inputs and outputs, so I followed the same idea: you can add new sections at the top and evaluate each one separately, and see the result at the bottom. There is obviously plenty of work to do still, but at least this is a working prototype.

*Note: the code is still pretty ugly, and totally not ready for prime time. Specifically, resources aren't disposed properly at all - use at your own peril!*

Now the question I am facing is the following: what would be a good way to expose FSI in Excel (assuming this is not a terrible idea...)? Technically, this can already be used to work against Excel. As a demo, start Excel, then the Editor, and try out the following code:

{% gist 4582881 %}

If everything works according to plan, the script should find your already-running Excel instance, and write "Hello from F#" in cell A1 of the first worksheet. Nothing spectacular, but it proves the point - I can fire up the editor, run a small script and get full Excel interop from FSI.

At that point, the obvious question is - that's great, but how is this better from running FSI from the Console, Visual Studio or [FunPad](http://funpad.codeplex.com/)?

The answer is, there isn't much difference. The one upside I could see is that it is feasible to add niceties like syntax highlighting or saving some configuration, but that's pretty much it.

One thing I was considering is embedding the Editor as a VSTO add-in, which could provide a smoother integration with Excel, and open possibilities like hosting a service in the add-in for dedicated operations like "import the selected range into FSI" or "export my FSI data and make a chart from it". That was my initial idea, but I am starting to doubt whether it's a good one: VSTO is notoriously heavy, and comes with its own set of issues (dependence on the VSTO runtime or on specific versions of Office and Visual Studio&hellip;) and it's not obvious what the upside is.
So&hellip; if you are interested in using FSI in Excel (or think it's the worst idea you heard in 2013 so far), I'd love to hear your thoughts! My initial use case was something along the lines of using Excel as a replacement for FSharpChart, but for this I wouldn't need much beyond a thin DSL. What are your use cases? How would you combine F# and Excel?

## Resources

[Current code on GitHub](https://github.com/mathias-brandewinder/FsiRunner/tree/fcf9d44d0cb884762cdec89dd5da1edf931be064)

[ExcelDNA](http://exceldna.codeplex.com/): if you want a lightweight way to expose .NET functions as Excel user-defined functions, this library is probably what you want. I actually don't understand why this library hasn't gotten more traction, it's really neat.
