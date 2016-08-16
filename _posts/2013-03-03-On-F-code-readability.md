---
layout: post
title: On F# code readability
tags:
- F#
- Readability
- Code
---

Recently, I had a few interesting discussions on F# code readability. One argument I often hear about F# is that by virtue of its succinctness, it [increases the signal-to-noise ratio](http://www.servicestack.net/mythz_blog/?p=765). I certainly found this to be true: when the entire code fits on your screen, and you don’t have to scroll around to figure out what is going on, navigating a code base becomes significantly simpler. Relatedly, because the F# syntax is so much lighter than C#, some of my coding habits evolved. I stick to the “[one public type per file](http://blogs.msdn.com/b/brada/archive/2005/01/26/361363.aspx)” guideline in C#, and initially did the same in F#. 

That didn’t last long: declaring a Record Type in F# is a one-liner, and dedicating an entire file to it seems… overkill:

``` fsharp
type Person = { FirstName: string; LastName: string; BornOn: DateTime }
``` 

As a result, my F# solutions tend to contain less files, and each file is more “self-contained”, usually declaring a couple of types and implementing some operations involving these types in a module. Again, less navigation required: open one file, and the truth, the whole truth, and nothing but the truth is right there on your screen.

In my experience, this also makes refactoring tools much less important in F# than C#. The lack of refactoring tools in F# used to be one of my main gripes with using the language. At that point, I don’t really care that much any more, because I don’t really need them that badly. Sure, it would be nice to propagate a rename automatically – but lots of the refactoring tools I commonly use with C# deal with navigating around or moving pieces of code from file to file (extract class, method, etc…), all problems that are minor when your code sits in just a couple of files, and the “what class owns what responsibility” issue vanishes because your functions are at a module level.

Conversely, I have found myself annoyed a few times looking at F# code where succinctness erred on the side of obfuscation. This tendency for terse naming conventions seems to be a cultural heritage from other functional languages, and makes sense to an extent – functional code tends to focus on applying generic transformations to “things”, and not that much on what the “thing” might be.

As an illustration, I have seen often code along these lines:

``` fsharp 
match list with
| x::xs -> ...
``` 

No need to go [full on](http://static.springsource.org/spring/docs/2.5.x/api/org/springframework/aop/framework/AbstractSingletonProxyFactoryBean.html) [Java](http://javadoc.bugaco.com/com/sun/java/swing/plaf/nimbus/InternalFrameInternalFrameTitlePaneInternalFrameTitlePaneMaximizeButtonPainter.html) on your code, but a bit of naming effort goes a long way in making code intelligible:  

``` fsharp
match list with
| head::tail -> ...
``` 

That being said, extreme terseness can be fun, at times – I don’t think I’ll see a C# [Game of Life implementation that fits in a Tweet](http://trelford.com/blog/post/140.aspx) any time soon :)

Another readability aspect I found interesting with F# code is that the order of declarations matters, and the order of the files in the project matters as well. This seemingly odd constraint has a good reason – it makes the awesome F# type inference work.

Over time, I actually began to appreciate this not as a constraint, but almost as a feature. One problem I keep running into when I look into a C# code base I am not familiar with is “damn! where should I start?”. There is no clear way to proceed through the code, and I have ended up countless times navigating haphazardly from class to class, hoping to stumble upon a solid starting point.

I don’t really have that problem with F# code bases – essentially, I either start from the first line of the first file, and read forward, or the last line of the last file, working my way back. Either way works; the first one reads like a constructive proof, walking you every step to the ineluctable conclusion, the second one starts with the “high point” of the code base, digging progressively into the nitty-gritty and assumptions that were made to get there.
Someone reacted by saying that I was “just rationalizing”. There is probably some truth in that – but I believe there is something to be said for having a natural reading order in a code base. As a side-note, this is also one of my minor annoyances with GitHub: in the browser, the files from an F# repository are displayed in alphabetical order, which loses the logical project organization.

I might also change my tune when I have to deal with a truly large F# code base, which hasn’t happened to me yet. At that point, I may long for more freedom in organizing my code, and, say, arrange it by topical folders. For the moment, though, this hasn’t been an issue for me!
