---
layout: post
title: Silicon Valley Code Camp material
tags:
- Mocks
- F#
- Presentation-Material
- Moq
- Rhino.Mocks
- NSubstitute
---

Huge thanks to everyone who came to my presentations at Silicon Valley Code Camp this year – and to the organizers. It’s amazing to me how the event has been growing up year after year, and yet retains its friendly atmosphere, and smooth organization.  

## For Those About to Mock  

I uploaded the entire code sample, illustrating how to roll your own, and how to achieve the same result with Moq, Rhino and NSubstitute [**here**]({{ site.url}}/downloads/Mocks.zip). The slides are included as well. Note that it assumes you have installed [NUnit](http://www.nunit.org/) on your machine. If this isn’t the case, some of the projects won’t build.  

## An excursion in F#  

The code sample is uploaded [**here**]({{ site.url}}/downloads/ExcursionInFSharp.zip). I must say, I was very pleasantly surprised by the level of enthusiasm of the audience, especially so because it was very late in the program. Sorry again for the string of technical glitches, and thank you for being really awesome, this session was a memorable one for me, thanks to you all!  

Notes:  
1) one of the projects (FSharp.StockReader) will not build unless you have the [F# PowerPack](http://fsharppowerpack.codeplex.com/) installed on your machine, because it uses the Async extensions which come with it. Either install it, or unload FSharp.StockReader and CSharp.ConsoleClient.  

2) In Stocks.FSharp.Scripts, you will have to modify the first line of the code to point to the location of FSharpCharts.fsx on your local machine.  

That’s it! I haven’t added material for the TDD session because all the code was written live, and the slide deck can be largely summarized with Red, Green, Refactor – if you want me to add that as well, let me know!
