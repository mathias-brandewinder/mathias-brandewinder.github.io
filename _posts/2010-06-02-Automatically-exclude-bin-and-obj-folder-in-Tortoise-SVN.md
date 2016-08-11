---
layout: post
title: Automatically exclude bin and obj folder in Tortoise SVN
tags:
- Tips-And-Tricks
- Subversion
- Tortoise
- Svn
---

It seems like all the cool kids are using either Git or Mercurial these days, so I feel like a dinosaur sticking to Subversion and Tortoise for version control. In the meanwhile, I just figured out a small Tortoise trick yesterday.   

In my experience, the number one dumb mistake that happens with Subversion is adding a new file in a project, and forgetting to add that new file when committing. To avoid this, before a commit, I right-click on my project, and select add, which shows all the local files that haven’t been added to the repository. The problem is that you get a bazillion files this way, some of them you know you are never going to add, like the Bin and Obj folders for instance.  

![AddFiles]({{ site.url }}/assets/2010-06-02-AddFiles_thumb.png)   

Easy fix: right-click TortoiseSVN, settings, and you’ll see the following:  

![TortoiseSettings]({{ site.url }}/assets/2010-06-02-TortoiseSettings_thumb.png)   

The text box “**Global ignore pattern**” defines what patterns you want to exclude; in my case I wanted to remove bin and obj folders, and ReSharper related files, which typically contain _ReSharper, so I added   bin obj *_ReSharper*  to the list of patterns. Et voila! Once again, I just wish I had taken the time to read the user manual. This type of dumb process detail just takes a few seconds here and there, but adds up over time; I wouldn’t want to know how many hours I spent un-selecting files in this list over the last 5 years…
