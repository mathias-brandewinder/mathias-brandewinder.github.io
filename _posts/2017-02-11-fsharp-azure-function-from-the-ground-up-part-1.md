---
layout: post
title: Creating an Azure Function in F# from the ground up (Part 1)
tags:
- F#
- Azure-Functions
- Azure
- Serverless
- Cloud
- Bot
- Slack
- Type-Provider
---

If you follow me on Twitter, you may have noticed a recurring topic lately: [Azure Functions][1]. I have found it both useful for many use cases, and simply fun to work with; and it fits pretty nicely with F#. I recently gave a talk at NDC London (the video should be online at some point), where I demoed a small example, trying to fit in as many features as I could, in as little time and code as possible. [Someone took up my offer to write a tutorial from the ground up][2], so I figured, let's take that example and turn it into a post. It is a demo, so what it does is not particularly useful by itself, but it illustrates many of the features and tricks I found useful, and should be a good starting point to write "real" code.

## The app: sending exchange rate updates on Slack

What we will build is an app which will post, on a regular cadence, the latest available USD/GBP exchange rate on Slack. The reason I picked that example is two fold. First, the exchange rate changes often, which will help verify that things are indeed working. Then, we'll be able to showcase how easy it is to integrate functions to put together a working application.

Before starting with the code itself, we will need two things: exchange rates, and Slack.

For the exchange rate, we will use Yahoo, while it's still there. Yahoo has a free API for exchange rates, available at the following URL:

