---
layout: post
title: Duct tape post-mortem
tags:
- Duct-Tape
- Learning
- Patterns-And-Practices
- Rant
---

Much ado on the interwebs has followed Joel’s recent post on the now-infamous [Duct Tape Programmer](http://www.joelonsoftware.com/items/2009/09/23.html). You have to give it to Joel, he has a talent for writing pieces which get lots of people really worked up – what in some circles is called [trolling](http://www.urbandictionary.com/define.php?term=troll). Out of curiosity, I looked up Google Trends, and unless some other piece of hot news related to duct tape surfaced on Sept 23rd, you can see with your naked eye the amount of buzz this one single post managed to generate. Impressive.  

![DuctTape]({{ site.url }}/assets/2009-10-10-DuctTape_thumb.png)

<!--more-->

At that point I think the question of whether design patterns are an evil over-engineering practice has been discussed to death, by people much more qualified than me. For what it’s worth, I think Joel’s position has merits, to a point. There **IS** a natural tendency for developers to over-engineer, and I believe it’s a good practice when designing something to keep a dialogue going between two guiding voices:   

> “how should I design this, if I was not under time or budget constraint?”    
> “what’s the easiest solution which would get the job done?” 

![Tug-O-War]({{ site.url }}/assets/2009-10-10-TugOWar.jpg)

*From </em><em>[http://www.dartmouthindependent.com/](http://www.dartmouthindependent.com/)*

One of the issue I have with the glorification of the Duct Tape Programmer is that Duct Tape programming is defined as a negative: to be a Duct Tape programmer, you should  

> avoid C++, templates, multiple inheritance, multithreading, COM, CORBA, and a host of other technologies that are all totally reasonable, when you think long and hard about them, but are, honestly, just a little bit too hard for the human brain 

So how do you become a Duct Tape Programmer? Well, you don’t.  

> Duct tape programmers have to have a lot of talent to pull off this shtick. They have to be good enough programmers to ship code, and we’ll forgive them if they never write a unit test

This is where I take issue with Joel’s post. In essence, what he is saying is that some people are just so good at what they are doing that no matter how many rules they break, they will smoke your best effort - and that he likes these guys because they are good. That’s obvious – and it’s also both useless and dangerous. Even if you are a genius, you should start by mastering the classics – and then you can start breaking the rules. If you want to become a better software engineer, go study patterns, unit testing, and learn as much as you can. And then, once you [clocked in your 10,000 hours](http://en.wikipedia.org/wiki/Outliers_(book)), go ahead: pick your tools, and chose what to do and what to ignore.  

I came across Joel a long time ago, through the [Joel Test](http://www.joelonsoftware.com/articles/fog0000000043.html). This post was at the time tremendously useful to me, because it provided simple and actionable guidance on what to aim for to establish good practices for my software team. It was good advice on where to start to get better. This Duct Tape Programmer business is doing exactly the opposite. I wish Joel went back to constructive advice – and in the meanwhile, take that duct tape roll out of the software engineering best practices room, and bring it back where it belongs, the garage. But before that, maybe take a strip to close this discussion?  

![epic fail pictures]({{ site.url }}/assets/2009-10-10-duct-tape.jpg)
