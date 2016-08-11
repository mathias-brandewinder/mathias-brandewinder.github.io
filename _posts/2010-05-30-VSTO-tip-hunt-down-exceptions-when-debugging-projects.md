---
layout: post
title: VSTO tip&#58; hunt down exceptions when debugging projects
tags:
- Exceptions
- Debugging
- VSTO
- Tips-And-Tricks
- Visual-Studio
---

Silence is gold. Or... is it? You may have noticed that VSTO swallows exceptions; that is, if something goes wrong in your add-in code, Office will discreetly carry on as if nothing had happened. Consider the following code:

``` csharp
public partial class ThisAddIn
{
    private int counter;

    private void ThisAddIn_Startup(object sender, System.EventArgs e)
    {
        this.Application.SheetActivate += SheetActivated;
    }

    private void SheetActivated(object sheet)
    {
        MessageBox.Show("Counter = " + this.counter.ToString());
        throw new ArgumentException("Something went south here.");
        counter++;
    }
``` 

The add-in is supposed to maintain a counter of how many times the user has changed the activate sheet. However, a bug throws an exception right before the counter is updated. If you run this code, you&rsquo;ll see that the MessageBox keeps being displayed every time you change the selected worksheet, but the counter stays firmly at zero, and never gets updated.

<!--more-->

On the plus side (?), this spares your user the scary-looking notification a traditional Winforms application puts in your face when an unhandled exception is thrown:

![WinformsException]({{ site.url }}/assets/2010-05-30-WinformsException_thumb.png)

On the down side, it means that you'd better think about a strategy to diagnose your add-in if something goes wrong: if you don't put in place some exception logging or feedback mechanism, you won't have a clue what is going wrong, or even that something is going wrong.

Now if you are using Visual Studio 2008 (and not the non-existent 2007 as I initially wrote), you want to be extra-careful: in debug mode, by default your VSTO project will behave the same way, and happily go on without notifying you of unhandled exceptions. If you want to go on a serious bug hunt, one thing you can do is turn on the [Ripley](http://en.wikipedia.org/wiki/Ellen_Ripley) mode: go to Debug > Exceptions (or Ctrl + Alt + E), and select Common Language Runtime Exceptions / Thrown.

![CatchExceptions]({{ site.url }}/assets/2010-05-30-CatchExceptions_thumb.png)

Visual Studio will now immediately highlight the guilty code whenever a .NET exception is thrown.

![RipleyMode]({{ site.url }}/assets/2010-05-30-RipleyMode_thumb.png)

Note that I said Visual Studio 2008, and not simply Visual Studio. When I tried the same in Visual Studio 2010, I was very pleasantly surprised: the exception was immediately highlighted, without having to do anything. Bugs, beware: Ripley mode is on out-of-the box in Visual Studio 2010!
