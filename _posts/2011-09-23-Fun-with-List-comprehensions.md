---
layout: post
title: Fun with List comprehensions
tags:
- F#
- List
- Comprehension
- FizzBuzz
---

I had the pleasure to present at the North Bay .NET user group this week on F#, where people asked me all sorts of great questions. At some point, we got into [List comprehensions](http://en.wikipedia.org/wiki/List_comprehension#F.23) – a convenient syntax to generate lists - via an example along these lines (which returns a list of the multiple of 2, from 2 to 40):  

``` fsharp
let list = 
   [ for i in 1 .. 20 do yield 2 * i ]
``` 

While slightly more complex, the actual example is in essence equivalent. A question followed: how complex can the code within the brackets be?

Well, pretty much as complex as you want it to be. Take this for instance:

``` fsharp
let list =
   [
      for i in 1 .. 10 do yield 2 * i
      for i in 1 .. 10 do yield 3 * i
   ]
``` 

This will return a list of the multiples of 2 from 2 to 20, followed in the same list by the multiples of 3 from 3 to 30. Nice.

But you can go much wilder, and start putting code in there, too. For instance, we can expand the previous example a bit and morph it into a nice and concise [FizzBuzz](http://www.codinghorror.com/blog/2007/02/why-cant-programmers-program.html):

``` fsharp
type Fizzbuzz = Fizz | Buzz | FizzBuzz | Number of int

let fizzBuzz n =
   [
      let fizzBuzzConvert number =
         if number % 2 = 0 && number % 5 = 0 then FizzBuzz
         elif number % 5 = 0 then Buzz
         elif number % 2 = 0 then Fizz
         else Number(number)
      
      for i in 1 .. n do yield fizzBuzzConvert i
   ]
``` 

We declare a discriminated union, covering all the possible outcomes of FizzBuzz, declare inside the comprehension itself a function that maps an integer to a FizzBuzz result, and generate the list of results from i to n. Running this in the interactive window results in the following:

``` fsharp
let fizzBuzz n =
   [
      let fizzBuzzConvert number =
         if number % 2 = 0 && number % 5 = 0 then FizzBuzz
         elif number % 5 = 0 then Buzz
         elif number % 2 = 0 then Fizz
         else Number(number)
      
      for i in 1 .. n do yield fizzBuzzConvert i
   ];;

type Fizzbuzz =
  | Fizz
  | Buzz
  | FizzBuzz
  | Number of int
val fizzBuzz : int -> Fizzbuzz list

> let f = fizzBuzz 20;;

val f : Fizzbuzz list =
  [Number 1; Fizz; Number 3; Fizz; Buzz; Fizz; Number 7; Fizz; Number 9;
   FizzBuzz; Number 11; Fizz; Number 13; Fizz; Buzz; Fizz; Number 17; Fizz;
   Number 19; FizzBuzz]
``` 

I would classify List comprehension under the “nice to have” features – it’s perfectly possible to write excellent code without it. At the same time, it’s a very, very convenient way to work with Lists, which I now miss in C#…
