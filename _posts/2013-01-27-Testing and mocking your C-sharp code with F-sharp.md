---
layout: post
title: Testing and mocking your C# code with F#
tags:
- C#
- F#
- Testing
- Mocks
- Moq
- Foq
- NUnit
- Unit-Tests
---

[Phil Trelford](http://trelford.com/blog/post/fstestlang.aspx) recently released [Foq](https://foq.codeplex.com/), a small F# mocking library (with a very daring name). If most of your code is in F#, this is probably not a big deal for you, because the technique of mocking isn’t very useful in F# (at least in my experience). On the other hand, if your goal is to unit test some C# code in F#, then Foq comes in very handy. So why would you want to write your unit tests in F# in the first place? Let’s start with some plain old C# code, like this:

``` csharp
namespace CodeBase
{
    using System;

    public class Translator
    {
        public const string ErrorMessage = "Translation failure";

        private readonly ILogger logger;
        private readonly IService service;

        public Translator(ILogger logger, IService service)
        {
            this.logger = logger;
            this.service = service;
        }

        public string Translate(string input)
        {
            try
            {
                return this.service.Translate(input);
            }
            catch (Exception exception)
            {
                this.logger.Log(exception);
                return ErrorMessage;
            }
        }
    }

    public interface ILogger
    {
        void Log(Exception exception);
    }

    public interface IService
    {
        string Translate(string input);
    }
}
``` 

We have a class, **`Translator`**, which takes 2 dependencies, a logger and a service. The main purpose of the class is to Translate a string, by calling the service. If the call succeeds, we return the translation, otherwise we log the exception and return an arbitrary error message. 

<!--more-->

This piece of code is very simplistic, but illustrates well the need for Mocking. If I want to unit test that class, there are 3 things I need to verify:

* when the translation service succeeds, I should receive whatever the service says is right, 
* when the translation service fails, I should receive the error message, 
* when the translation service fails, the exception should be logged.

In standard C#, I would typically resort to a Mocking framework like Moq or NSubstitute to test this. What the framework buys me is the ability to create cheaply a fake implementation for the interfaces, setup their behavior to whatever my scenario is (“stubbing”), and in the case of the logger, where I can’t observe through state whether the exception has been logged, verify that the proper call has been made (“mocking”).

This is how my test suite would look:

``` csharp
namespace MoqTests
{
    using System;
    using CodeBase;
    using Moq;
    using NUnit.Framework;

    [TestFixture]
    public class TestsTranslator
    {
        [Test]
        public void Translate_Should_Return_Successful_Service_Response()
        {
            var input = "Hello";
            var output = "Kitty";

            var service = new Mock<IService>();
            service.Setup(s => s.Translate(input)).Returns(output);

            var logger = new Mock<ILogger>();

            var translator = new Translator(logger.Object, service.Object);

            var result = translator.Translate(input);

            Assert.That(result, Is.EqualTo(output));
        }

        [Test]
        public void When_Service_Fails_Translate_Should_Return_ErrorMessage()
        {
            var service = new Mock<IService>();
            service.Setup(s => s.Translate(It.IsAny<string>())).Throws<Exception>();

            var logger = new Mock<ILogger>();

            var translator = new Translator(logger.Object, service.Object);

            var result = translator.Translate("Hello");

            Assert.That(result, Is.EqualTo(Translator.ErrorMessage));
        }

        [Test]
        public void When_Service_Fails_Exception_Should_Be_Logged()
        {
            var error = new Exception();
            var service = new Mock<IService>();
            service.Setup(s => s.Translate(It.IsAny<string>())).Throws(error);

            var logger = new Mock<ILogger>();

            var translator = new Translator(logger.Object, service.Object);

            translator.Translate("Hello");

            logger.Verify(l => l.Log(error));
        }
    }
}

``` 

The first test is pretty self-explanatory, and validates the “happy path”. The second test is a bit more interesting and illustrates the benefit of working against an interface: if we were testing against a real service, it would pretty difficult to simulate a faulty state. Using a Mock allows us to set up the behavior any which way we want, in this case, a service that throws an exception. The third case is where Mocking becomes really useful. `Logger.Log(…)` is a void method, and the `Logger` has no publicly visible state that allows us to verify whether “something happened” – Moq allows us to Verify that a certain call did take place, and if it doesn’t, the test will fail.

Enough C# – what would we gain by rewriting these tests in F#?

First off, we could do that without any Mocking framework, thanks to [Object Expressions](http://msdn.microsoft.com/en-us/library/dd233237.aspx). Then, the tests themselves could, depending on your tastes, look much nicer. Here is what I came up with, using FsUnit, a lovely F# unit testing DSL which prettifies things a bit:

``` fsharp
namespace FSharpTests

open CodeBase
open NUnit.Framework
open FsUnit

[<TestFixture>]
type ``Translator tests``() = 

    [<Test>]
    member test.``Translate should return successful service response`` () =
        let service = {
            new IService with
                member this.Translate(input) =
                    match input with
                    | "Hello" -> "Kitty"
                    | _       -> failwith "ooops" }

        let logger = {
            new ILogger with
                member this.Log(_) = ignore () }

        let translator = Translator(logger, service)
        let input, output = "Hello", "Kitty"
        translator.Translate(input) |> should equal output

    [<Test>]
    member test.``When service fails Translate should return error message`` () =
        
        let service = {
            new IService with
                member this.Translate(_) = failwith "ooops" }

        let logger = {
            new ILogger with
                member this.Log(_) = ignore () }

        let translator = Translator(logger, service)
        
        translator.Translate("Hello") |> should equal Translator.ErrorMessage

    [<Test>]
    member test.``When service fails exception should be logged`` () =
        
        let error = System.Exception()
        let service = {
            new IService with
                member this.Translate(_) = raise error }
        
        let logged = ref false
        let logger = {
            new ILogger with
                member this.Log(e) = 
                    match e with
                    | error -> 
                        logged := true 
                        ignore ()
                    | _ -> ignore () }

        let translator = Translator(logger, service)
        translator.Translate("Hello") |> ignore

        logged.Value |> should equal true

``` 

F#, being a full-fledged member of the .NET family, has no problem dealing with our C# code. Instead of relying on a Mocking framework to provide fake implementations of our interfaces, we use object expressions to generate on-the-fly anonymous types, implementing the methods as we see fit for each test case. Note also the test method names: instead of the arguably ugly-looking `Translate_Should_Return_Successful_Service_Response`, we can use plain English, and simply state “Translate should return successful service response” – and the test runner will show exactly that. It’s not a huge deal, but it does improve readability quite a bit. Finally, the assertion syntax went from `Assert.That(result, Is.EqualTo(Translator.ErrorMessage));` to `translator.Translate("Hello") |> should equal Translator.ErrorMessage`.

There is nothing wrong with the raw NUnit assertion syntax, but I personally find the second version much more palatable and pleasing to the eye. That's what [FsUnit](https://github.com/dmohl/FsUnit) buys you.

*As an aside, I am still in awe at the fact that the core code of FsUnit is under 70 lines of code, a testament to how much can be done with just a tiny amount of smart F# code.*

Object expressions by themselves will cover 99% of your mocking needs. However, there are some situations where they come as a cost. When the interface you are trying to Mock has a lot of methods, having to provide a fake implementation for each of them becomes rather unpleasant. For instance, if you were to use a “real” Log, say, NLog, instead of our simplistic Logger, you’d have to supply implementation for [twenty plus methods](http://nlog-project.org/help/NLog.LoggerMembers.html), not counting overloads, when all you need is one or two. Painful.

Enter [Foq](https://foq.codeplex.com/), a F# mocking library that mimics Moq, written by [Phil Trelford](https://twitter.com/ptrelford). You might ask, “why not use Moq in F#”? The short answer is, C# and F# expressions don’t play too well together, which ends up making that option an unpleasant one. Foq fills that gap, allowing you to create mocks where you need to supply only what’s needed for your test. Here is how the test suite would look like, rewritten with Foq:

``` fsharp
namespace FoqTests

open System
open CodeBase
open NUnit.Framework
open FsUnit
open Foq

[<TestFixture>]
type ``Translator tests``() = 

    [<Test>]
    member test.``Translate should return successful service response`` () = 

        let logger = Mock<ILogger>().Create()

        let input, output = "Hello", "Kitty"
        let service = Mock<IService>()
                         .Setup(fun me -> <@ me.Translate(input) @>).Returns(output)
                         .Create()

        let translator = Translator(logger, service)

        translator.Translate(input) |> should equal output

    [<Test>]
    member test.``When service fails Translate should return error message`` () =
        
        let logger = Mock<ILogger>().Create()

        let error = Exception()
        let service = Mock<IService>()
                         .Setup(fun me -> <@ me.Translate(any()) @> ).Raises(error)
                         .Create()

        let translator = Translator(logger, service)
        
        translator.Translate("Hello") |> should equal Translator.ErrorMessage

    [<Test>]
    member test.``When service fails exception should be logged`` () = 

        let error = Exception()
        let logged = ref false
        let logger = Mock<ILogger>()
                        .Setup(fun log -> <@ log.Log(error) @>).Calls<Exception>(fun (_) -> logged := true)
                        .Create()

        let service = Mock<IService>()
                         .Setup(fun me -> <@ me.Translate(any()) @> ).Raises(error)
                         .Create()

        let translator = Translator(logger, service)

        translator.Translate("Hello") |> ignore

        logged.Value |> should equal true
``` 

Mapping the Foq code to the two previous examples should be pretty straightforward. The main difference is in the third test: unless I am mistaken, I believe Foq doesn’t support verifying expected behaviors, so we check that the logger has been called with the expected exception by setting a flag upon that call. It’s not quite as elegant as the “Validate” functionality Moq has, but it’s still very understandable – and, given that I have shot myself in the foot a few times in the past with that type of functionality, I actually don’t mind the extra-explicitness.

As a side-note, the previous version of Foq didn’t support throwing an explicit Exception instance, which I thought was a bit of a problem – for instance, I couldn’t have written the 3rd test case without that feature. So I proceeded to whine on the interwebs:

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr"><a href="https://twitter.com/ptrelford">@ptrelford</a> in Foq, I can only specify the type, but not raise a specific exception, correct?</p>&mdash; Mathias Brandewinder (@brandewinder) <a href="https://twitter.com/brandewinder/status/286728552127295488">January 3, 2013</a></blockquote> <script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

… and the next day, Phil had it implemented. Hats off, and thank you!

And that’s all I have for today! I hope you found this useful, and maybe if you don’t already, you’ll consider using F# to test your C# code… I put the code sample on [GitHub here](https://github.com/mathias-brandewinder/Mocking), if you are interested.

For the sake of full disclosure, if you look into the details of the code, you’ll see something a bit ugly; I added the `FSharp.PowerPack.dll` and `FSharp.PowerPack.Linq.dll` directly in there, because I ran into some issues on my local machine, where the test runner was looking for the wrong version of the PowerPack. Long story short, I was too lazy to do it right – if anyone knows how to make this cleaner (Phil suggested to look into [Tao’s post on BindingRedirect](http://apollo13cn.blogspot.com/2012/02/f-powerpack-with-dev11-preview.html), I am all ears!
