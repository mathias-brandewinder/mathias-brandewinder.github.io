---
layout: post
title: Data driven tests with NUnit 2.5
tags:
- NUnit
- TDD
- Exceptions
- Data-Driven
---

Another nice improvement coming with NUnit 2.5 is the mechanism for data-driven tests. NUnit 2.4.7 included an extension by [andreas schlapsi](http://www.andreas-schlapsi.com/2008/03/31/nunit-247-includes-rowtest-extension/) which permitted to write [row tests](http://blog.donnfelker.com/post/NUnit-247-and-the-RowTest-Attribute-with-Example.aspx), using the [TestRow] attribute.  

NUnit 2.5 eases the process with the [TestCase] attribute. Unlike [TestRow], the [TestCase] attribute is available within the NUnit.Framework namespace, and doesn’t require including additional references.  Why do Data-driven tests matter? They are not technically necessary: you can write the same tests as easily using the standard [Test] attribute. However, it comes handy when you are testing a feature where you want to verify the behavior for multiple combinations of input values. Using “classic” unit tests, you will end up duplicating test code, and you will have to find different name for tests method which are in essence the same test.  

Using [TestCase] instead, here is how it looks. Suppose your class MyClass has a method “Divide” like this one:  

``` csharp
public class MyClass
{
    public double Divide(double numerator, double denominator)
    {
        if (denominator == 0)
        {
            throw new DivideByZeroException("Cannot divide by zero."); 
        }
        return numerator / denominator;
    }
}
``` 

One way to test that feature would be with a test like that one:

``` csharp
[TestCase(2.5d, 2d, Result=1.25d)]
[TestCase(-2.5d, 1d, Result = -2.5d)]
public double ValidateDivision(double numerator, double denominator)
{
    var myClass = new MyClass();
    return myClass.Divide(numerator,denominator);
}
``` 

<!--more-->

Each TestCase will match the arguments of the test method with the arguments provided in parenthesis (e.g. the first test will pass a numerator of 2.5 and a denominator of 2.0) and verify that the return value matches the value provided as “Result”.

One feature I really like in the new implementation is that it also supports exceptions testing. If a certain combination of input values is expected to throw an exception, it can also be expressed as a test case, without writing a dedicated test method:

``` csharp
[TestCase(2.5d, 2d, Result = 1.25d)]
[TestCase(-2.5d, 1d, Result = -2.5d)]
[TestCase(1d, 0d, ExpectedException = typeof(DivideByZeroException))]
public double ValidateDivision(double numerator, double denominator)
{
    var myClass = new MyClass();
    return myClass.Divide(numerator,denominator);
}
``` 

When you run this in the NUnit GUI, you will see something like this, displaying the “mother” test, and the result of each data set:

![TestCase]({{ site.url }}/assets/2009-05-17-TestCase.jpg)

As an aside, this post made me realize that dividing a double by zero was not throwing a “DivideByZeroException”, as I naively thought it would, but returns a double.PositiveInfinity (or NegativeInfinity, depending on the numerator). Goes to show that nothing beats [writing unit tests when trying to understand a feature](http://blog.goeran.no/PermaLink,guid,fe01bed3-c526-4b76-bb91-f82f4792aece.aspx) of a language!
