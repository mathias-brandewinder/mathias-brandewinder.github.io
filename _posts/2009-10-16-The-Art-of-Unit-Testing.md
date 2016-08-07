---
layout: post
title: The Art of Unit Testing
tags:
- TDD
- Testing
- Mocks
- Books
---

![TheArtOfUnitTesting]({{ site.url }}/assets/2009-10-16-TheArtOfUnitTesting.jpg)   

I recently finished reading [the Art of Unit Testing](http://www.manning.com/osherove/), by [Roy Osherove](http://weblogs.asp.net/rosherove/default.aspx) (Manning); here are a few thoughts on the book.  

## Who to give it too  

This is an **excellent** book for the C# developer with solid foundations in object-oriented design, who has already some exposure to writing unit tests. If you have worked on a decent-scale project, and found yourself thinking “hmmm, I am sure there is a smarter way to write these tests”, you should definitely get that book. Note that while it will be extremely useful to the test-driven development practitioner, this is NOT a book on TDD.

<!--more-->

## 3 things I liked about it  

**Writing maintainable tests**: this topic has its own chapter, but you could argue that it is the underlying theme of the book, and Osherove does a great job covering what to look for in a test, and why. I really loved this part.   

**Design for testability**: Osherove presents various refactoring approaches to make code more testable, and goes into it some more in an appendix. Besides the fact that this is a very important topic, I found this part of the book very stimulating, because, as is usually the case for design questions, the answers are not clear cut, and Osherove discusses the pros and cons very honestly.  

**Mocks and Stubs**: not surprisingly, Osherove gives a very good exposition to isolation. I really liked that before going into specific frameworks, he takes the time to show how one would roll stubs and mocks manually. This is very helpful: it focuses the attention on why a mock is needed, and avoids the distraction that the framework syntax can be – and only then introduces the frameworks, showing how they simply reduce the amount of repetitive work needed, and how to use them. This is one of the clearest explanations on stubs and mocks I have seen so far (thank you!).  

## 3 ways to make me happier  

**Keep the example straight**: the LogAnalyzer class is used throughout chapter 2 and 3 as an example. In chapter 2, it is used how to unit test a feature which validates whether a file name is valid, based on the file extension. In chapter 3, however, the same feature is still there, but somehow another rule has mysteriously been added – in addition to the extension, the file name is also supposed to be longer than 5 characters. The code isn’t very complex, but I think the chapter would have gained clarity by either keeping the same example throughout, or by clearly exposing in the beginning of chapter 3 what the feature was, and which class was responsible for it.  
**Code layout**: two small layout gripes. First , the indentation of the code is odd. The curly braces which open and close the class definition are indented with a tab space, the attribute are not aligned with the name of the class… Minor things, but displeasing to the eye. Then, it would be nice if the code examples were entirely on the same page. They are short enough that it seems it should be possible, and having the code visible in its entirety without needing to turn pages back and forth would be nice. On the plus side, I like the annotations/comment of the code.  

**Arrange, Act, Assert**: I wish the section on AAA was a bit more developed. This is of course a matter of opinion, but I find this approach much clearer than record/replay – and it also seems that’s where most isolation frameworks are headed. I would have liked more guidance on this pattern / style - maybe using this as the default would be beneficial.  

## Final thoughts  

As should be clear from the previous paragraphs, I really liked this book, and wish it had been available to me earlier. My experience with unit testing has gone through phases. When I came across Test-Driven Development, I began writing unit tests – lots and lots of them. This worked very well for the type of code I was writing, and I embraced unit testing with enthusiasm. But over time, I came to realize that, just like for “regular” code, it took work and experience to write maintainable tests, and learnt the hard way that some things worked well and some, not so well.  

This is where the book shines. Every problem I encountered is listed in here, and some more, of course; the book provides a solid frame to write better, more maintainable tests, as well as guidance on how to better integrate them in the process and the organization.  

That being said, I think that maintenance is a bit of an abstract concept. Until you had to maintain a real-size project, it is hard to fully grasp what maintainable code is, and why it is so important – and the same goes for tests. While I am sure this book would have helped me avoid pitfalls in my early attempts at writing good unit tests, I would probably have missed some of the points the book is making, not because there are complex, but because I would not have understood how they applied.  

For that reason, I really recommend “the Art of Unit Testing” to the more seasoned developer. It will be an excellent companion, and will help bring your unit-testing game to the next level. If you are just getting started with unit testing, I would recommend starting with something else, like Kent Beck’s “Test Driven Development, by Example”, because it might give you a better sense of how to “do” things, and what it feels like to develop code and unit tests together.
