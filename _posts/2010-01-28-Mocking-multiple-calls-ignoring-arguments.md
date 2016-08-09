---
layout: post
title: Mocking multiple calls, ignoring arguments
tags:
- Mocks
- Rhino.Mocks
- TDD
- Testing
---

Mark Needham recently published a series of posts around TDD, and one caught my attention. He is [mocking a series of calls to a method](http://www.markhneedham.com/blog/2010/01/25/tdd-simplifying-a-test-with-a-hand-rolled-stub/) `SomeMethod()` of a service `IService`, and doesn’t really care about the arguments, but:  

> For the sake of the test I only wanted 'service' to return a value of 'aValue' the first time it was called and then 'anotherValue' for any other calls after that. 

His solution is to ditch his mocking framework (Rhino.Mocks, as far as I can tell) for that one test, and hand-roll his stub – and his example is a good case for why you might want to do that, sometimes.  

However, this got me curious, and I wondered if this was indeed possible using Rhino. As recently as last week, I struggled with mocking repeat calls; but I had never actually considered a situation where one might want to mock a method, focusing only on the fact that the method is called, without paying attention to the specific arguments passed. Fun stuff.  

After some digging into the documentation, I came across `IgnoreArguments()`, which seems to do the job:  

``` csharp
public void SpecifyFirstReturnThenReturnSameThingForeverAfter()
{
    var fakeService = MockRepository.GenerateStub<IService>();
    fakeService.Expect(f => f.SomeMethod(null)).IgnoreArguments().Return("First").Repeat.Once();
    fakeService.Expect(f => f.SomeMethod(null)).IgnoreArguments().Return("SecondAndAfter");
    
    var first = fakeService.SomeMethod("ABC");
    var second = fakeService.SomeMethod("DEF");
    var third = fakeService.SomeMethod( "GHI" );

    Assert.AreEqual("First", first);
    Assert.AreEqual("SecondAndAfter", second);
    Assert.AreEqual("SecondAndAfter", third);
}
``` 

`IgnoreArguments()` seems to be a potentially convenient way to make some tests lighter. That being said, arguably, the setup here is cumbersome, and the hand-rolled version is clearer: when you reach the point where you wonder if your mock is doing what you think it should, you enter perilous territory…
