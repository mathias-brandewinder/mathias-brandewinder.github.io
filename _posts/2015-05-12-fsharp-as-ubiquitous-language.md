---
layout: post
title: F# as a Ubiquitous Language
tags:
- F#
- Ubiquitous-Language
- DDD
- Domain-Modeling
---

As much as we people who write code like to talk about code, the biggest challenge in a software project is not code. A project rarely fails because of technology – it usually fails because of miscommunications: the code that is delivered solves a problem (sometimes), but not the right one. One of the reasons we often deliver the wrong solution is that coding involves translating the world of the original problem into a different language. Translating one way is hard enough as it is, but then, rarely are users comfortable with reading and interpreting code – and as a result, confirming whether the code “does the right thing” is hard, and errors go un-noticed.

This is why the idea of [Ubiquitous Language][1], coined by Eric Evans in his [Domain Driven Design book][2], always appealed to me. The further apart the languages of the domain expert and the code are, the more likely it is that something will be lost in translation.

However, achieving this perfect situation, with “a language structured around the domain model and used by all team members to connect all the activities of the team with the software” [source][3], is hard. I have tried this in the past, mainly through tests. My idea at the time was that tests, especially BDD style, could perhaps provide domain experts with scenarios similar enough to their worldview that they could serve as a basis for an active dialogue. The experience wasn’t particularly successful: it helped some, but in the end, I never got to the point where tests would become a shared, common ground (which doesn’t mean it’s not possible – I just didn’t manage to do it).

Fast forward a bit to today – I just completed a project, and it’s the closest I have ever been to seeing Ubiquitous Language in action. It was one of the most satisfying experiences I had, and F# had a lot to do with why it worked.

The project involved some pretty complex modeling, and only two people – me and the client. The client is definitely a domain expert, and on the very high end of the “computer power user” spectrum: he is very comfortable with SQL, doesn’t write software applications, but has a license to Visual Studio and is not afraid of code.

The fact that F# worked well for me isn’t a surprise – I am the developer in that equation, and I love it, for all the usual technical reasons. It just makes my life writing code easier. The part that was interesting here is that F# worked well for the client, too, and became our basis for communication.

What ended up happening was the following: I created a GitHub private repository, and started coding in a script file, fleshing out a domain model with small, runnable pieces of code illustrating what it was doing. We would have regular Skype meetings, with a screen share so that I could walk him through the code in Visual Studio, and explain the changes I made - and we would discuss. Soon after, he started to run the code himself, and even making small changes here and there, not necessarily the most complicated bits, but more domain-specific parts, such as adjusting parameters and seeing how the results would differ. And soon, I began receiving emails containing specific scenarios he had experimented with, using actual production data, and pointing at possible flaws in my approach, or questions that required clarifications.

So how did F# make a difference? I think it’s a combination of at least 2 things: succinctness, and static typing + scripts. Succinctness, because you can define a domain with very little code, without loosing expressiveness. As a result, the core entities of the domain end up taking a couple of lines at the top of a single file, and it’s easy to get a full picture, without having to navigate around between files and folders, and keep information in your head. As an illustration, here is a snippet of code from the project:

``` fsharp
type Window = { Early:DateTime; Target:DateTime; Late:DateTime }

type Trip = {
  ID:TripID
  Origin:Location
  Destination:Location
  Pickup:Window
  Dropoff:Window
  Dwell:TimeSpan }

type Action =
  | Pickup of Trip
  | Dropoff of Trip
  | CompleteRoute of Location
```

This is concise, and pretty straightforward – no functional programming guru credentials needed. This is readable code, which we can talk about without getting bogged down in extraneous details.

The second ingredient is static typing + scripts. What this creates is a safe environment for experimentation.  You can just change a couple of lines here and there, run the code, and see what happens. And when you break something, the compiler immediately barks at you – just undo or fix it. Give someone a running script, and they can start playing with it, and exploring ideas.

In over 10 years writing code professionally, I never had such a collaborative, fruitful, and productive interaction cycle with a client. Never. This was the best of both worlds – I could focus on the code and the algorithms, and he could immediately use it, try it out, and send me invaluable feedback, based on his domain knowledge. No noise, no UML diagrams, no slides, no ceremony – just write code, and directly communicate around it, making sure nothing was amiss. Which triggered this happy tweet a few weeks back:

<blockquote class="twitter-tweet" lang="en"><p lang="en" dir="ltr">Being able to just show the code to a client and have him immediately catch domain modelling errors: priceless. F# is awesome. <a href="https://twitter.com/hashtag/fsharp?src=hash">#fsharp</a></p>&mdash; Mathias Brandewinder (@brandewinder) <a href="https://twitter.com/brandewinder/status/570437796113985536">February 25, 2015</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

We were looking at the code together, and my client spotted a domain modeling mistake, right there. This is priceless.

>As a side-note, another thing that is priceless is [“F# for Fun and Profit”][4]. [Scott Wlaschin](https://twitter.com/scottwlaschin) has been doing an incredible work with this website. It’s literally a gold mine, and I picked up a lot of ideas there. If you haven’t visited it yet, you probably should.

[1]: http://martinfowler.com/bliki/UbiquitousLanguage.html
[2]: http://www.amazon.com/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215
[3]: http://en.wikipedia.org/wiki/Domain-driven_design#Core_definitions
[4]: http://fsharpforfunandprofit.com/
