---
layout: post
title: Create a basic Discord bot in F#
tags:
- F#
- Discord
- Bot
---

I have been using Discord a lot lately, mainly because I needed a space to meet for role-playing games remotely during the Black Plague. One nice perk of Discord is its support for bots. In particular, I used a bot called Groovy, which allowed streaming music from various sources like YouTube during games, and was great to set the tone for epic moments in a campaign. Unfortunately, Groovy wasn't complying with the YouTube terms of service, and fell to the ban hammer. No more epic music for my epic D&D encounters :(

As the proverb goes, "necessity is the mother of invention". If there is no bot I can readily use, how difficult could it be to create my own replacement, in F#?

In this post, I will go over the basics of creating a Discord bot in F#, using the [DSharpPlus library][1]. Later on, I will follow up with a post focusing on streaming music.

The bot we will write here will be pretty basic: we will add a fancier version of hello world, with a command `inspire` that we can trigger from Discord:

`/inspire @bruenor`

.. which will cast [Bardic Inspiration][2] on @bruenor, a user on our server, responding with a message

`Bardic Inspiration! @bruenor, add 3 (1d6) to your next ability check, attack, or saving throw.`

<!--more-->

## Prerequisites / Setup

For us to use a bot in Discord, we will need 2 things:

- a Discord server where you have enough admin privileges to add the bot (you can create your own server for free),
- an App registered in Discord (our bot), so we can get a token to connect our code to Discord, and a link to add the bot to our server.

To create the app, go to the [Discord developers page][3], where you can create an Application. Once that application is created, go to the Bot section. In there you will find a link to a **Token**, which will be used to authenticate our code later on.

To add your bot to a server, in the Discord developers page, go to the **OAuth2** section, and go to the **OAuth2 URL Generator** section. In the section labeled **Scopes**, select **bot**. You should see a url like this one appear:

`https://discord.com/api/oauth2/authorize?client_id=YOUR_APP_CLIENT_ID&permissions=0&scope=bot`

Note the argument `permissions=0`. To give your bot permission to perform some actions, select below the **bot permissions** you want, in our case, `Sent Messages`, which will convert the url to

`https://discord.com/api/oauth2/authorize?client_id=YOUR_APP_CLIENT_ID&permissions=2048&scope=bot`

Once that is done, copy that url in your browser, which will ask you to select the server(s) where you would like this bot to be added.

At that point, we are set: we have all the hooks we need, all that is missing is code for our bot to do something.

## Setting up our Bot

Our bot will be a basic console app. Let's get that wired up. In VS Code, we'll create that console app:

`dotnet new console --language F# --name BardicInspiration`

To avoid hard-coding our bot token in code, let's put it in an `AppSettings.json` file, adding the nuget packages `Microsoft.Extensions.Hosting`, `Microsoft.Extensions.Configuration` and `Microsoft.Extensions.Configuration.Json` to our project, and making sure that `AppSettings.json` is copied during build and publish in the `BardicInspiration.fsproj` file.

Code: [Initial console app setup][4]

Now that we have a token, let's connect to Discord, using `DSharpPlus`. We'll add 2 more packages, `DSharpPlus` and `DSharpPlus.CommandsNext`, and modify our program to create a Discord client, using our bot token:

``` fsharp
[<EntryPoint>]
let main argv =
    printfn "Starting"

    let token = appConfig.["Token"]
    let config = DiscordConfiguration ()
    config.Token <- token
    config.TokenType <- TokenType.Bot

    let client = new DiscordClient(config)

    1
```

Code: [Creating a Discord client][5]

## Wiring up our first Command

We are now ready to add a command. Commands in DSharpPlus use the `DSharpPlus.CommandsNext` package, and must be hosted in a class that inherits from `BaseCommandModule`. Let's create a separate file for our bot commands, `DiscordBot.fs`, and create our bot:

``` fsharp
open DSharpPlus.CommandsNext

type BardBot () =

    inherit BaseCommandModule ()
```

Let's add our first command. Commands are methods or functions, decorated with attributes. Following along the [C# docs for DSharpPlus][6], translating into F#, I got my first command working:

``` fsharp
[<Command>]
let inspiration (ctx: CommandContext) =
    async {
        do!
            ctx.TriggerTypingAsync()
            |> Async.AwaitTask

        let rng = Random ()
        let emoji =
            DiscordEmoji.FromName(ctx.Client, ":game_die:").ToString()

        do!
            rng.Next(1, 7)
            |> sprintf "%s Bardic Inspiration! Add %i to your next ability check, attack, or saving throw." emoji
            |> ctx.RespondAsync
            |> Async.AwaitTask
            |> Async.Ignore
        }
    |> Async.StartAsTask
    :> Task
```

