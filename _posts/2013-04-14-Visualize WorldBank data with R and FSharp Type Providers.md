---
layout: post
title: Visualize WorldBank data with R and F# Type Providers
tags:
- F#
- R
- World-Bank
- Type-Provider
- Video
- Visualization
---

Last Thursday, I gave a talk at the [Bay.NET user group in Berkeley](http://www.meetup.com/BayNET/events/112730182/), introducing F# to C# developers. First off, I have to thank everybody who came – you guys were great, lots of good questions, nice energy, I had a fantastic time! My goal was to highlight why I think F# is awesome, and of course this had to include a Type Provider demo, one of the most amazing features of F# 3.0. So I went ahead, and demoed [Tomas Petricek](https://twitter.com/tomaspetricek)’s [World Bank Type Provider], and [Howard Mansell](https://twitter.com/hmansell)’s [R Type Provider](https://github.com/BlueMountainCapital/FSharpRProvider) – together. The promise of Type Providers is to enable information-rich programming; in this case, we get immediate access to a wealth of data over the internet, in one line of code, entirely discoverable by IntelliSense in Visual Studio - and we can use all the visualization arsenal of R to see what’s going on. Pretty rad. 

Rather than just dump the code, I thought it would be fun to turn that demo into a video. The result is a 7 minutes clip, with only minor editing (a few cuts, and I sped up the video x3 because the main point here isn’t how terrible my typing skills are). I think it’s largely self-explanatory, the only points that are worth commenting upon are:  

* I am using a NuGet package for the R Type Provider that doesn’t officially exist yet. I figured a NuGet package would make that Type Provider more usable, and spent my week-end creating it, but haven’t published it yet. Stay tuned! 
* The most complex part of the demo is probably R’s syntax from hell. For those of you who don’t know R, it’s a free, open-source statistical package which does amazingly cool things. What you need to know to understand this video is that R is very vector-centric. You can create a vector in R using the syntax `myData <- c(1,2,3,4)`, and combine vectors into what’s called a data frame, essentially a collection of features. The R type provider exposes all R packages and functions through a single static type, aptly named R – so for instance, one can create a R vector from F# by typing `let myData = R.c( [|1; 2; 3; 4 |])`. 

That’s it! Let me know what you think, and if you have comments or questions. 

<iframe width="420" height="315" src="https://www.youtube.com/embed/_BOST3W88-Y" frameborder="0" allowfullscreen></iframe>