[`http://query.yahooapis.com/v1/public/yql?q=select * from yahoo.finance.xchange where pair in ("GBPUSD")&env=store://datatables.org/alltableswithkeys`][http://query.yahooapis.com/v1/public/yql?q=select * from yahoo.finance.xchange where pair in ("GBPUSD")&env=store://datatables.org/alltableswithkeys]

This returns an xml document, which looks like this:

``` xml
<query xmlns:yahoo="http://www.yahooapis.com/v1/base.rng" yahoo:count="1" yahoo:created="2017-02-11T19:56:24Z" yahoo:lang="en-US">
    <results>
        <rate id="GBPUSD">
            <Name>GBP/USD</Name>
            <Rate>1.2486</Rate>
            <Date>2/10/2017</Date>
            <Time>10:02pm</Time>
            <Ask>1.2489</Ask>
            <Bid>1.2486</Bid>
        </rate>
    </results>
</query>
```

So the first part of our job will be to regularly call that URL, and extract the `Rate` from the xml document.

Posting to Slack isn't very difficult either. I created my own personal Slack at `mathias-brandewinder`, where I can talk to myself quietly, as well as test examples like this one. I then created a webhook, by going to `https://mathias-brandewinder.slack.com/apps/manage`, selecting `Custom Integrations`, `Incoming WebHooks`, and pick a channel to post to. I created a channel `#exchange_rate` for the occasion. Once the setup is done, you get a WebHook URL, which looks like `https://hooks.slack.com/services/S0meL0ngCrypt1cK3y`, where you can now [POST JSON messages][3].

So the second part of our job will be to take that rate, create a JSON message and POST it.

<!--more-->

## Local version

Before diving into Azure Functions, let's write the F# code we will need to achieve this, and get things to work locally, with simple F# scripts.

Making a request to Yahoo is fairly straightforward:

``` fsharp
open System.Net

let url = """http://query.yahooapis.com/v1/public/yql?q=select * from yahoo.finance.xchange where pair in ("GBPUSD")&env=store://datatables.org/alltableswithkeys"""
let client = new WebClient()
let result = client.DownloadString(url)
printfn "%s" result
```

Running this produces something along these lines:

```
<?xml version="1.0" encoding="UTF-8"?>
<query xmlns:yahoo="http://www.yahooapis.com/v1/base.rng" yahoo:count="1" yahoo:created="2017-02-11T20:20:10Z" yahoo:lang="en-US
"><results><rate id="GBPUSD"><Name>GBP/USD</Name><Rate>1.2486</Rate><Date>2/10/2017</Date><Time>10:02pm</Time><Ask>1.2489</Ask><
Bid>1.2486</Bid></rate></results></query><!-- total: 9 -->
<!-- prod_gq1_1;paas.yql;queryyahooapiscomproductiongq1;e8805764-ed45-11e6-912b-f0921c12e67c -->
```

We can extract the rate part from this with some old-fashioned, quick-and-dirty code like this:

``` fsharp
let parse (s:string) = 
    let o = "<Rate>"
    let c = "</Rate>"
    
    let st = s.IndexOf(o) + 6
    let en = s.IndexOf(c) - st

    s.Substring(st,en)

result |> parse |> float
```

Or we can go a bit fancier (we are in 2017, after all), and use the [FSharp.Data XML Type Provider][4]:

``` fsharp
#r "System.Xml.Linq.dll"
#r @"packages/FSharp.Data/lib/net40/FSharp.Data.dll"
open FSharp.Data

[<Literal>]
let sampleRate = """<query xmlns:yahoo="http://www.yahooapis.com/v1/base.rng" yahoo:count="1" yahoo:created="2017-02-11T19:56:24Z" yahoo:lang="en-US">
<results>
<rate id="GBPUSD">
<Name>GBP/USD</Name>
<Rate>1.2486</Rate>
</rate>
</results>
</query>"""

type Rate = XmlProvider<sampleRate>
let rate = Rate.Load(url)
rate.Results.Rate.Rate
```

That's pretty much all we need for the rate. How about Slack? Going quick-and-dirty again, this isn't much harder:

``` fsharp
open System.Text
#r "System.Net.Http.dll"
open System.Net.Http

let slackMessage = sprintf """{"text":"current USD/GBP rate is %f"}""" 123.455

let client = new HttpClient()
let url = "https://hooks.slack.com/services/your-key-goes-here"
let message = new StringContent(slackMessage, Encoding.UTF8)

client.PostAsync(url,message) |> ignore
```

Run this, and boom! Here we are, we got an incoming message in Slack:

![Incoming Slack Message]({{ site.url }}/assets/2017-02-11-incoming-slack-message.PNG)

## Setting up the Azure Function App

Now that we have all the pieces working, how do we get this to run on Azure Functions?

The first thing we need is to create a **Function App**. A Function App is a container, where one or more functions will live. To do that, we'll head to the [Azure Portal][5]. Click on the + sign, pick Function App from Microsoft, and Create.

![Create Function App]({{ site.url }}/assets/2017-02-11-portal-create-function-app.PNG)

You'll be presented with a few options to set up:

![Setup Function App]({{ site.url }}/assets/2017-02-11-portal-create-function-app-2.PNG)

Give the app a name and resource group a name - in our case, "sample-exchange-rate", and "sample_exchange_rate", pick the location where you want it deployed (West US in this case). I like also to give the Storage Account a human-friendly name (in this case sampleexchangerate), instead of the default random one; it makes it easier to figure out what a storage account is there for later on.

> As an aside, the reason all names follow inconsistent conventions is that the rules for what is and isn't a valid name for various Azure resources are different, which is pretty annoying.

The Hosting Plan gives you the choice between **Consumption Plan** and **App Service Plan**. Unless you have good reasons to do something different, you probably want Consumption Plan; what this means in a nutshell is, you will pay only for the time your function(s) run and the memory they use, and Azure will handle scaling automatically for you.

Finally, I recommend also selecting "Pin to dashboard", which will create a convenient shortcut to your app on the Portal dashboard.

We are now ready to go - click Create, and wait for the deployment to complete:

![Deploying Function App]({{ site.url }}/assets/2017-02-11-deploying-function-app.PNG)

## Writing our first function

Within a couple of minutes, your Function App should be ready to use, and you'll be presented with this screen, where the fun part begins.

![Deployed Function App]({{ site.url }}/assets/2017-02-11-function-app-deployed.PNG)

Let's begin with retrieving exchange rates from Yahoo. What we want is to automatically run the code we previously wrote, on a fixed schedule. To do this, we will use a timer-triggered Azure Function:

![Create Timer Function]({{ site.url }}/assets/2017-02-11-create-timer-function.PNG)

We will name that function "retrieve-rate", and set it to run every 15 seconds, by configuring its schedule, using a [CRON-style format][6]:

![Setup Timer Function]({{ site.url }}/assets/2017-02-11-setup-timer-function.PNG)

Once the function is created, you will be presented with an online development environment, with an F# script `run.fsx` generated from a template; click on the "Logs" button on the top-right corner, which will reveal a window with Logs - your function is already running! The script is being triggered and runs every 15 seconds, writing out to the log like clockwork. 

![Timer Template Code]({{ site.url }}/assets/2017-02-11-timer-template.PNG)

The template code is probably the simplest Function you could write:

``` fsharp
open System

let Run(myTimer: TimerInfo, log: TraceWriter) =
    log.Info(
        sprintf "F# Timer trigger function executed at: %s" 
            (DateTime.Now.ToString()))
```

We have a `Run` function, which takes two arguments, a (`Microsoft.Azure.WebJobs`) `TimerInfo` and a `TraceWriter` we use for logging. We'll leave it at that for now, and discuss this a bit more later. 

For now, if that function is already running... let's see if we can get our original local script to run, too, by doing a bit of copy-paste:

``` fsharp
open System
open System.Net

let url = """http://query.yahooapis.com/v1/public/yql?q=select * from yahoo.finance.xchange where pair in ("GBPUSD")&env=store://datatables.org/alltableswithkeys"""

let Run(myTimer: TimerInfo, log: TraceWriter) =
    log.Info(
        sprintf "F# Timer trigger function executed at: %s" 
            (DateTime.Now.ToString()))

    let client = new WebClient()
    let result = client.DownloadString(url)
    
    sprintf "%s" result            
    |> log.Info
```

Save, and take a look at the logs:

![Recompilation]({{ site.url }}/assets/2017-02-11-recompilation.PNG)

```
2017-02-11T22:27:47.848 Script for function 'retrieve-rate' changed. Reloading.
2017-02-11T22:27:49.598 D:\home\site\wwwroot\retrieve-rate\run.fsx(9,14): warning FS52: The value has been copied to ensure the original is not mutated by this operation or because the copy is implicit when returning a struct from a member and another member is then accessed
2017-02-11T22:27:49.598 D:\home\site\wwwroot\retrieve-rate\run.fsx(6,9): warning FS1182: The value 'myTimer' is unused
2017-02-11T22:27:49.598 Compilation succeeded.
2017-02-11T22:28:00.014 Function started (Id=54dfc25e-c99b-44e2-bfc0-3f3a92483911)
2017-02-11T22:28:00.014 F# Timer trigger function executed at: 2/11/2017 10:28:00 PM
2017-02-11T22:28:00.045 <?xml version="1.0" encoding="UTF-8"?>
<query xmlns:yahoo="http://www.yahooapis.com/v1/base.rng" yahoo:count="1" yahoo:created="2017-02-11T22:27:59Z" yahoo:lang="en-US"><results><rate id="GBPUSD"><Name>GBP/USD</Name><Rate>1.2486</Rate><Date>2/10/2017</Date><Time>10:02pm</Time><Ask>1.2489</Ask><Bid>1.2486</Bid></rate></results></query><!-- total: 8 -->
<!-- prod_gq1_1;paas.yql;queryyahooapiscomproductiongq11;c2b8d2cb-ea59-11e6-912b-f0921c12e67c -->
2017-02-11T22:28:00.045 Function completed (Success, Id=54dfc25e-c99b-44e2-bfc0-3f3a92483911)
2017-02-11T22:28:15.005 Function started (Id=039d9230-a3ac-4f70-ba61-44a126b8d08d)
```

Looks like things are working. Code changes have been detected, the code is compiled, and starts running, pulling exchange rates from Yahoo. Success!

Let's use our `parse` function, to extract the rate as a number, and not a raw string:

``` fsharp
open System
open System.Net

let parse (s:string) = 
    let o = "<Rate>"
    let c = "</Rate>"
    
    let st = s.IndexOf(o) + 6
    let en = s.IndexOf(c) - st

    s.Substring(st,en)

let url = """http://query.yahooapis.com/v1/public/yql?q=select * from yahoo.finance.xchange where pair in ("GBPUSD")&env=store://datatables.org/alltableswithkeys"""

let Run(myTimer: TimerInfo, log: TraceWriter) =
    log.Info(
        sprintf "F# Timer trigger function executed at: %s" 
            (DateTime.Now.ToString()))

    let client = new WebClient()
    let result = 
        client.DownloadString(url)
        |> parse 
        |> float

    sprintf "%f" result            
    |> log.Info 
```

And... done.

Before going any further, let's click on the View Files button next to Logs: 

![View Files]({{ site.url }}/assets/2017-02-11-view-files.PNG)

What we have is a folder, named "retrieve-rate" (the name of our function), with 2 files: `run.fsx`, which we already looked at, and `function.json`. That file contains the bindings for our function:

``` json
{
  "bindings": [
    {
      "name": "myTimer",
      "type": "timerTrigger",
      "direction": "in",
      "schedule": "*/15 * * * * *"
    }
  ],
  "disabled": false
}
```

That's the minimum setup for a function: a script (F# or not), which contains the code to run, and a `function.json` file, which defines the **trigger**, an event which, when it happens, will cause the script code to be executed.

In the `function.json` file, we have a list of bindings, with, in our case, only one binding defined, of type `timerTrigger`, named `myTimer`, going `in` the function. This is where the `myTimer: TimerInfo` argument in the `Run` function comes in. When we initially setup the function, all we did was creating that file, which we could now edit directly here. If you change the schedule to `"schedule": "*/5 * * * * *"`, Save and Run, your function will now run every 5 seconds. If you change the name of the binding from `myTimer` to `timer`, Save and Run, you'll see an error pop in the logs:

```
2017-02-11T22:46:54.826 Function compilation error
2017-02-11T22:46:54.826 error AF003: Missing a trigger argument named 'timer'.
```

That's because the name of the argument in the `Run` function should match the trigger we defined. Modify `Run` to `let Run(timer: TimerInfo, log: TraceWriter) =`, and everything will be back in order.

## What next

That's where I will stop for today. So far, we have covered the setup and creation of a Function App via the Azure portal, and shown how easy it was to just take an existing F# script, and, with barely a modification, get it to run on a schedule.

This was just scratching the surface, and we still have work to do. Next time, we will expand our app to post to Slack. In the process, we will look more into bindings and triggers, and how to connect functions together. We'll also show how to use existing nuget packages, such as `FSharp.Data`, and how to make any file available to our functions. So... stay tuned for the next post!


[1]: https://azure.microsoft.com/en-us/services/functions/
[2]: https://twitter.com/chriskeenan/status/818910379795513345
[3]: https://api.slack.com/incoming-webhooks
[4]: http://fsharp.github.io/FSharp.Data/library/XmlProvider.html
[5]: https://portal.azure.com
[6]: https://en.wikipedia.org/wiki/Cron