We'll revisit that later, to see if we can make things a bit simpler. At a high level, a command is decorated with the `[<Command>]` attribute, takes in a `CommandContext`, which provides contextual information (which server or channel is it coming from, which user sent the command...) and possibly arguments, and returns a `Task`.

Now that our `inspiration` command is ready, let's bolt that to our bot, in `Program.fs`:

``` fsharp
let client = new DiscordClient(config)

let commandsConfig = CommandsNextConfiguration ()
commandsConfig.StringPrefixes <- ["/"]

let commands = client.UseCommandsNext(commandsConfig)
commands.RegisterCommands<BardBot>()

client.ConnectAsync()
|> Async.AwaitTask
|> Async.RunSynchronously

Task.Delay(-1)
|> Async.AwaitTask
|> Async.RunSynchronously
```

We set the prefix of commands to `/`, so we can invoke them like `/inspiration`, and register our `BardBot` with the client - and we start the whole thing up, connecting our client to Discord.

Code: [First Command][7]

At that point, if you build and run the program, and added the bot to your server, it should work:

![Bardic inspiration in action]({{ site.url }}/assets/2021-10-30-bardic-inspiration.png)

## Puttings some bells and whistles on that Command

At that point, we have a working Command, which is great. However, we also have some small issues.

First, while using a function works perfectly fine, it will prevent us from using command overloads, if that is something we wanted to support. So I rewrote the command, making a few changes:

``` fsharp
[<Command "inspire">]
[<Description "Cast bardic inspiration">]
member this.Inspiration (ctx: CommandContext) =
```

With that change, we could now support an alternate version, where we can cast Bardic Inspiration on a specific user, like this:

``` fsharp
[<Command "inspire">]
[<Description "Cast bardic inspiration on someone!">]
member this.Inspiration (ctx: CommandContext, [<Description "Who do you want to inspire?">] user: DiscordMember) =
```

I added a few more attributes, which illustrate some interesting points:

- `[<Command "inspire">]` explicitly defines how the command will be named in Discord, instead of relying on the function or method name,
- `[<Description "Cast bardic inspiration on someone!">]` provides help in Discord about the command itself,
- `[<Description "Who do you want to inspire?">]` provides help around the argument `user`.

... which can then be used in Discord like so:

![Bardic inspiration in action]({{ site.url }}/assets/2021-10-30-command-help.png)

Note also in the method signature how `user` is a `DiscordMember`. `DSharpPlus` will use that information to try and parse the argument into a user for use.

## From Async to Task

The other small issue is the friction between `async` and `Task`. [F# 6 includes native support for task][8], which would be perfect here, but at the time of writing, .NET 6 is still in release candidate, so I decided to use `Ply` instead for now. After adding the `Ply` package, we can now rewrite our method like so:

``` fsharp
[<Command "inspire">]
[<Description "Cast bardic inspiration on someone!">]
member this.Inspiration (ctx: CommandContext, [<Description "Who do you want to inspire?">] user: DiscordMember) =
    unitTask {
        do!
            ctx.TriggerTypingAsync()

        let emoji = DiscordEmoji.FromName(ctx.Client, ":drum:").Name
        let roll = Random().Next(1, 7)
        let userName = user.Mention

        let! _ =
            sprintf "%s Bardic Inspiration! %s, add %i (1d6) to your next ability check, attack, or saving throw." emoji userName roll
            |> ctx.RespondAsync

        return ()
        }
```

And we are done! We have a fully functioning Discord Bot, with a command:

![Bardic inspiration in action]({{ site.url }}/assets/2021-10-30-bardic-inspiration-done.png)

Code: [Final State of Affairs][9]

## Conclusion

Well, that's it for today! If you are interested in writing Discord bots, hope this blog post helps you get started on the right foot. In the next installment, I plan on going over how to add music streaming to that bot. In the meanwhile, [ping me on twitter](https://twitter.com/brandewinder) if you have have questions or comments, and... happy coding!


[1]: https://dsharpplus.github.io/
[2]: https://roll20.net/compendium/dnd5e/Bard#toc_4
[3]: https://discord.com/developers/applications
[4]: https://github.com/mathias-brandewinder/Bardic-Inspiration/tree/a1a6ecff23d612027a7a3e1583d663a38a1da871/BardicInspiration
[5]: https://github.com/mathias-brandewinder/Bardic-Inspiration/tree/d249555d85e4a4ecccf628b2ac3ef887447950b8/BardicInspiration
[6]: https://dsharpplus.github.io/articles/preamble.html
[7]: https://github.com/mathias-brandewinder/Bardic-Inspiration/tree/59d7ac2a432f853a5085b9067c2fc954281470ee/BardicInspiration
[8]: https://docs.microsoft.com/en-us/dotnet/fsharp/whats-new/fsharp-6#task-
[9]: https://github.com/mathias-brandewinder/Bardic-Inspiration/tree/9e2ccb098848d97d28917fa551d6603894f387f3/BardicInspiration