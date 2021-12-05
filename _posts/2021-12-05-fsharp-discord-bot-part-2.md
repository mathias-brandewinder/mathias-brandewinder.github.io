---
layout: post
title: Playing Audio with an F# Discord bot
tags:
- F#
- Discord
- Bot
---

This post is a follow up to [that one][1]. As mentioned earlier, my overarching goal is to build a Discord bot to help play "atmosphere" soundtracks during D&D games. Last time, we went over creating a simple Discord bot in F# to support basic text commands. This time, we'll add sound.

## How it works overall

Our application builds on what we did last time. We will use [DSharpPlus][2] to create a console application that exposes commands we can trigger from a Discord server. The part we need to add is a way to stream sound to Discord. To do that, we will use [Lavalink][3], a java program that supports searching and streaming audio sources. The NuGet package `DSharpPlus.Lavalink` handles integration with Lavalink already, so most of the work is done for us already, all we have to do is bolt the parts together. Rather than repeating the DSharpPlus docs, I will highlight the parts where I had some issues.

To run the complete solution locally, you will need to:

- Run `Lavalink` on your machine,
- Run `BardicInspiration` on your machine: it will connect to Lavalink, and respond to Discord commands, searching audio tracks via Lavalink and streaming them to your Discord server.

<!--more-->

## Connecting to Lavalink

That part is fairly straightforward. We add the package `DSharpPlus.Lavalink` to our project, and made the following changes in `Program.fs`: add 2 new references:

``` fsharp
open DSharpPlus.Net
open DSharpPlus.Lavalink
```

... and, after we connect our client to Discord, connect to our local Lavalink server:

``` fsharp
printfn "Connecting to Discord"
discord.ConnectAsync()
|> Async.AwaitTask
|> Async.RunSynchronously

printfn "Connecting to Lavalink"
let hostname = "127.0.0.1"
let port = 2333
let password = "youshallnotpass"

let lavalinkEndpoint = ConnectionEndpoint(hostname, port)
let lavalinkConfig = LavalinkConfiguration ()
lavalinkConfig.Password <- password
lavalinkConfig.RestEndpoint <- lavalinkEndpoint
lavalinkConfig.SocketEndpoint <- lavalinkEndpoint

let lavalink = discord.UseLavalink()

let lavalinkConnection =
    lavalink.ConnectAsync lavalinkConfig
    |> Async.AwaitTask
    |> Async.RunSynchronously
```

The hostname, port and password should match the values you used in the `application.yml` file that configures your Lavalink server instance.

In the [final code version][4], I extracted all that in the `AppSettings.json` file, like this:

```
{
    "Token":"your discord token",
    "Lavalink": {
        "Hostname": "127.0.0.1",
        "Port": 2333,
        "Password": "youshallnotpass"
    }
}
```

## Searching for Audio and Streaming to a Voice Channel

That part is also fairly straightforward. For our bot to stream audio, it needs to join a voice channel on our server. We'll add a command to `DiscordBot.fs`, `/join`, that does just that:

``` fsharp
[<Command "join">]
[<Description "Join the General voice channel">]
member this.Join (ctx: CommandContext) =
    unitTask {
        // find General voice channel
        let channelID, channel =
            ctx.Guild.Channels
            |> Seq.find (fun kv ->
                kv.Value.Type = ChannelType.Voice
                &&
                kv.Value.Name.ToLowerInvariant () = "general"
                )
            |> fun kv -> kv.Key, kv.Value
        let lavalink = ctx.Client.GetLavalink ()
        let node = lavalink.ConnectedNodes.Values |> Seq.head
        let! connection = node.ConnectAsync(channel)
        return ()
        }
```

From the current `CommandContext`, we go through the existing Channels for the Guild (the server where the command originated from), and grab the first one that is a Voice channel, and named General, and we establish a Lavalink connection. I ran into weird issues there. By default, a Discord server has a Voice Channel named `General`, but for some reason, I never managed to find a channel with such a name. Using `general` instead appears to work. Why? No idea.

