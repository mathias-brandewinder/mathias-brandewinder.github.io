---
layout: post
title: Bumblebee 0.3 is now on CodePlex (and NuGet)
tags:
- Bumblebee
- Nuget
- F#
---

I have just pushed [version 0.3 of Bumblebee](http://bumblebee.codeplex.com/) on CodePlex. Bumblebee is an Artificial Bee Colony algorithm implementation in F#. In a nutshell, it’s a randomized search method that mimics the behavior of bees looking for food, and can be suitable to find approximate solutions to large scale problems where deterministic approaches are impractical. Bumblebee provides a C#-friendly Solver, which will search for solutions to a problem, sending messages to the caller whenever an improved solution is found, until the search is stopped. It uses the Task Parallel Library to parallelize the searches as much as possible.  

The [source code](http://bumblebee.codeplex.com/SourceControl/changeset/changes/8af0311dc81a) includes two sample projects that illustrate the algorithm in action on the Travelling Salesman Problem, one in F#, one in C#, with a “fancy” WPF user interface.

What’s new in Version 0.3? Mostly code cleanup – when I revisited my original code a few months after the fact, I had a hard time following it, so I reorganized things internally in a way which I hope is clearer. The main change from an API perspective is the constructor for C# problems: I removed the Tuples from the Func delegates, which were mostly noise and didn’t help much.  

<!--more-->

Other than that, the changes are mostly cosmetic: the main Search loop has been transformed into a recursive immutable loop, code has been shuffled around and renamed for readability, the test suite has been updated and uses the FsUnit NuGet package.  

Speaking of NuGet, I published [Bumblebee as a NuGet package here](https://nuget.org/packages?q=bumblebee)
<a href="https://nuget.org/packages?q=bumblebee">Bumblebee as a NuGet package here</a>. It’s my first NuGet package, so hopefully I haven’t messed up anything there – if you see anything amiss, please let me know!  

That’s it for the moment. I am working on some ideas right now, the main one being to use Azure to allow Bumblebee to scale out and attack larger problems – we’ll see how that turns out. I kept Bumblebee as Alpha stage, as I may still change the API in the future.  
On a related note, I will be travelling to Boston mid-June, where I will have the pleasure to present Bumblebee at the [New England F# user group](http://fsug.org/SitePages/Home.aspx). I am extremely excited about this opportunity (thanks to [Talbott Crowell](https://twitter.com/#!/talbott) for the invitation!) - I plan on discussing the algorithm and its implementation, writing F# code live to solve a problem and hopefully show why F# is so fun to work with, and talk in general about my experience learning F# after years of C# development. I am really looking forward to it, and hope to see some of you there!
