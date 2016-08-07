---
layout: post
title: No Tolerance for NUnit Data-Driven tests?
tags:
- NUnit
- TDD
- Testing
- Tolerance
---

I really like the addition of [[TestCase]](http://www.nunit.org/index.php?p=testCase&r=2.5) in NUnit 2.5. A significant part of the code I write is math or finance oriented, and I find [Data-Driven tests]({{ site.url }} /2009/05/17/Data-driven-tests-with-NUnit-25/) more convenient that “classic” unit tests to validate numeric procedures.  

However, I got a bit frustrated today, because of the lack of tolerance mechanism in data-driven tests. [Tolerance](http://www.nunit.org/index.php?p=equalConstraint&r=2.5) allows you to specify a margin of error (delta) on your test, and is supported in classic asserts:  

``` csharp
[Test]
public void ClassicToleranceAssert()
{
    double numerator = 10d;
    double denominator = 3d;
    Assert.AreEqual(3.33d, numerator / denominator, 0.01);
    Assert.That(3.33d, Is.EqualTo(numerator / denominator).Within(0.01));
}
``` 

You can specify how close the result should be from the expected test result, here +/- 0.01.

I came into some rounding problems with data driven tests today, and hoped I would be able to resolve them with the same mechanism. Here is roughly the situation:

``` csharp
[TestCase(10d, 2d, Result = 5d)]
[TestCase(10d, 3d, Result = 3.33d)]
public double Divide(double numerator, double denominator)
{
    return numerator / denominator;
}
``` 

Not surprisingly, the second test case fails – and when I looked for a similar tolerance mechanism, I found zilch.

The best solution I got was to do something like this:

``` csharp
[TestCase(10d, 2d, Result = 5d)]
[TestCase(10d, 3d, Result = 3.33d)]
public double Divide(double numerator, double denominator)
{
    return Math.Round(numerator / denominator, 2);
}
``` 

Of course, this works – but this is clumsy. I was really hoping that TestCase would support the same functionality as Assert, with a built-in delta tolerance. It seems particularly relevant: rounding error issues are typical in numerical procedures, a field where data-driven tests are especially adapted.

Maybe the feature exists, but is undocumented. If you know how to do this, sharing your wisdom will earn you a large serving of gratitude, and if it the feature doesn’t exist yet… maybe in NUnit 2.5.1?