> Note: you will also need to give your bot permission to use audio, and not just messages. See the [OAuth2 URL Generator](https://brandewinder.com/2021/10/30/fsharp-discord-bot/#prerequisites--setup) section in our previous post.

At that point, typing `/join` in your server will add Bardic Inspiration to the General Voice Channel. Let's add a command to play some music next:

``` fsharp
[<Command "play">]
[<Description "Search and play the requested track">]
member this.Play (ctx: CommandContext, [<RemainingText>] search: string) =
    unitTask {
        let lavalink = ctx.Client.GetLavalink ()
        let node =
            lavalink.ConnectedNodes
            |> Seq.find (fun node ->
                node.Value.ConnectedGuilds.ContainsKey(ctx.Guild.Id)
                )
            |> fun kv -> kv.Value
        let connection = node.GetGuildConnection(ctx.Guild)
        let! loadResult = node.Rest.GetTracksAsync(search)
        let track = loadResult.Tracks |> Seq.head
        do! connection.PlayAsync(track)
        }
```

The `search` argument is a search string for what you want to play. Lavalink works against a variety of sources, which you can configure in `application.yml` (YouTube, SoundCloud, ...). The command is now be ready to go, like so: `/play https://youtu.be/dQw4w9WgXcQ`.

## Looping tracks

At that point, we have the basics in place. However, this isn't exactly what I need. When I am on Game Master duty for a Role Playing game, what I typically want is to start an atmosphere audio track (crowded inn, ominous dungeon, epic battle music...), and keep that on repeat until the adventure moves to a different atmosphere.

The change I want is along these lines: `/play track1` should start track1, and keep playing it every time the track finishes, unless I type `/play track2`, which should stop track1 and start looping track2.

Getting that to work took a bit of effort. The good news is, `DSharpPlus.Lavalink` exposes events like [`PlaybackFinished`][5], which triggers when a track finishes, and the `EventArgs` carry an enum describing the reason, [`TrackEndReason`][6] (the track finished because it played to the end, because another track was started, because it was stopped...).

This is exactly what we need: we want to subscribe to that event, and:
- If the track `Finished` uninterrupted, play it again,
- Otherwise do nothing.

The less good news is, the event itself is not standard. As I naively tried to add a handler to `connection.PlaybackFinished`, I was greeted with an interesting error:

```
The event 'PlaybackFinished' has a non-standard type. If this event is declared in another CLI language, you may need to access this event using the explicit add_PlaybackFinished and remove_PlaybackFinished methods for the event. If this event is declared in F#, make the type of the event an instantiation of either 'IDelegateEvent<_>' or 'IEvent<_,_>'.
```

OK then. Let's try to get that to work, and use `add_PlaybackFinished`. What does that one expect? Let's check its signature:

``` fsharp
member add_PlaybackFinished:
   value: AsyncEventHandler<LavalinkGuildConnection,TrackFinishEventArgs>
       -> unit
```

One step closer, the only unclear piece is `AsyncEventHandler`. Where is that coming from and what does it want? After some more digging, `AsyncEventHandler` appears to be defined in `Emzi0767.Utilities`, and is defined as:

``` fsharp
type AsyncEventHandler<'TSender,'TArgs (requires :> AsyncEventArgs)> =
   delegate of
      sender: 'TSender *
      e     : 'TArgs (requires :> AsyncEventArgs )
           -> Task
```

Let's implement a handler that matches the signature:

``` fsharp
member this.OnTrackFinished =
    AsyncEventHandler<LavalinkGuildConnection, EventArgs.TrackFinishEventArgs>(
        fun (conn: LavalinkGuildConnection) (args: EventArgs.TrackFinishEventArgs) ->
            unitTask {
                printfn $"Finished track {args.Track.Title} ({args.Reason})."
                match args.Reason with
                | EventArgs.TrackEndReason.Finished ->
                    printfn $"Looping: restarting track {args.Track.Title}."
                    do! args.Player.PlayAsync(args.Track)
                | _ -> ignore ()
                }
        )
```

And we can now refine our `/play` command like this:

``` fsharp
[<Command "join">]
[<Description "Join the General voice channel">]
member this.Join (ctx: CommandContext) =
    unitTask {
        // find General voice channel
        let channelID, channel =
            ctx.Guild.Channels
            |> Seq.find (fun kv ->
                kv.Value.Type = ChannelType.Voice
                &&
                kv.Value.Name.ToLowerInvariant () = "general"
                )
            |> fun kv -> kv.Key, kv.Value

        let lavalink = ctx.Client.GetLavalink ()
        let node = lavalink.ConnectedNodes.Values |> Seq.head

        let! connection = node.ConnectAsync(channel)

        connection.add_PlaybackFinished(this.OnTrackFinished)
        connection.add_PlaybackStarted(this.OnTrackStarted)
        }
```

... and we are done. Is this pretty? No. Is there a way to do this more cleanly? Probably. Do I care? Not really - it works, let's move on :)

## Conclusion

That's where we will stop for today. I added a few commands to the bot (`stop`, `pause`, and `resume` the current track, and `leave` the server), which follow the same patterns. I am sure some details could be cleaned up, but this is good enough for my purposes: I have a Discord bot that I can run on my machine to switch between audio loops during D&D games.

[Completed code on GitHub][4]

If you need a replacement for the Groovy bot (which is why I got started with this project in the first place), building and running the code locally with your own token should be relatively straightforward. Got questions or comments? [ping me on twitter](https://twitter.com/brandewinder), and in the meanwhile... happy coding!

[1]: https://brandewinder.com/2021/10/30/fsharp-discord-bot/
[2]: https://dsharpplus.github.io/
[3]: https://dsharpplus.github.io/articles/audio/lavalink/setup.html
[4]: https://github.com/mathias-brandewinder/Bardic-Inspiration/tree/3f9485c3c92f641d7fdd1e9d548ab4a13e0a739b
[5]: https://dsharpplus.github.io/api/DSharpPlus.Lavalink.LavalinkNodeConnection.html
[6]: https://dsharpplus.github.io/api/DSharpPlus.Lavalink.EventArgs.html
