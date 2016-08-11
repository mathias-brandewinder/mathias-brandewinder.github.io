---
layout: post
title: On the road from C# to F#&#58; more stocks
tags:
- F#
- Scripting
- Record
- Option
- Map
- Finance
- Functional
---

In our last post, we saw how to use [F# to read historical stock quotes]({{ site.url }}/2010/06/21/On-the-road-from-C-to-F-reading-Stock-Quotes/) from Yahoo. Today we’ll take the raw response, which is a big block of text, and break it up into a list of individual quotes.  

## Breaking up the response into lines  

The function we wrote last time, `GetResponse`, receives one chunk of text from the web service, formatted like this:     

```
Date,Open,High,Low,Close,Volume,Adj Close      
2010-03-08,28.52,28.93,28.50,28.63,39414500,28.50       
2010-03-05,28.66,28.68,28.42,28.59,56001800,28.46      
 2010-03-04,28.46,28.65,28.27,28.63,42890600,28.50
```       

What we need to do now is break up this into individual lines of text, and parse them to read individual quotes. The first part is straightforward: the function `BreakIntoLines` calls `String.Split()`, using `char(10)`, the code for line break, as a delimiter, and returns an Array of strings.  
``` fsharp
let BreakIntoLines (response:string) =
  response.Split((char)10)
``` 

Note the type annotation on the function argument: without context, F# cannot infer the type of “response”, and we need to specify that this function expects a string argument.

## Parsing valid lines into Quote records

The second part is a bit more complex. We need to break each line into 7 components (date, open, etc…), deal with lines that are not valid, like the header, and store the result in an appropriate structure.

We will store individual quotes into records. A `Record` is a data type somewhat similar to the C# struct. It has named fields, which makes it more expressive than Tuples, and is less involved than a class. Here is the declaration for our Quote record – concise, and pretty self-explanatory: 

``` fsharp
type Quote={
  Symbol:string;
  Date:DateTime;
  Open:double;
  Close:double;
  Low:double;
  High:double;
  Volume:int64}
``` 

<!--more-->

In a perfect world, all the lines in the response would correspond to well-formed quotes, and we could simply break each line using the commas as a delimited, and building a `Quote` record per line this way:

``` fsharp
let ParseQuote (line:string) symbol =
  let parsed = line.Split(',')
  {
    Symbol=symbol;
    Date=DateTime.Parse(parsed.[0]);
    Open=Convert.ToDouble(parsed.[1]);
    Close=Convert.ToDouble(parsed.[4]);
    Low=Convert.ToDouble(parsed.[3]);
    High=Convert.ToDouble(parsed.[2]);
    Volume=Convert.ToInt64(parsed.[5]);}
``` 

Note the dot before the `[i]`: to access the ith element of an Array in F#, you would use `myArray.[i]`. 

Also if you are curious, I initially had `Volume` as a regular `Int32`, but found at least one stock where this wasn’t sufficient!

## Failure is an Option

Unfortunately, we&#160; don’t live in that perfect world, and we have to assume that this could fail. **I will do something here which I normally consider bad practice, namely wrapping this in the equivalent of a C# try/catch block and ignoring the exceptions**. I chose to do so because it will allow us to keep the code easier to read and discuss some interesting aspects of F#.

The equivalent of a C# try / catch block is a `try / with`, with pattern-matching after the with to determine the specific exception that took place. What we want is something like this:

``` fsharp
let ParseQuote (line:string) symbol =
  try
    // parse and return quote
  with
    | _ -> // a problem occurred
``` 

We want to try parsing the line and return the quote if it works; if any exception is encountered, the code will go to the with block, where we use the wildcard symbol `_` to catch any exception.

We need both branches of the function to return something, though. To that effect, we will use the F# `Option`. An `Option` is somewhat analogous to the C# `Nullable<T>` : just like the Nullable of T can either contain a T or be null, the Option can be **Some** T, or **None**. Here is the complete version of the `ParseQuote` function:

``` fsharp
let ParseQuote (line:string) symbol =
  try
    let parsed = line.Split(',')
    {
      Symbol=symbol;
      Date=DateTime.Parse(parsed.[0]);
      Open=Convert.ToDouble(parsed.[1]);
      Close=Convert.ToDouble(parsed.[4]);
      Low=Convert.ToDouble(parsed.[3]);
      High=Convert.ToDouble(parsed.[2]);
      Volume=Convert.ToInt64(parsed.[5]);} 
      |> Some
  with
    | _ -> None
``` 

## Putting it all together

Now we have all the functions we need to transform the blob of text we receive, into an array of `Quote` records:

``` fsharp
let ReadQuotes symbol date1 date2 = 
  CreateRequest symbol date1 date2 
  |> GetResponse 
  |> BreakIntoLines
  |> Array.map (fun line –> ParseQuote line symbol)
  |> Array.filter (fun element -> element.IsSome)
  |> Array.map (fun element -> element.Value)
``` 

We break the response into an array of lines, and apply a **map**, which in plain English would translate to “take the input array, and for each line in the array apply the function “ParseQuote line symbol”, and put the result in a new array”. `ParseQuote` returns an `Option`, so we need to eliminate the cases which return `None`. We do that by applying a **filter** to the array; in plain English again, we “take every element of the input array, and for each element in that array, if the function “IsSome” returns true, i.e. if the element is `Option.Some` and not `Option.None`, add the element to the output array”. Now that we removed all the None cases, we apply a last mapping to the array, to get rid of the Option, and keep only plain Quote records.

We can now modify our Main function:

``` fsharp
let Main =
  printfn "Symbol: "
  let symbol = Console.ReadLine()
  printfn "Start date (yyyy/mm/dd)"
  let startDate = DateTime.Parse(Console.ReadLine())
  printfn "End date (yyyy/mm/dd)"

  let endDate = DateTime.Parse(Console.ReadLine())
  let result = ReadQuotes symbol startDate endDate

  for quote in result do 
    printfn "On %s it closed at %f" (quote.Date.ToShortDateString()) (quote.Close)
  
  Array.map (fun quote -> quote.Low) result
  |> Array.min
  |> printfn "Min was %f"

  Array.map (fun quote -> quote.High) result
  |> Array.max
  |> printfn "Max was %f"

  Console.ReadKey()
``` 

After reading the quotes, we iterate over the quotes in the results array, and print the date and corresponding close value - which we could equally well have done it using Array.map. We also retrieve and print the minimum and maximum values reached over the period.

## Run this as a Script

I’ll finish with a nice F# feature: scripting. In your F# project, select right-click > Add > New Item > F# script file; this will add a Script file to your project, which is really just an empty code file with a .fsx extension. Copy/paste the code we just wrote into the new script file (I named mine QuotesScript.fsx), and&#160; then copy the file&#160; itself onto your desktop. Now if you right-click on the file, you’ll see somewhere in the context menu an option “**Run with F# Interactive**”:

![RunScript]({{ site.url }}/assets/2010-07-05-RunScript_thumb.png)

Selecting that option will run the program we wrote in the Console as a script:

![ScriptInConsole]({{ site.url }}/assets/2010-07-05-ScriptInConsole_thumb.png)

We can create and run .Net scripts, just like that. Pretty cool, no?

Hope you enjoyed this installment of my travelogue on my journey from C# to F#; please let me know if you have questions, or suggestions on how to do this better – I am still in the process of learning, and would very much appreciate to hear them!
