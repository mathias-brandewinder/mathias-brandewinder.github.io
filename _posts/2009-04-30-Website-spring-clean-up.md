---
layout: post
title: Website spring clean-up
tags:
- Css
- Website
- Web-Design
- Asp.Net
- Menu
---

After much postponing, I finally cleaned up the layout of Clear Lines. I had cobbled together the previous design over a few days when I started, and, because it's not a crucial aspect of my activities, I left it at that until now. I like my new design better (I hope you do, too!), it feels much cleaner than the previous one. The main motivation was not the looks, though, but rather flexibility. I will add a few pages soon, and need to easily integrate them into the site navigation, so I finally replaced my hard-coded links by an ASP.NET menu. And while I was at it, I got inspired by [Peter Kellner](http://peterkellner.net/2009/03/27/codecampwebsiteseries6-cssfriendly-adapters-aspnet-menu/)'s beautiful menu for the [Silicon Valley Code Camp](http://www.siliconvalley-codecamp.com) site, and started looking into [Css Friendly Control Adapters](http://www.codeplex.com/cssfriendly).  

I like the fact that the whole menu layout is pure css, instead of tables, but I struggled quite a bit with getting css to play nice. Not the adapter's fault, rather my own limitations with css... In the end, I managed to get roughly the look I was after. That being said, if you open the page in IE7, it will render differently than in any other browser I tried: for some reason, I couldn't get IE to change the background color of the menu links on hover, or to render properly a border-bottom. If anyone has an idea what's wrong with my css, I would love to hear it! Next step: upgrade the blog to BlogEngine 1.5, and probably add a sub-menu to the pages, similar to the Code Camp site.
