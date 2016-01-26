---
layout: post
title: Taking a peek at F# on StackOverflow
tags:
- F#
- StackOverflow
- Type-Provider
- Data-Analysis
- JSON
---

I got curious the other day about how to measure the F# community growth, and thought it could be interesting to take a look at this through StackOverflow. As it turns out, it’s not too hard to get some data, because [StackExchange exposes a nice API](https://api.stackexchange.com/docs), which allows you to make all sorts of queries and get a JSON response back.

As a starting point, I figured I would just try to get the number of questions asked per month. The API allows you to [retrieve questions on any site, by tag, between arbitrary dates](https://api.stackexchange.com/docs/questions). Responses are paged: you can get up to 100 items per page, and keep asking for next pages until there is nothing left to receive. That sounds like a perfect job for the [FSharp.Data JSON Type Provider](http://fsharp.github.io/FSharp.Data/library/JsonProvider.html).

<!--more-->

First things first, we create a type, `Questions`, by pointing the JSON Type Provider to a url that returns questions; based on the structure of the JSON document it receives, the Type Provider creates a type, which we will then be able to use to make queries:

``` fsharp
#I"../packages"
#r @"FSharp.Data.2.2.0\lib\net40\FSharp.Data.dll"
open FSharp.Data
open System

[<Literal>]
let sampleUrl = "https://api.stackexchange.com/2.2/questions?site=stackoverflow"
type Questions = JsonProvider<sampleUrl>
```

Next, we’ll need to grab all the questions tagged F# between 2 given dates. As an example, the following would return the second page (questions 101 to 200) from all F# questions asked between January 1, 2014 and January 31, 2015:

https://api.stackexchange.com/2.2/questions?page=2&pagesize=100&fromdate=1420070400&todate=1422662400&tagged=F%23&site=stackoverflow

There are a couple of quirks here. First, the dates are in UNIX standard, that is, the number of seconds elapsed from January 1, 1970. Then, we need to keep pulling pages, until the response indicates that there are no more questions to receive, which is indicated by the HasMore property. That’s not too hard: let’s create a couple of functions, first to convert a .NET date to a UNIX date, and then to build up a proper query, appending the page and dates we are interested in to our base query – and finally, let’s build a request that recursively calls the API and appends results, until there is nothing left:

``` fsharp
let fsharpQuery = "https://api.stackexchange.com/2.2/questions?site=stackoverflow&;tagged=F%23&pagesize=100"

let unixEpoch = DateTime(1970,1,1)
let unixTime (date:DateTime) =
  (date - unixEpoch).TotalSeconds |> int64

let page (page:int) (query:string) =
  sprintf "%s&page=%i" query page
let between (from:DateTime) (``to``:DateTime) (query:string) =
  sprintf "%s&&fromdate=%i&todate=%i" query (unixTime from) (unixTime ``to``)

let questionsBetween (from:DateTime) (``to``:DateTime) =
  let baseQuery = fsharpQuery |> between from ``to``
  let rec pull results p =
    let nextPage = Questions.Load (baseQuery |> page p)
    let results = results |> Array.append nextPage.Items
    if (nextPage.HasMore)
    then pull results (p+1)
    else results
  pull Array.empty 1
```

And we are pretty much done. At that point, we can for instance ask for all the questions asked in January 2015, and check what percentage were answered:

``` fsharp
let january2015 = questionsBetween (DateTime(2015,1,1)) (DateTime(2015,1,31))

january2015
|> Seq.averageBy (fun x -> if x.IsAnswered then 1. else 0.)
|> printfn "Average answer rate: %.3f"
```

… which produces a fairly solid 78%.

If you play a bit more with this, and perhaps try to pull down more data, you might experience (as I did) the Big StackExchange BanHammer. As it turns out, the API has usage limits (which is totally fair). In particular, if you ask for too much data, too fast, you will get banned from making requests, for a dozen hours or so.

This is not pleasant. However, in their great kindness, the API designers have provided a way to avoid it. When you are making too many requests, the response you receive will include a field named “backoff”, which indicates for how many seconds you should back off until you make your next call.

This got me stumped for a bit, because that field doesn’t show up by default on the response – only when you are hitting the limit. As a result, I wasn’t sure how to pass that information to the JSON Type Provider, until [Max Malook](https://twitter.com/max_malook) [helped me out](http://stackoverflow.com/a/28980109/114519) (thanks so much, Max!). The trick here is to supply not one sample response to the type provider, but a list of samples, in that case, one without the backoff field, and one with it.

I carved out an artisanal, hand-crafted sample for the occasion, along these lines:

``` fsharp
[<Literal>]
let sample = """
[{"items":[
  {"tags":["f#","units-of-measurement"],//SNIPPED FOR BREVITY}],
  "has_more":false,
  "quota_max":300,
  "quota_remaining":294},
{"items":[
  {"tags":["f#","units-of-measurement"],//SNIPPED FOR BREVITY}],
  "has_more":false,
  "quota_max":300,
  "quota_remaining":294,
  "backoff":10}]"""

type Questions = JsonProvider<sample,SampleIsList=true>
```

… and everything is back in order – we can now modify the recursive request, causing it to sleep for a bit when it encounters a backoff. Not the cleanest solution ever, but hey, I just want to get data here:

``` fsharp
let questionsBetween (from:DateTime) (``to``:DateTime) =
  let baseQuery = fsharpQuery |> between from ``to``
  let rec pull results p =
    let nextPage = Questions.Load (baseQuery |> page p)
    let results = results |> Array.append nextPage.Items
    if (nextPage.HasMore)
    then
      match nextPage.Backoff with
      | Some(seconds) -> System.Threading.Thread.Sleep (1000*seconds + 1000)
      | None -> ignore ()
      pull results (p+1)
    else results
  pull Array.empty 1
```

So what were the results? I decided, quite arbitrarily, to count questions month by month since January 2010. Here is how the results looks like:

![F# question on StackOverflow]({{ site.url }}/assets/fsharp-question-stackoverflow.png)

Clearly, the trend is up – it doesn’t take an advanced degree in statistics to see that. It’s interesting also to see the slump around 2012-2013; I can see a similar pattern in the Meetup registration numbers in San Francisco. My sense is that after a spike in interest in 2010, when F# launched with Visual Studio, there hasn’t been much marketing push for the language, and interest eroded a bit, until serious community-driven efforts took place. However, I don’t really have data to back that up – this is speculation.

How this correlates to overall F# adoption is another question: while I think this curves indicates growth, the number of questions on StackOverflow is clearly a very indirect measurement of how many people actually use it, and StackOverflow itself is a distorted sample of the overall population. Would be interesting to take a similar look at GitHub, perhaps…
