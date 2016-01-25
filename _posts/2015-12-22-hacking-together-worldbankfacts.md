---
layout: post
title: hacking together @worldbankfacts, a World Bank Twitter Bot
tags:
- F#
- World-Bank
- Type-Provider
- Twitter
- fsAdvent
- FParsec
---

>This is my modest contribution to the [F# Advent Calendar 2015](https://sergeytihon.wordpress.com/2015/10/25/f-advent-calendar-in-english-2015/). Thanks to [@sergey_tihon](https://twitter.com/sergey_tihon) for organizing it! Check out the epic stuff others have produced so far on his website or under the [#fsAdvent hashtag](https://twitter.com/search?q=%23fsadvent) on Twitter. Also, don’t miss the [Japan Edition of #fsAdvent](http://connpass.com/event/22056/) for more epicness…

Sometime last year, in a moment of beer-fueled inspiration, I ended up putting together [@fsibot](https://twitter.com/fsibot), the ultimate mobile F# IDE for the nomad developer with a taste for functional-first programming. This was fun, some people created awesome things with it, other people, [not so much](https://github.com/mathias-brandewinder/fsibot/blob/master/FsiBot/FsiBot.Tests/UnitTests.fs#L26-L55), and I learnt a ton.

People also had feature requests (of course they did), some obviously crucial (Quines! We need quines!), some less so. Among others came the suggestion to support querying the World Bank for data, and returning results as a chart.

<!--more-->

So... Let's do it! After a bit of thought, I decided I would not extend [@fsibot](https://twitter.com/fsibot) to support this, but rather build a separate bot, with its own [external DSL](http://martinfowler.com/books/dsl.html). My thinking here was that adding this as a feature to @fsibot would clutter the code; also, this is a specialized task, and it might make sense to create a dedicated language for it, to make it accessible to the broader public who might not be familiar with F# and its syntax.

You can find [the code for this thing here](https://github.com/mathias-brandewinder/worldbankbot).

## The World Bank Type Provider

Let's start with the easy part - accessing the World Bank data and turning it into a chart. So what I want to do is something along the lines of 'give me the total population for France between 2000 and 2005', and make a nice columns chart out of this. The first step is trivial using the World Bank type provider, which can be found in the [FSharp.Data library](http://fsharp.github.io/FSharp.Data/library/WorldBank.html):

``` fsharp
open FSharp.Data

let wb = WorldBankData.GetDataContext ()
let france = wb.Countries.France
let population = france.Indicators.``Population, total``
let series = [ for year in 2000 .. 2005 -> year, population.[year]]
```

Creating a chart isn't much harder, using [FSharp.Charting](http://fslab.org/FSharp.Charting/):  

``` fsharp
open FSharp.Charting

let title = sprintf "%s, %s" (france.Name) (population.Name)
let filename = __SOURCE_DIRECTORY__ + "/chart.png"

Chart.Line(series, Title=title)
|> Chart.Save(filename)
```


## Wrapping up calls to the Type Provider  

Next, we need to take in whatever string the user will send us over Twitter, and convert it into something we can execute. Specifically, what we want is to take user input along the lines of "France, Total population, 2000-2005", and feed that information into the WorldBank type provider.

Suppose for a moment that we had broken down our message into its 4 pieces, a country name, an indicator name, and two years. We could then call the WorldBank type provider, along these lines:

``` fsharp
type WB = WorldBankData.ServiceTypes
type Country = WB.Country
type Indicator = Runtime.WorldBank.Indicator

let findCountry (name:string) =
  wb.Countries
  |> Seq.tryFind (fun c -> c.Name = name)

let findIndicator (name:string) (c:Country) =
  c.Indicators
  |> Seq.tryFind (fun i -> i.Name = name)

let getValues (year1,year2) (indicator:Indicator) =
  [ for year in year1 .. year2 -> year, indicator.[year]]
```

We can then easily wrap this into a single function, like this:

``` fsharp
let getSeries (country,indicator,year1,year2) =
  findCountry country
  |> Option.bind (findIndicator indicator)
  |> Option.map (getValues (year1,year2))
```

## Defining our language

This is a bit limiting, however. Imagine that we wanted to also support queries like "France, Germany, Italy, Total population, total GDP, 2000". We could of course pass in everything as lists, say,

 ["France";"Germany"], ["Total population"], [2000],

… but we'd have to then examine how many elements the list contains to make a decision. Also, more annoyingly, this allows for cases that should not be possible: ideally, we wouldn't want to even allow requests such as

[], [], [2000; 2010; 2020].

One simple solution is to carve out our own language, using F# Discriminated Unions. Instead of lists, we could, for instance, create a handful of types to represent valid arguments:

``` fsharp
type PLACE =
  | COUNTRY of string
  | COUNTRIES of string list

type MEASURE =
  | INDICATOR of string

type TIMEFRAME =
  | OVER of int * int
  | IN of int
```

This is much nicer: we can now clean up our API using pattern matching, eliminating a whole class of problems:

``` fsharp
let cleanAPI (place:PLACE) (values:MEASURE) (timeframe:TIMEFRAME) =
match (place, values, timeframe) with
| COUNTRY(country), INDICATOR(indicator), OVER(year1,year2) ->            
// do stuff
| COUNTRIES(countries), INDICATOR(indicator), OVER(year1,year2) ->
// do different stuff
| // etc...
```

## Parsing user input

The only problem we are left with now is to break a raw string - the user request - into a tuple of arguments. If we have that, then we can compose all the pieces together, piping them into a function that will take a string and go all the way down to the type provider.

We are faced with a decision now: we can go the hard way, powering our way through this using [Regex](http://stackoverflow.com/questions/1732348/regex-match-open-tags-except-xhtml-self-contained-tags/1732454#1732454) and string manipulation, or the easy way, using a parser like [FParsec](http://www.quanttec.com/fparsec/). Let's be lazy and smart!

> Note to self: when using FParsec from a script file, make sure you #r FParsecCS before FParsec. I spent a couple of hours stuck trying to understand what I was doing wrong because of that one.

Simply put, FParsec is awesome. It allows you to define small functions to parse input strings, test them on small pieces of input, and compose them together into bigger and badder parsers. Let's illustrate: suppose that in our DSL, we expect user requests to contain a piece that looks like "IN 2010", or "OVER 2000 - 2010" to define the timeframe.

In the first case, we want to recognize the string “IN”, followed by spaces, followed by an integer; if we find that pattern, we want to retrieve the integer and create an instance of IN:

``` fsharp
let pYear = spaces >>. pint32 .>> spaces
let pIn =
  pstring "IN" >>. pYear
  |>> IN
```

If we run the parser on a well-formed string, we get what we expect:

``` fsharp
run pIn "IN  2000 "
>
val it : ParserResult<TIMEFRAME,unit> = Success: IN 2000
```

If we pass in an incorrectly formed string, we get a nice error diagnosis:

``` fsharp
run pIn "IN some year "
>
val it : ParserResult<TIMEFRAME,unit> =
Failure:
Error in Ln: 1 Col: 4
IN some year
^
Expecting: integer number (32-bit, signed)
```

Beautiful! The second case is rather straightforward, too:

``` fsharp
let pYears =
  tuple2 pYear (pstring "-" >>. pYear)

let pOver =
  pstring "OVER" >>. pYears
  |>> OVER
```

Passing in a well-formed string gives us back OVER(2000,2010):

``` fsharp
run pOver "OVER 2000- 2010"
>
val it : ParserResult<TIMEFRAME,unit> = Success: OVER (2000,2010)
```

Finally we can compose these together, so that when we encounter either IN 2000, or OVER 2000 - 2005, we parse this into a TIMEFRAME:

``` fsharp
let pTimeframe = pOver <|> pIn
```

I won't go into the construction of the full parser - you can just take a look here. The trickiest part was my own doing. I wanted to allow messages without quotes, that is,

COUNTRY France

and not

COUNTRY "France"

The second case is much easier to parse (look for any chars between ""), especially because there are indicators like, for instance, "Population, total". The parser is pretty hacky, but hey, it mostly works, so... ship it!

## Ship it!

That's pretty much it. At that point, all the pieces are there. I ended up <del>copy pasting</del> taking inspiration from the existing @fsibot code, using [LinqToTwitter](https://github.com/JoeMayo/LinqToTwitter) to deal with reading and writing to Twitter, and [TopShelf](http://topshelf-project.com/) to host the bot as a Windows service, hosted on an Azure VM, and voila! You can now tweet to [@worldbankfacts](https://twitter.com/worldbankfacts), and get back a nice artisanal chart, hand-crafted just for you, with the freshest data from the World Bank:

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr"><a href="https://twitter.com/brandewinder">@brandewinder</a> Population, total in France, Germany, Italy, Spain (2000-2015) <a href="https://t.co/efZGjySgrN">pic.twitter.com/efZGjySgrN</a></p>&mdash; World Bank Facts (@worldbankfacts) <a href="https://twitter.com/worldbankfacts/status/686901096321691648">January 12, 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet" data-lang="en"><p lang="fr" dir="ltr"><a href="https://twitter.com/brandewinder">@brandewinder</a> France, Population, total (1990-2010) <a href="https://t.co/Gp2TJygfS1">pic.twitter.com/Gp2TJygfS1</a></p>&mdash; World Bank Facts (@worldbankfacts) <a href="https://twitter.com/worldbankfacts/status/687704671356502016">January 14, 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

A couple of quick final comments:

- One of the most obvious issues with the bot is that Twitter offers very minimal support for IntelliSense (and by minimal, I mean 'none'). This is a problem, because we lose discoverability, a key benefit of type providers. To compensate for that, I added a super-crude string matching strategy, which will give a bit of flexibility around misspelled country or indicator names. This is actually a fun problem - I was a bit pressed by time, but I'll probably revisit it later.
- In the same vein, it would be nice to add a feature like "find me an indicator with a name like GDP total". That should be reasonably easy to do, by extending the language to support instructions like HELP and / or INFO.
- The bot seems like a perfect case for some [Railway-Oriented Programming](http://fsharpforfunandprofit.com/rop/). Currently the wiring is pretty messy; for instance, our parsing step returns an option, and drops parsing error messages from FParsec. That message would be much more helpful to the user than our current message that only states that “parsing failed". With ROP, we should be able to compose a clean pipeline of functions, along the lines of parseArguments >> runArguments >> composeResponse.
- The performance of looking up indicators by name is pretty terrible, at least on the first call on a country. You have been warned :)
- That's right, there is no documentation. Not a single test, either. Tests show a disturbing lack of confidence in your coding skills. Also, I had to ship by December 22nd :)

That being said, in spite of its many, many warts, I am kind of proud of [@worldbankfacts](https://twitter.com/worldbankfacts)! It is ugly as hell, the code is full of duct-tape, the parser is wanky, and you should definitely not take this as ‘best practices’. I am also not quite clear on how the Twitter rate limits work, so I would not be entirely surprised if things went wrong in the near future… In spite of all this, hey, it kind of runs! Hopefully you find the code or what it does fun, and perhaps it will even give you some ideas for your own projects. In the meanwhile, I wish you all happy holidays!

You can find [the code for this thing here](https://github.com/mathias-brandewinder/worldbankbot).

_This is my modest contribution to the [F# Advent Calendar 2015](https://sergeytihon.wordpress.com/2015/10/25/f-advent-calendar-in-english-2015/). Thanks to [@sergey_tihon](https://twitter.com/sergey_tihon) for organizing it! Check out the epic stuff others have produced so far on his website or under the [#fsAdvent hashtag](https://twitter.com/search?q=%23fsadvent) on Twitter. Also, don’t miss the [Japan Edition of #fsAdvent](http://connpass.com/event/22056/) for more epicness…_

_I also wanted to say thanks to [Tomas Petricek](https://twitter.com/tomaspetricek), for opening my eyes to discriminated unions as a modeling tool, and [Phil Trelford](https://twitter.com/ptrelford) for introducing me to FParsec, which is truly a thing of beauty. They can be blamed to an extent for inspiring this ill-conceived project, but whatever code monstrosity is in the repository is entirely my doing :)_
