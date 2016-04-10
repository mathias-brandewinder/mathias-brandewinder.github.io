---
layout: post
title: fsibot, now 100% more Enterprise!
tags:
- F#
- fsibot
- Twitter
- Azure
- Service-Bus
---

Let’s face it, [@fsibot](https://twitter.com/fsibot) in its initial release came with a couple ~~flaws~~ undocumented features. One aspect that was particularly annoying was the mild Tourette’s syndrom that affected the bot; on a fairly regular basis, it would pick up the same message, and send the same answer over and over again to the brave soul that tried to engage in a constructive discussion.

<!--more-->

Let’s face it, @fsibot in its initial release came with a couple flaws undocumented features. One aspect that was particularly annoying was the mild Tourette’s syndrom that affected the bot; on a fairly regular basis, it would pick up the same message, and send the same answer over and over again to the brave soul that tried to engage in a constructive discussion.

I wasn’t too happy about that (nobody likes spam), and, being all about the enterprise and stuff, I thought it was time to inject a couple more buzzwords. In this post, I’ll briefly discuss how I ended up using the Azure Service Bus to address the problem, with a sprinkle of Azure Storage for good measure, and ended up liking it quite a bit.

So what was the problem?

The issue came from a combination of factors. Fundamentally, [@fsibot](https://twitter.com/fsibot) is doing two things: pulling on a regular basis recent mentions from Twitter, and passing them to the F# Compiler Services to produce a message with the result of the evaluation.

Mentions are pulled via the Twitter API, which offers two options: grab the latest 20, or grab all mentions since a given message ID. If you have no persistent storage, this implies that when the service starts, you pull the 20 most recent ones, and once you have retrieved some messages, you can start pulling only from the last one seen.

This is a great strategy, if your service runs like a champ and never goes down (It’s also very easy to implement – a coincidence, surely). Things start to look much less appealing when the service goes down. In that scenario, the service reboots, and starts re-processing the 20 most recent mentions. In a scenario where, say, a couple of enthusiastic F# community members decide to thoroughly test the bots’ utter lack of security, and send messages that cause it to have fits and go down in flames multiple times in a short time span, this is becoming a real problem.

So what can we do to fix this?

A first obvious problem is that a failure in one part of the service should not bring down the entire house. Running unsafe code in the F# Compiler Service should not impact the retrieval of Twitter mentions. In order to decouple the problem, we can separate these into two separate services, and connect them via a queue. This is much better: if the compiler service fails, messages keep being read and pushed to the queue, and when it comes back on line, they can be processed as if nothing happened. At that point, the only reasons that will disrupt the retrieval of mentions is either a problem in that code specifically, or a reboot of the machine itself.

So how did I go about implementing that? The most lazy way possible, of course. In that case, I used the Azure Service Bus queue. I won’t go into all the details of using the Service Bus; [this tutorial does a pretty good job at covering the basic scenario](http://azure.microsoft.com/en-us/documentation/articles/service-bus-dotnet-how-to-use-queues/), from creating a queue to sending and receiving messages. I really liked how it ended up looking from F#, though. In the first service, which reads recent mentions from Twitter, [the code simply looks like this](https://github.com/mathias-brandewinder/fsibot/blob/0e1aaca40602cd0a75b0d4d9e60e26d2cab67a88/FsiBot/FsiBotHears/FsiBotHears.fs#L90-134):

``` fsharp
let queueMention (status:Status) =
    let msg = new BrokeredMessage ()
    msg.MessageId <- status.StatusID |> string
    msg.Properties.["StatusID"] <- status.StatusID
    msg.Properties.["Text"] <- status.Text
    msg.Properties.["Author"] <- status.User.ScreenNameResponse
    mentionsQueue.Send msg
```

From the `Status` (a LinqToTwitter class) I retrieve, I extract the 3 fields I care about, create a BrokeredMessage (the class used to communicate via the Azure Service Bus), add key-value pairs to  Properties and send it to the Queue.

On the processing side, [this is the code I got](https://github.com/mathias-brandewinder/fsibot/blob/0e1aaca40602cd0a75b0d4d9e60e26d2cab67a88/FsiBot/FsiBot/FsiBot.fs#L43-67):

``` fsharp
let (|Mention|_|) (msg:BrokeredMessage) =
    match msg with
    | null -> None
    | msg ->
        try
            let statusId = msg.Properties.["StatusID"] |> Convert.ToUInt64
            let text = msg.Properties.["Text"] |> string
            let user = msg.Properties.["Author"] |> string
            Some { StatusId = statusId; Body = text; User = user; }
        with 
        | _ -> None

let rec pullMentions( ) =
    let mention = mentionsQueue.Receive ()
    match mention with
    | Mention tweet -> 
        tweet.Body
        |> processMention
        |> composeResponse tweet
        |> respond
        mention.Complete ()
    | _ -> ignore ()

    Thread.Sleep pingInterval
    pullMentions ()
```
            
I declare a [partial Active Pattern](http://msdn.microsoft.com/en-us/library/dd233248.aspx#sectionToggle0) (the `(|Mention|_|)` “banana clip” bit), which allows me to use pattern matching against a BrokeredMessage, a class which by itself knows nothing about F# and discriminated unions. That piece of code itself is not beautiful (just it’s a try-catch block, trying to extract data from the BrokeredMessage into my own Record type), but the part I really like is the pullMentions () method: I can now directly grab messages from the queue, match against a Mention, and here we go, a nice and clean pipeline all the way through.

So now that the two services are decoupled, one has a fighting chance to survive when the other goes down. However, it is still possible for the Twitter reads to fail, too, and in that case we will still get mentions that get processed multiple times.

One obvious way to resolve this is to actually persist the last ID seen somewhere, so that when the Service starts, it can read that ID and restart from there. This is what I ended up doing, storing that ID in a blob (probably the smallest blob in all of Azure); the code to write and read that ID to a blob is pretty simple, and probably doesn’t warrant much comment:

``` fsharp
let updateLastID (ID:uint64) =
    let lastmention = container.GetBlockBlobReference blobName
    ID |> string |> lastmention.UploadText

let readLastID () =
    let lastmention = container.GetBlockBlobReference blobName
    if lastmention.Exists ()
    then 
        lastmention.DownloadText () 
        |> System.Convert.ToUInt64
        |> Some
    else None
```
            
However, even before doing this, I went an even lazier road. One of the niceties about using the Service Bus is that the queue behavior is configurable in multiple ways. One of the properties available (thanks [@petarvucetin](https://twitter.com/petarvucetin) for pointing it out!) is Duplicate Detection. As the name cleverly suggests, it allows you to specify a time window during which the Queue will detect and discard duplicate BrokeredMessages, a duplicate being defined as “a message with the same MessageID”.

So I simply set a window of 24 hours for Duplicate Detection, and the BrokeredMessage.MessageID equal to the Tweet Status ID. If the Queue sees a message, and the same message shows up withing 24 hours, no repeat processing. Nice!

Why did I add the blob then, you might ask? Well, the Duplicate Detection only takes care of most problem cases, but not all of them. Imagine that a Mention comes in, then less than 20 mentions arrive for 24 hours, and then the service crashes – in that case, the message WILL get re-processed, because the Duplicate Detection window has expired. I could have increased that to more than a day, but it already smelled like a rather hacky way to solve the problem, so I just added the blob, and called it a day.

So what’s the point here? Nothing earth shattering, really – I just wanted to share my experience using some of the options Azure offers, in the context of solving simple but real problems on [@fsibot](https://twitter.com/fsibot). What I got out of it is two things. First, Azure Service Bus and Azure Storage were way easier to use than what I expected. Reading the tutorials took me about half an hour, implementing the code took another half an hour, and it just worked. Then (and I will readily acknowledge some F# bias here), my feel is that Azure and F# just play very nicely together. In that particular case, I find that Active Patterns provide a very clean way to parse out BrokeredMessages, and extract out code which can then simply be plugged in the code with a Pattern Match, and, when combined with classic pipelines, ends up creating very readable workflows.
