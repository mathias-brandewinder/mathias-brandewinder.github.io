---
layout: post
title: Testing for exceptions with NUnit 2.5
tags:
- TDD
- Testing
- NUnit
- Exceptions
---

Compared to the recent releases, NUnit 2.5 contains quite a few significant changes. One notable change is in the area of exception testing – and it is for the better.   

Until NUnit 2.4.8, testing for exceptions was done by decorating tests with the [ExpectedException] attribute. NUnit 2.5 introduces a new assertion instead, Assert.Throws.  

Why is this better?  

I see at least 2 reasons: it makes it much easier to catch the exception precisely where it is expected to happen, and working with the exception itself is now a breeze.  

While the ExpectedException attribute is typically sufficient, it is a bit of a blunt tool. What it does verify is that the code under test throws the expected type of exception; what it&#160; doesn’t tell you is where. The tests are not fully explicit, and sometimes, they can result in unexpected “false positives”.  

Consider the following situation: a class MyClass exposes a method that takes a positive int as argument, and throws an ArgumentException if a negative is passed. A test for this behavior would look something like this:  

``` csharp
[Test]
[ExpectedException(typeof(ArgumentException))]
public void FalsePositive()
{
    MyClass myClass = new MyClass();
    // This call is test setup, but will
    // throw an unwanted ArgumentException.
    myClass.SomeMethodThatThrows();
    // We want to check that this call throws.
    myClass.SomeMethodThatRequiresAPositiveArgument(-5);
}
``` 

<!--more-->

Unfortunately, our setup contains a call to another method, which due to an error in our code, will throw an ArgumentException, too. The right type of exception is thrown, but absolutely not where we intend it – and the test will pass. Not good.

Granted, the example is pretty contrived, but situations like these do happen. To avoid this, you need to catch the exception “red handed”, exactly where it is supposed to take place – which requires cumbersome code code like this:

``` csharp
[Test]
[ExpectedException(typeof(ArgumentException))]
public void PainfulCorrectTest()
{
    MyClass myClass = new MyClass();
    try
    {
        // if the setup throws the test fails.
        myClass.SomeMethodThatThrows();
    }
    catch
    {
        Assert.Fail();
    }
    // We expect an exception in that portion of the code.
    myClass.SomeMethodThatRequiresAPositiveArgument(-5);
}
``` 

By wrapping the setup in a try/catch block, you can ensure that any exception that happens there will result in a failure of the test; the only “tolerated” exception has to occur after that block.

With NUnit 2.5, this problem disappears. The [ExpectedException] attribute is gone, and replaced by an assertion that verifies if a specific method call throws an exception:

``` csharp
[Test]
public void DelegateBasedTest()
{
    MyClass myClass = new MyClass();
    // We don't need to do anything about the setup.
    myClass.SomeMethodThatThrows();
    // The exception is expected here.
    Assert.Throws<ArgumentException>(
        delegate { myClass.SomeMethodThatRequiresAPositiveArgument(-5); });
}
``` 

This is really nice: the test pinpoints what exception is expected, AND exactly where it is supposed to happen. And with the “special” [ExpectedException] attribute gone, the syntax is more consistent.

The cherry on the cake is that Assert.Throws returns the actual exception that is thrown; it is totally straightforward to validate the state of the exception itself:

``` csharp
[Test]
public void RetrieveException()
{
    MyClass myClass = new MyClass();
    ArgumentException exception = Assert.Throws<ArgumentException>(delegate { myClass.SomeMethodThatRequiresAPositiveArgument(-5); });
    Assert.AreEqual("The Message.", exception.Message);
}
``` 

I really like this change in NUnit 2.5. The syntax does look a bit more intimidating, but the tests gain in clarity – which is crucial in a test suite. Tests are your best specification, and anything which reduces ambiguity there is a good thing!
