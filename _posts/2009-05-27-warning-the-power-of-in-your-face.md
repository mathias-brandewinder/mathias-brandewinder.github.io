---
layout: post
title: warning, the power of in-your-face
tags:
- C#
- Refactoring
- Tips-And-Tricks
---

The iterative nature of writing code inevitably involves adding code which is good enough for now, but should be refactored later. The problem is that unless you have some system in place, later, you will just forget about it. Personally, I have been trying 3 approaches to address this: bug-tracking systems, the good old-fashion text to-do list, and its variant, the task list built in Visual Studio, and finally, comments embedded in the code.  

Each have their pros and cons. Bug tracking systems are great for systematically managing work items in a team (prioritization, assignment to various members...), but work best for items at the level of a feature: in my experience, smaller code changes don't fit well. I am a big fan of the bare-bones [text file to-do list](http://www.tobinharris.com/past/2008/10/22/how-do-you-manage-your-todos/); I tried, but never took to the Visual Studio to-do list (no clear reason there). I hardly embed comments in code anymore (like 'To-do: change this later'): on the plus side, the comment is literally tacked to the code that needs changing, but the comments cannot be displayed all as one list, which makes them too easy to forget.  

Today I found a cool alternative via Donn Felker’s blog: [#warning](http://blog.donnfelker.com/post/Code-Review-Tip-Using-the-e28098warninge28099-Preprocessor-Directive.aspx). You use it essentially like a comment, but preface it with #warning, like this:  

``` vb
#warning The tag name should not be hardcoded
XmlNodeList atBatNodes = document.GetElementsByTagName("atbat");
``` 

Now, when you build, you will see something like this in Visual Studio:

![warning]({{ site.url }}/assets/2009-05-27-warning.jpg)

It has all the benefits of the embedded comment – it’s close to the code that needs to be changed - but will also show up as a list which will be in-your-face every time you build. I’ll try that out, and see how that goes, and what stays in the todo.txt!
