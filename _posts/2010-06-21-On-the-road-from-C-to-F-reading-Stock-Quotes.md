---
layout: post
title: On the road from C# to F#&#58; reading Stock Quotes
tags:
- F#
- Finance
- Functional
- C#
---

Lately I have spent time on a pet project, which requires access to historical financial data. [Mads Kristensen](http://madskristensen.net/) has a nice post where he shows how to [read&#160; stock quotes from Yahoo finance using C#](http://madskristensen.net/post/Stock-quote-class-in-C.aspx), which was very helpful to get started. I figured it would be interesting to try out a conversion to F# and see what the result looked like.  

Mads focus is on getting quasi real-time updates of a quote; my interest is in an easier problem: retrieving historical data. Fortunately, Yahoo provides a free service for that, too. Given a quote symbol and two dates, it returns a comma-separated file list of all the values for the quote between these 2 dates.  

So what do we need to do? Given a valid symbol and 2 dates, we want to create the `WebRequest` to send to Yahoo, retrieve the response, break it into lines, and parse each line into a quote, which will be added to a list. The core of the resulting program will be the `ReadQuotes` function, which will look like this:  

``` fsharp
let ReadQuotes symbol date1 date2 = 
  CreateRequest symbol date1 date2 
  |> GetResponse 
  |> BreakIntoLines
  |> CreateQuotes symbol
``` 

## Creating the WebRequest

The web request required to obtain historical data from Yahoo follows this pattern: 

`http://ichart.finance.yahoo.com/table.csv?s=S&a=A&b=B&c=C&d=D&e=E&f=F&g=d&ignore=.csv`

where:

* S is the symbol (ex: MSFT) 
* A, B, C are the start month, day and year, the month being coded in base 0 (i.e. January is 0) 
* D, E, F are the end month, day and year, the month being coded in base 0 (i.e. January is 0) 

For instance, replacing S with MSFT, A with 0, B with 1, C with 2010, D with 1, E with 15, F with 2010, will return all the available quotes for Microsoft between January 1 and February 15, 2010.

Let’s start by creating a Console application, by selecting new F# project > F# Application, and typing in the following code:

``` fsharp
open System
open System.Net
open System.IO
open System.Text

let RetrieveDateInfo (date:DateTime) =
  (date.Day, date.Month-1, date.Year)

let CreateRequest symbol startDate endDate =

  let startDay, startMonth, startYear = RetrieveDateInfo startDate
  let endDay, endMonth, endYear = RetrieveDateInfo endDate

  let query = String.Format("&a={0}&b={1}&c={2}&d={3}&e={4}&f={5}&g=d&ignore=.csv", startMonth, startDay, startYear, endMonth, endDay, endYear)
  let url = "http://ichart.finance.yahoo.com/table.csv?s=" + symbol + query
  WebRequest.Create(url)
``` 

<!--more-->

The `CreateRequest` function has two parts. The second part is pretty similar to the equivalent C# code: it simply builds the appropriate url string for the request. The first part is a bit more interesting: it uses the `RetrieveDateInfo` function, which, given a date, returns a Tuple with 3 elements, the day, 0-based month, and year, all at once. This uses two F# techniques: Tuples and pattern matching. 

From a C# background, you can think of a Tuple as an extension of the KeyValuePair<T1, T2> class idea; it is an ordered collection of data, which provides a convenient way to pack together data – and in this case, allows you to have a function return multiple values, without having to create a dedicated class to hold the results (C# 4.0 also supports Tuples, by the way).

Armed with this method, we can now take a date, and extract the information we need in one line:

``` fsharp
let startDay, startMonth, startYear = RetrieveDateInfo startDate
``` 

In plain English, this translates into: “take the Tuple return from RetrieveDateInfo, and match the first element with startDay, the second with startMonth, and the third with startYear”.

A few comments here regarding types and type inference. Note that we had to explicitly specify that `RetrieveDateInfo` expects a `DateTime`, because the body of the function doesn’t provide enough information to figure out what type we are talking about. On the other hand, we haven’t said anything about the types of arguments expected in `CreateRequest`. The reason is that F# is able to infer what types we are talking about, by their usage: `RetrieveDateInfo` requires a `DateTime`, and symbol is used in a string concatenation.

Note also that we declared `RetrievedDateInfo` first; if you were to place its definition after `CreateRequest`, it would not build. F# code is order-dependent (for type-inference reasons I believe), which is one aspect I am still getting used to. Coming from C#, where properties and method can be moved around freely, this is a big change of perspective. I usually arrange my C# code by visibility, putting forward what is important about the class, and hiding the “implementation details”; by contrast, F# code, as far as I understand it so far, is organized bottom-up, and directly reflects how the code works.

## Getting the response and printing out the raw result

Let’s see now if we can print out the result of the request. First, let’s get the response with the following code, which I lifted and adapted from Mads’ code.

``` fsharp
let GetResponse (request:WebRequest) =
  use response = request.GetResponse()
  use reader = new StreamReader(response.GetResponseStream(), Encoding.ASCII)
  reader.ReadToEnd()
``` 

The `use` keyword is the equivalent to the C# `using { }`, and disposes the resource once they go out of scope.

We now have the tools to get data – let’s write a simplified version of the `ReadQuotes` function, which will simply printout the raw text we get back from Yahoo:

``` fsharp
let ReadQuotes symbol date1 date2 = 
  CreateRequest symbol date1 date2 
  |> GetResponse 
  |> printfn "%s"
``` 

The `|>` is called the **pipe-forward** operator. In plain English, it translates into “take the intermediate result that is on the left, and pass it as an argument to the function that follows”. Or, in our case, “Take the request produced by CreateRequest and pass it to GetResponse”, and then “take the response from GetResponse and print it on screen”.

We are now nearly done. Let’s add a quick function where the user can input a symbol and two dates, and execute ReadQuotes:

``` fsharp
let Main =
  printfn "Symbol: "
  let symbol = Console.ReadLine()
  printfn "Start date (yyyy/mm/dd)"
  let startDate = DateTime.Parse(Console.ReadLine())
  printfn "End date (yyyy/mm/dd)"
  let endDate = DateTime.Parse(Console.ReadLine())
  ReadQuotes symbol startDate endDate
  Console.ReadKey()
``` 

If you debug the program at that point, you will see something like this:

![RawConsoleApp]({{ site.url }}/assets/2010-06-21-RawConsoleApp_thumb.png)

We’ll stop here for today, and in the next installment, we will take a look at [breaking apart that big block of text into individual quotes](http://www.clear-lines.com/blog/post/From-C-Sharp-to-F-Sharp-reading-historical-stock-quotes.aspx). I hope you enjoyed this post, and I welcome comments or questions – let me know if either anything is unclear, or if you have suggestions to make that code better, which is very possible, as I am still very new to F#!
