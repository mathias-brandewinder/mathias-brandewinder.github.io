---
layout: post
title: Joel doesn't like SOLID
tags:
- Design
- Mocks
- TDD
- Testing
- Solid
- Agile
- OO
---

I came across this dialog between [Joel Spolsky](http://www.joelonsoftware.com/) and [Jeff Atwood](http://www.codinghorror.com/blog/) a few days ago, where Joel rails against the SOLID principles. The origin of his ire is a [Hanselminutes](http://www.hanselminutes.com/default.aspx?showID=163) Podcast with [Uncle Bob](http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod), to which he reacted with this comment: 
	
> People that say things like this have just never written a heck of a lot of code. Because what they're doing is spending an enormous amount of time writing a lot of extra code, a lot of verbiage, a lot of files, and a million little classes that don't do anything and thousands of little interface classes and a lot of robustness to make each of these classes individually armed to go out into the world alone and do things, and you're not going to need it. You're spending a lot of time in advance writing code that is just not going to be relevant, it's not going to be important. It could, theoretically, protect you against things, but, how about waiting until those things happen before you protect yourself against them?
	
<!--more-->

I suspect this is in part simple provocation; Joel seems to have embraced a role as the [anti-agile spokesperson](http://www.reddit.com/r/programming/comments/7uq8o/kent_beck_joel_spolsky_is_wrong_about_my_work/) lately. Whatever his motivation, I had two issues with his reaction. 

Are the SOLID principles symptomatic of [Architecture Astronauts](http://www.joelonsoftware.com/items/2008/05/01.html) in action? Joel seems to think so, but in my opinion, this is a misunderstanding. I tend to revert to "SOLID" principles when abstract architecture is leading me nowhere, and want to actually write code that works. When that happens, I just go and write a feature. I write a class, and implement functionality using TDD, not because I am obsessed by QA, but because each test forces me to elicit my use case, work with that class, and understand better what will work and what the issues are. When the feature interacts with other pieces of the system, I write the collaborators as interfaces. I can then focus on one feature only, and use [Mocks](http://martinfowler.com/articles/mocksArentStubs.html) to get it to work quickly without getting lost in coding the entire system. As a result, I do get lots of small classes, interfaces and unit tests - because it helps me get code written quickly. 

The other issue I have with Joel's rant is that it seems a bit [disingenuous](http://en.wikipedia.org/wiki/Straw_man). Granted, Uncle Bob's exposition of the single-responsibility principle may have sounded somewhat contrived (extremist?) - but I read his point as defining an ideal, guidelines which help spot design flaws, with clear ways to address them. The goal is not to write as many tiny classes as possible, but to have tight classes, which do few things, but do them right. Is Joel really advocating to go for [large classes](http://sis36.berkeley.edu/projects/streek/agile/bad-smells-in-code.html#Large+Class)? Somehow, I doubt it. 

That being said, I might have a bias, because most of the code I write revolves around producing financial calculations and forecasting, and test-driven development has proven  invaluable to me in that area, and helped me produce more robust code, faster. Typically, I don't spend much time unit-testing user interface, because tests tend to be more brittle, and if the domain model is well-designed in the first place, it limits the scope of problems that can arise there. So I can end on a point where Joel and I agree:

> In fact, if you're making any kind of API, a plug in API, it is very important to separate things into interfaces and be very very contractual, and tightly engineered.
