---
layout: post
title: Book review&#58; Working effectively with legacy code
tags:
- Legacy-Code
- Books
- Refactoring
- Testing
---

I finally finished “Working effectively with legacy code”, reading it a few pages at a time every morning on my way to work. Legacy code is one of these topics you know are important, but which you never really want to hear about, so the book has stayed on the backlog for a while. Recently, I helped out someone establish tests on a legacy code base, and began following [Michael Feather’s tweets](https://twitter.com/#!/mfeathers) with great enjoyment, and decided it was time to read it.  

## Who should read it?  

The developer who is already familiar with unit testing, comfortable with his language, object-oriented concepts, and what makes code maintainable - and wants to expand his thoughts and tools on testing and testability.  

## 3 things I liked about it     

* The chapter titles are awesome – just like good naming is a hallmark of Clean Code, the chapter titles convey very clearly what the intent is. “I need to change a Monster method and I can’t write tests for it”, “It takes forever to make a change”, “How do I know that I am not breaking anything”, “I am changing the same code all over the place” – they all evoke situations we have been through one time or another, and the corresponding chapters do address these questions head-on.     

* Clear concepts and vocabulary: if anything, the one sentence that will stay with me is “**legacy code is simply code without tests**”, a wonderfully clear and opinionated definition, which [not everyone may agree with](http://stackoverflow.com/questions/479596/what-makes-code-legacy). Feathers defines a few concepts (like a Seam or a Pinch Point), which provide a helpful language to think and and discuss legacy code.    

* Multiple languages: I write primarily in C# and F#, so in principle, learning about specific issues of testing legacy C code isn’t high on my concerns list. Still, I found that going through examples in languages I am not familiar with was interesting, in that it provided both a broader perspective on testing and on the relative strengths and weaknesses of various languages. It also made me think of techniques I seldom (if ever) use in C#, like pre-processor directives.    

## 3 things I didn’t like that much     

* Multiple languages: covering multiple languages provides a broader perspective, but it also comes at the expense of each individual language. If you are specifically interested in, say, C#-specific techniques, this book may disappoint you - it is fairly general.    

* A bit dated: for a book published in 2004, it aged remarkably well. Still, 8 years is a long time in computer-years. From a C# developer perspective, there have been a few major releases of both the language and the IDE, with implications on testing and refactoring. I would assume (hope) that today, most language/IDEs do support refactorings like Extract Method. On the language side, the book touches on using function pointers to achieve decoupling, but the context is mostly C. With the emergence of functional concepts (Func<T> in modern C# for instance), I think this would warrant a bigger discussion today.     

* A somewhat tedious read: this book is not exactly a page-turner. Reading legacy code examples (a good part of them probably not in a language you are comfortable with, unless you are a polyglot) and figuring out mechanical steps to disentangle it isn’t material that will be turned into a Hollywood movie any time soon.    

## Parting thoughts  

I really enjoyed this book, but I would recommend it with an asterisk. Depending on how you want to look at it, a polyglot book will either lose specificity, or gain generality. Personally, I think in this case, the gain in generality easily compensates for the lack of depth in each individual language. Yes, I would like a C#-specific book which points to useful, up-to-date tools – but that book would be obsolete in 2 years at best. By covering a variety of languages, Feathers illustrates very different solutions or ideas, and because he uses only fairly simple features in each language, the ideas remain easy to understand and convert into other “coding dialects”.  

My personal bent is for concepts and language, because they last longer than recipes and tools, which is why I really enjoyed this book: it helped me create / articulate a mental map. I don’t have many computer books published in 2004 that I read for insight, today – and this one feels like one of these “timeless classics”.  

That being said, I think it takes a certain experience with unit testing and code maintenance to appreciate the book, and I wouldn’t recommend it to someone who is just starting with tests and wants to find quick solutions to their problems. It may work (the book is very clear on steps and methodology), but I suspect it may be potentially frustrating.  

Totally unrelated note: this is the first technical book I read on Kindle, and I have mixed feelings about it. I was hoping that the Kindle could serve as a portable library for all these massive technical bricks. On one hand, it’s nice to have the possibility to carry around searchable books; on the other hand, clearly, it’s not the best way to read through code samples, where good old paper still has an edge.
