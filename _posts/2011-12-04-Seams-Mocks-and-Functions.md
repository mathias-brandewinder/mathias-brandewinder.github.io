---
layout: post
title: Seams, Mocks, and Functions
tags:
- C#
- F#
- OO
- Mocks
- Testing
- Functional
- FsUnit
- Design
- TDD
- Books
---

I am in the middle of “[Working Effectively with Legacy Code](http://www.amazon.com/Working-Effectively-Legacy-Michael-Feathers/dp/0131177052)”, and found it every bit as great as it was said to be. In the book, Feathers introduces the concept of [Seams and Enabling Points](http://books.google.com/books?id=fB6s_Z6g0gIC&lpg=PT61&pg=PT61#v=onepage&q&f=false):   

> a **Seam** is a place where you can alter behavior in your program without editing it in that place    
> every seam has an **enabling point**, a place where you can make the decision to use one behavior or another.  

The idea - as I understand it - is that an enabling point is a hook for testability, a place where you can replace the behavior of a piece of code with your own controlled behavior, and validate that the results are as expected.  

The reason I am bringing this up is that I have been writing lots of F# lately, and it made me realize that a functional style provides lots of enabling points, and can be much easier to test than object-oriented code.  

Here is a simplified, but representative, example of the problem I was looking at: I needed to pick a random item in a list. In C#, a method along these lines would do the job:  

``` csharp
public T PickFrom(IList<T> list)
{
   var random = new Random();
   return list[random.Next(list.Count())];
}
``` 

However, this code is utterly untestable; it’s also probably a terrible idea to instantiate a new Random every time this is called, so we modify it this way:

``` csharp
public T PickFrom(IList<T> list, Random random)
{
   return list[random.Next(list.Count())];
}
``` 

This is much better: now we have a decent Enabling Point, because the list of arguments of the method contains everything that is used inside the method. However, this is still untestable, but for a different reason: by definition, `Random.Next()` will return different values every time `PickFrom` is called, and expecting a repeatable result from `PickFrom` is a bit of a desperate enterprise.

<!--more-->

To be able to assert anything, we need to control the behavior of the Random, and make it [not-too-random](http://dilbert.com/strips/comic/2001-10-25/) in the test. After years of OO training, the solution comes easy: if you have a problem, add some indirection:

``` csharp
public T PickFrom(IList<T> list, IRandom random)
{
   return list[random.Next(list.Count())];
}

public interface IRandom
{
   int Next(int lastIndex);
}
``` 

We can now pull the big guns and test this using Mocks, which is certainly a pleasant feeling:

``` csharp
[Test]
public void Check_With_Mock()
{
   var list = new List<string>() { "A", "B", "C" };
   var random = new Mock<IRandom>();
   random.Setup(it => it.Next(3)).Returns(1);

   var picker = new Picker<string>();
   var pick = picker.PickFrom(list, random.Object);

   Assert.That(pick, Is.EqualTo("B"));
}
``` 

In plain English, what we are saying here is that “if Random.Next(3) was called and happened to return 1, the result of PickFrom better be the item at index 1 of the list, which is B”. That does the job, but, to quote a former Math teacher of mine, if feels a bit like using a Jackhammer to insert a thumbtack.

Faced with the same issue in F#, I ended up doing something a bit different:

``` fsharp
let pickFrom (list: list<'a>) picker =  
   let index = picker (list.Length)
   list.Item index
``` 

The magic of type inference recognizes that picker is of type `(int –> int)`, which means that it is a function that expects an integer as input, and “returns” / evaluates as an integer. To use a real `Random`, I would do something like this, creating a function `rngPicker` that has the correct signature, and uses a `Random` instance:

``` fsharp
open System

let pickFrom (list: list<'a>) picker =  
   let index = picker (list.Length)
   list.Item index

let rng = new Random()
let rngPicker = fun i -> rng.Next(i)
let list = ["A"; "B"; "C"]
for i in 1 .. 10 do
   pickFrom list rngPicker
   |> Console.WriteLine
``` 

… which, when run in the interactive window, will produce a random list of picks from A, B, C. (For the curious minded, mine was BCACACABAC). 

The nice thing here is that I can also test this fairly easily, using NUnit and the wonderful [**FsUnit**](http://fsunit.codeplex.com/):

``` fsharp
namespace Seams.Tests

open NUnit.Framework
open FsUnit

[<TestFixture>]
type PickerTests() =

   [<Test>]
   member test.``pickFrom should return item at index obtained from picker``() =
      // Arrange
      let list = ["A"; "B"; "C"]
      let picker i = 
         match i with 
         | 3 -> 1
         | _ -> failwith "Ooops"

      // Act
      let result = Picker.pickFrom list picker

      // Assert
      result |> should equal "B"
``` 

In essence, I am doing here exactly the same thing as I did with the Mock previously, creating an arbitrary picker which will return 1 when called with 3, and validating the result of the function pickFrom, given that known setup.

The beauty here is that this is every bit as flexible as the Interface/Mocks solution, but involves much less ceremony and tooling.

So what’s the point here? First, that approach is by no means unique to F#, and can be used in C# equally well. I could change the `PickFrom` signature to accept a function, and proceed in a manner similar to the F# example:

``` csharp
public T PickFrom(IList<T> list, Func<int, int> picker)
{
   return list[picker(list.Count())];
}
``` 

Probably because of how I have been trained to think, this doesn’t feel like the most obvious solution in a C# world, where boundaries are often expressed via interfaces.

Conversely, I found it interesting that after a few days of testing in F#, I still haven’t felt the need for a Mocking framework a single time. I think this has to do with the fact that a functional style provides seams everywhere, because composing functions allows to pipe in any function of equivalent signature, making testing fairly straightforward.

*As an aside, I wanted to mention a recent post by Phil Trelford discussing [Stubs and TDD with F#](http://trelford.com/blog/post/Stubs.aspx), which I found very inspirational.*
