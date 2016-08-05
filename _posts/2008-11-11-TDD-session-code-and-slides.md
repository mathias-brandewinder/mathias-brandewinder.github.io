---
layout: post
title: TDD session code and slides
tags:
- TDD
- Svcc
- C#
- NUnit
- Mocks
- Testing
---

Thank you to all of you who attended my session on test-driven development for C# developers at Silicon Valley Code Camp 2008!

Here are my [slides]({{ site.url }}/files/Intro%20to%20TDD.pptx) and, more importantly, the [code]({{ site.url }}/files/tdd.zip) I presented during the session. In order to get it to work, you will need to install [NUnit](http://www.nunit.org) on your machine first. Besides the unit tests for City, there are 3 files in the folder "Tests". RowTestIllustration is an example of how to use RowTest to pass different set of values to the same test; note the using statement "using NUnit.Framework.Extensions". SetupIllustration shows how the method marked "SetUp" runs before each test method is executed. Finally, "MockIllustration" shows how you can use mocks to easily create instances that satisfy an interface, and verify that the class you are testing conforms to a specified behavior when interacting with that interface.

That's it! Let me know if you have questions or feedback. 
