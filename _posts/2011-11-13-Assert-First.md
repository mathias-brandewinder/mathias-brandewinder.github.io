---
layout: post
title: Assert First
tags:
- TDD
- Unit-Tests
- Patterns-And-Practices
---

We were doing some pair-programming with [Petar](http://petarvucetin.me/blog/) recently, Test-Driven Development style, and started talking about how figuring out where to begin with the tests is often the hardest part. Petar noticed that when writing a test, I was typically starting at the end, first writing an Assert, and then coding my way backwards in the test – and that it helped getting things started.  

I hadn’t realized I was doing it, and suspected it was coming from Kent Beck’s “[Test-Driven Development, by Example](http://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)”. Sure enough, the Patterns section of the book lists the following:  

> **Assert First**. When should you write the asserts? Try writing them first.

So why would this be a good idea?  

I think the reason it works well, is that it helps focus the effort on one single goal at a time, and requires clarifying what that goal is. Starting with the Assert forces you to imagine one single fact that should be true once you have implemented the feature, and to think about how you are going to verify that the feature is indeed working.  

Once the Assert is in place, you can now write the story backwards: what is the method that was called to get the result being checked, and&#160; where does it belong? What classes and setup is required to make that method call? And, now that the story is written, what is it really saying, and what should the test method name be?  

In other words, begin with the Assert, figure out the Act part, Arrange the actors, and (re)name the test method.  

I think what trips some people is that while a good test will look like a little story, progressing from a beginning to a logical end, the process leading to it follows a completely opposite direction. Kent Beck points the [Self-Similarity](http://en.wikipedia.org/wiki/Self-similarity) in the entire process: write stories which describe what the application will do once done, write tests which describe what the feature does once the code is implemented, and write asserts which will pass once the test is complete. Always start with the end in mind, and do exactly what it takes to achieve your goal.  

![Self Similarity]({{ site.url }}/assets/2011-11-13-souriez.jpg)
