---
layout: post
title: Bugs hiding in plain sight
tags:
- .Net
- Math
- Nunit
- Testing
- Precision
- Accuracy
- Floating-Point
---

![ghostmantis]({{ site.url }}/assets/2009-09-18-ghostmantis.jpg)

I found a bug in my code the other day. It happens to everybody - apparently I am not the only one to [write bugs](http://www.codinghorror.com/blog/archives/000099.html) – but the bug itself surprised me. In my experience, once you know a piece of code is buggy, it’s usually not too difficult to figure out what the origin of the problem might be (fixing it might). This bug surprised me, because I knew exactly the 10 lines of code where it was taking place, and yet I had no idea what was going on – I just couldn’t see the bug, even though it was floating in plain sight (hint: the pun is intended).  Here is the context. The code reads a double and converts it into a year and a quarter, based on the following convention: the input is of the form yyyy.q, for instance, 2010.2 represents the second quarter of 2010. Anything after the 2nd decimal is ignored, 2010.0 is “rounded up” to 1st quarter, and 2010.5 and above rounded down to 4th quarter.  Here is my original code:

``` csharp 
public class DateConverter
{
    public static int ExtractYear(double dateAsDouble)
    {
        int year = (int)dateAsDouble;
        return year;
    }

    public static int ExtractQuarter(double dateAsDouble)
    {
        int year = ExtractYear(dateAsDouble);
        int quarter = (int)(10 * (Math.Round(dateAsDouble, 1) - (double)year));
        if (quarter < 1)
        {
            quarter = 1;
        }
        if (quarter > 4)
        {
            quarter = 4;
        }
        return quarter;
    }
}
``` 

Can you spot the bug?

<!--more-->

Here is another hint – only one of these tests fails:

``` csharp 
[TestCase(2010.1, Result = 1)]
[TestCase(2010.2, Result = 2)]
[TestCase(2010.3, Result = 3)]
[TestCase(2010.4, Result = 4)]
[TestCase(2010.0, Result = 1)]
[TestCase(2010.5, Result = 4)]
public int ValidateQuarter(double dateAsDouble)
{
    return DateConverter.ExtractQuarter(dateAsDouble);
}
``` 

My first thought was, “Oops I did it again, must have made a silly mistake with either rounding or casting somewhere”. But when I saw that the only failing test case was for 2010.3, I knew the logic of the calculation wasn’t the problem.

After some head-scratching, I realized what it was – **my** math is perfectly OK, thank you, but in the [floating point](http://www.extremeoptimization.com/resources/Articles/FPDotNetConceptsAndFormats.aspx) world of the computer, things happen [a bit differently](http://www.codinghorror.com/blog/archives/001266.html). Like,

``` csharp 
[Test]
public void HmmmRight()
{
    Assert.AreEqual(0.3, 0.3 - 0.0);
    // all the following fail miserably
    Assert.AreEqual(0.3, 0.4 - 0.1);
    Assert.AreEqual(0.3, 1.3 - 1.0);
    Assert.AreEqual(0.3, 2010.3 - 2010.0);
}
``` 

It is such simple math, and it is so obvious to me that 2010.3 – 2010.0 equals 0.3, that I didn’t even consider this was a source of potential errors.

I have changed my code to the following version, which uses doubles as little as possible, and seems to work just fine:

``` csharp 
public static int ExtractQuarter(double dateAsDouble)
{
    int year = ExtractYear(dateAsDouble);
    int quarter = (int)(10 * dateAsDouble) - 10 * year;
    if (quarter < 1)
    {
        quarter = 1;
    }
    if (quarter > 4)
    {
        quarter = 4;
    }
    return quarter;
}
``` 

I am not sure this is the smartest way to deal with the issue - any suggestions are greatly appreciated! In the meanwhile, for me, the moral of story is that:

1) Write unit tests. For “any piece of code that has some form of logic in it, small as it may be” ([The Art of Unit Testing](http://www.artofunittesting.com/).

2) Beware of floating point arithmetic!
