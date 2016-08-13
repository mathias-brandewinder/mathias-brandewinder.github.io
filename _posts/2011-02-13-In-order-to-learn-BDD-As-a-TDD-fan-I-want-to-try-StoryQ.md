---
layout: post
title: In order to learn BDD, As a TDD fan, I want to try StoryQ
tags:
- TDD
- BDD
- Storyq
- Tools
- Testing
---

I have been a fan of Test-Driven Development for a long time; it has helped me write better code and keep my sanity more than once. However, until now, I haven’t really looked into Behavior-Driven Development, even though I have often heard it described as a natural next step from TDD. A recent piece in [MSDN Magazine](http://msdn.microsoft.com/en-us/magazine/gg490346.aspx) re-ignited my interest, and helped me figure out one point I had misunderstood, namely how BDD and TDD fit together, so I started looking into existing frameworks.  

Most of them follow a similar approach: write in a plain-text file a description of the feature in Gherkin, a “feature description” language that is human readable, let the framework generate test stubs which map to the story, and progressively fill the stubs as the feature gets implemented.  

I am probably (too) used to writing tests as code, but something about the idea of starting from text files just doesn’t feel right to me. I understand the appeal of Gherkin as a platform-independent specification language, and of letting the product owner write specifications – but the thought of having to maintain two sets of files (the features and the actual tests) worries me. I may warm up to it in due time, but in the meanwhile I came across [**StoryQ**](http://storyq.codeplex.com/), a framework which felt much easier to adopt for me.  

StoryQ is a tiny dll, which permits to write stories as tests in C#, using a fluent interface, with all the comfort and safety of strong typing and intellisense; Gherkin stories can be produced as an output of the tests, and a separate utility allows you to create code templates from Gherkin.  

Rather than talk about it, let’s see a quick code example. I have a regular NUnit TestFixture with one Test, which represents a Story I am interested in: when I pay the check at the restaurant, I need to add a tip to the check. There are 2 scenarios I am interested in: when I am happy, I’ll tip a nice 20%, but when I am not, there will be zero tip. This is how it could look like in StoryQ:  

``` csharp
using NUnit.Framework;
using StoryQ;

[TestFixture]
public class CalculateTip
{
   [Test]
   public void CalculatingTheTip()
   {
      new Story("Calculating the Tip")
      .InOrderTo("Pay the check")
      .AsA("Customer")
      .IWant("Add tip to check")

      .WithScenario("Unhappy with service")
      .Given(CheckTotalIs, 100d)
      .When(IAmHappyWithService, false)
      .Then(TipShouldBe, 0d)

      .WithScenario("Happy with service")
      .Given(CheckTotalIs, 100d)
      .When(IAmHappyWithService, true)
      .Then(TipShouldBe, 20d)

      .Execute();
   }

   public double CheckTotal { get; set; }

   public bool IsHappy { get; set; }

   public void CheckTotalIs(double total)
   {
      this.CheckTotal = total;
   }

   public void IAmHappyWithService(bool isHappy)
   {
      this.IsHappy = isHappy;
   }

   public void TipShouldBe(double expectedTip)
   {
      var tip = TipCalculator.Tip(CheckTotal, IsHappy);
      Assert.AreEqual(expectedTip, tip);
   }
}
``` 

(The `TipCalculator` class is a simple class I implemented on the side).

This test can now be run just like any other NUnit test; when I ran this with ReSharper within Visual Studio, I immediately saw the output below. Pretty nice, I say.

![image]({{ site.url }}/assets/2011-02-13-image_thumb.png)

## What I liked so far


* Painless transition for someone used to TDD. For someone like me, who is used to write unit tests within Visual Studio, this is completely straightforward. No new language to learn, a process pretty similar to what I am used to – a breeze.

* Completely smooth integration with NUnit and ReSharper: no plugin to install, no tweaks, it just worked.

* Fluent interface: the fluent interface provides guidance as you write the story, and hints at what steps are expected next. 

* Passing arguments: I like the API for expressing the Given/When/Then steps. Passing arguments feels very natural.

* xml report: I have not played much with it yet, but there is an option to produce an xml file with the results of the tests, which should work well with a continuous integration server.

## What I didn’t like that much

* Execute: at some point I inadvertently deleted the `.Execute()` call at the end of the Story, and it took me a while to figure out why all my tests were passing, but no output was produced. More generally, I would have preferred something like `Verify()`, which seems clearer, but that’s nitpicking.

* Multiple scenarios in one test: once I figured out that I could chain multiple scenarios in one story, I was a happy camper, but all the examples I saw on the project page have one story / one scenario per test method. It’s only when I used the WPF story converter that I realized I could do this. 

* Crash of the WPF converter: the converter is awesome – but the first time I ran it it crashed.

So where do I go from there? So far, I really enjoyed playing with StoryQ – enough that I want to give it a go on a real project. I expect that the path to getting comfortable with BDD will be similar to TDD: writing lots of tests, some of them fairly bad, until over time a certain feeling for what’s right or very wrong develops… In spite of my reservations, I am skeptical but curious (after all, I have been known to be wrong sometimes…), so I also plan to give SpecFlow a try.
