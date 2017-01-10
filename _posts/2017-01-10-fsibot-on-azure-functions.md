---
layout: post
title: New relase of @fsibot, now on Azure Functions
tags:
- F#
- Azure-Functions
- Azure
- fsibot
- Serverless
- Cloud
- Bot
- Twitter
---

About 2 years ago, I wrote a little application, [@fsibot]({{ site.url }}/2014/09/13/fsibot-enterprise/). [@fsibot](https://twitter.com/fsibot/with_replies) is a Twitter bot which, when it receives a Tweet that is a valid F# expression, will evaluate it and return the result to the sender. Got to code FizzBuzz in an interview? Impress your audience, and send a Tweet from your cell phone to @fsibot:

<blockquote class="twitter-tweet" data-lang="en"><p lang="ht" dir="ltr"><a href="https://twitter.com/brandewinder">@brandewinder</a> 1,2,Fizz,4,Buzz,Fizz,7,8,Fizz,Buzz,11,Fizz,13,14,FizzBuzz,16,17,Fizz,19,Buzz,Fizz,22,23,Fizz,Buzz,26,Fizz,28,29,FizzBuzz [...]</p>&mdash; fsibot (@fsibot) <a href="https://twitter.com/fsibot/status/818767377273864192">January 10, 2017</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

It was very fun to write, rather pointless, but turned out to be an interesting exercise, which [taught me a lot][1]. And, in spite of its simplicity, it's a decent sample app, which touches on many aspects a real-world app might encounter.

After some hiccups early on, @fsibot has been running pretty smoothly, until I noticed issues recently. Rather than trying to figure out what the hell was going on, I decided to port it over [Azure Functions][2], which sounded like a better fit for it. While at it, I also made a couple of changes to the bot. If you are interested, you can [find the code on GitHub][3].

<!--more-->

## New features

@fsibot "Classic" was designed to evaluate F# expressions. This ended up creating some frustration, because the behavior was unexpectedly different from the F# Interactive experience people were used to. In particular, while typing `printfn "hello"` in FSI produces a nice and friendly `hello`, @fsibot would respond with a much less pleasant `null`. @fsibot also required expressions to be written in the "non light" syntax, which is not that common.

Long story short, @fsibot now supports expressions and interactions (thanks [@tomaspetricek](https://twitter.com/tomaspetricek) for the helpful FCS pointers!), and, minus some security-related restrictions, behaves more or less the same way FSI does. You can now use pretty much everything, from `printfn` to `#time` or creating your own discriminated unions, as long as it fits in under 132 characters:

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr"><a href="https://twitter.com/brandewinder">@brandewinder</a> hello<br><br>type Foo =<br>  | Bar of int<br>  | Baz of string<br>val f : _arg1:Foo -&gt; unit<br>val it : unit = ()</p>&mdash; fsibot (@fsibot) <a href="https://twitter.com/fsibot/status/818204138353917953">January 8, 2017</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

No IntelliSense yet, but @fsibot now also returns potentially helpful error messages for invalid code:

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr"><a href="https://twitter.com/brandewinder">@brandewinder</a> The type &#39;string&#39; does not match the type &#39;int&#39;<br>The type &#39;string&#39; does not match the type &#39;int&#39;</p>&mdash; fsibot (@fsibot) <a href="https://twitter.com/fsibot/status/818484983044128769">January 9, 2017</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

## Under the hood: Azure Functions

Before talking about the why, I should probably start with what Azure Functions are. In a nutshell, an Azure Function is a script, which will run whenever a particular triggering event occurs. Triggers can be many things, from a timer, to an http request, or a message showing up in a queue. At a minimum, a function boils down to 2 files in a folder, the script, and bindings, a `function.json` file describing what triggers the function, and potentially other resources it might talk to. If needed, a function can also use a `project.json` file, listing the nuget dependencies the code requires. Functions can be composed together in a larger unit, a Function App.

This lent itself very well to the problem at hand. If you [take a look at the code on GitHub][3], you will see 3 folders, each containing one function:

- `check-mentions` is a timer-triggered function. Every 2 minutes, it looks for new Tweets mentioning @fsibot, and sends them to a queue. The function also reads and writes the ID of the latest Tweet processed in a blob, to make sure the same Tweet is not processed twice.
- `process-mention` is bound to that same queue. Whenever a message is found, it analyzes it, tries to run it through the F# Compiler Services, and sends the result to another queue for further processing.
- `send-tweet` picks up from that queue, composes a Twitter response, and sends it to the original author.

That's pretty much it - the whole application now fits in 3 folders, with a grand total of 11 fairly small (and hackish) files.

## Why Azure Functions?

So why did I pick Azure Functions?

The obvious reason is price. My original setup used a couple of TopShelf windows services, running on the cheapest VM I could get on Azure, which was costing me about 12 USD / month. This isn't insanely expensive, but, let's face it, given the limited usage of @fsibot, I was paying mostly for a machine doing nothing.

By contrast, with Azure Functions, you pay only for the time your code is running, which is perfect for my use case. At [$0.20 per million executions][4], my coffee budget suddenly got a nice boost.

@fsibot was my first foray into Azure Functions. In hindsight, I have also found them to be a great fit with F#. I tend to use F# scripts quite a lot to sketch out designs. Feedback is immediate, and the language simplicity lets me focus quickly on the code, and doesn't get in the way. At the same time, there is a small effort required to move from script to production: Azure Functions fills just that gap. I can now take that script all the way, and easily fill in the missing pieces, with minimal efforts. Need a queue? Just declare it, and it's there for you to use. Scaling, build, deployment? Just connect your GitHub repository, and it's done. I can focus on what matters, the code, without getting bogged down in plumbing details. Lovely.

This turned out to be a huge productivity improvement over my previous setup. Maintaining a VM, two services and a queue did create a lot of friction; as an extra bonus, RDPing into a minuscule VM to trouble-shoot issues isn't something I wish on anyone. By contrast, in spite of a few rough edges - at the time I begun, Functions were in preview - the process is now extremely smooth: I have a grand total of 11 files to maintain, I edit them in Code, push, and I am done.

## What next?

There are a couple of improvements I'd like to make, and yes, the code is quite hacky in places, but it's good enough to ship, so let's ship it! I'd love your feedback - try it out, and let me know what you think, and if there is something you'd like to see added or changed.

And otherwise, I encourage you to take a look at Azure Functions. In a way, I have found F# and Functions to share similar qualities: writing code is productive, and... simply fun. On top of that, the team "gets" open-source: everything is in the open, they listen, and the experience improves literally every day. And F# support is quite nice! So again, try it out, and let them know what you think.

Finally, I am considering writing a more detailed post, explaining how I wrote @fsibot on Functions, step-by-step, from the ground up. The code base is not overly complex, so I am not entirely sure if this is useful. If you'd like to see such a post, ping me in the comments or [on Twitter](https://twitter.com/brandewinder)!  

[Code on GitHub][3]


[1]: https://vimeo.com/113725369
[2]: https://azure.microsoft.com/en-us/services/functions/
[3]: https://github.com/mathias-brandewinder/fsibot-serverless/tree/b5ff0ff8f16bab22bff128a0a3d21d38aeb02dc3
[4]: https://azure.microsoft.com/en-us/pricing/details/functions/