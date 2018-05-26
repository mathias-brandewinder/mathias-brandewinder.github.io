---
layout: post
title: The 12-pack problem&#58; combination of integers
tags:
- Fun
- Math
- Algorithms
- Optimization
- FizzBuzz
---
A fun problem came my way today. Imagine that you are the owner of a renowned brewery in Bizzarostan, a country where beer is sold only in 7-packs and 13-packs, sometimes described as the ++ packs. Beer is a serious matter in Bizzarostan, and buying single bottles is not tolerated by the law.  

You take great pride in doing what’s best for your customers, so when a customers asks you for, say, 20 beers, you always try your best to find the combination of 7-packs and 13-packs that will meet your customer’s thirst, for the least amount of hard-earned money – in that case, a 7-pack and a 13-pack.  

*To be extra clear, the goal is to find a combination of 7- and 13-packs containing at least as many bottles as requested, with a total number of bottles as close as possible to the amount requested.*  

But the unquenchable thirst of the population of Bizzarostan has been increasing lately, which is making your job harder. How would you know on top of your head what’s the best combination for a hundred bottles of Beer? Having great faith in the wonders of modern technology, you decide it’s time to write an application to find that ideal combination of beer packs.  

I got a rather brute-force working solution already, which I will share in the next few days. This may be massive overkill, but that’s also a problem the Microsoft Solver Foundation can handle fairly easily, so we’ll look into that as well. I have this nagging feeling that there is an elegant recursive solution to the problem, but couldn’t write anything clever so far; if you have thoughts, please share them in the comments!  

PS: no, I haven’t started working for a company that manufacture 7-packs of beers, it’s a transposition of a real-world, analogous problem.  

PPS: I think this is also the closest I ever got to seeing a real application of the [FizzBuzz](http://www.codinghorror.com/blog/2007/02/why-cant-programmers-program.html) problem in the real world.
