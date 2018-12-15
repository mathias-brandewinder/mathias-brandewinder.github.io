---
layout: post
title: Give me Monsters! (Part 8)
tags:
- F#
- DnD
- Domain-Modeling
- Fable
---

In the [previous installment of this series][1], we ended up with a primitive model for turn-based battles in Dungeons & Dragons, covering some of the rules related to movement. The model we came up with represents actions taken by creatures as commands, which we use to update the state of the world. One nice thing about this model is how easy it is to test it out, in the scripting environment or otherwise. However, it would be nice to observe what is going on visually. This will be our goal for today: take our existing domain model, and plug that into [Fable Elmish][2] to visualize our rules in action.

_Warning: I claim zero expertise in Fable, Elmish or not. For that matter, I would rate my skills in web stuff as "inexistent". All this to say that the Fable related code is likely going to have some flaws - would love to hear from people who actually know what they are doing, how I could do better ;)_

<!--more-->

## Rules

Before diving into Fable, let's do a bit of cleanup. You might have noticed an Arrow of Doom starting to take place in our `update` function, with increasingly deeply nested `if/then/else` statements, each of them checking whether a particular rule is satisfied by the command that was just passed.

That `update` function is already over 70 lines long, and it's only going to get worse as we add more rules. Furthermore, what the code is doing is becoming less and less clear. We don't like doom, at least not in our code base - let's simplify this.

One way to look at the issue is, we are mixing together two things: we check in the function whether certain conditions are met, and if they are, we apply the command to update the state of the world. If something fails, we throw an exception.

Let's take a different angle, and separate the process in 2 phases: first, validate the command, by checking if it passes all the rule checks, and then, update the model. And, while we are at it, let's remove these ugly exception.

To achieve this, we will explicitly represent each `Rule`, and validate whether or not a command satisfies that rule, returning a `Result` type, which will be either `Ok(command)` if it is valid, and `Error(message)` otherwise.

So let's do this. The first rule we have embedded in our `update` function is the following:

``` fsharp
let update (creatureID: CreatureID, cmd: Command) (world: World) = 
    if world.Active <> creatureID
    then 
        sprintf "Error: it is not %A's turn." creatureID
        |> failwith    
    else
```

... which simply states that a creature must be active to act, otherwise it is not its turn. Let's model `Rule`(s) as an interface, and use an [`Object Expression`][3] to create an instance implementing that particular rule:

``` fsharp
module Rules = 

    type Rule = 
        abstract member Validate: 
            World -> CreatureID * Command -> Result<CreatureID * Command, string>

    let ``A creature must be active to act`` =
        { new Rule with
            member this.Validate world (creatureID, command) =
                if world.Active <> creatureID
                then 
                    sprintf "%A / %A failed: %s" command creatureID "it is not the creature's turn"
                    |> Error
                else Ok (creatureID, command)
        }
```

> Note: I could also have modeled rules as straight functions `type Rule =  World -> CreatureID * Command -> Result<CreatureID * Command, string>`, instead of going for an interface, which is not really buying us much here. I am not sure why I went that route, perhaps I'll change the code later to just use functions.

At that point, we can simply use that rule, and check if a command emitted by a creature is valid, given the current state of the world:

``` fsharp
open Rules
``A creature must be active to act``.Validate world (CreatureID 1, Move N)
// Ok (CreatureID 1, Move N)
``A creature must be active to act``.Validate world (CreatureID 2, Move N)
// Error "Move N / CreatureID 2 failed: it is not the creature's turn"
```

Implementing the 3 other embedded rules following the same pattern is straightforward - we end up with a list of 4 rules:

``` fsharp
let rules = [
    ``A creature must be active to act``
    ``A creature cannot move if it has not enough movement left``
    ``A creature cannot move to a space occupied by another creature``
    ``A creature can take at most one action per turn``
    ]
```

So how is this useful? We can now chain them ala [Railway Oriented Programming][4], using `Result.bind`:

``` fsharp
Ok (CreatureID 1, Move N)
|> Result.bind (``A creature must be active to act``.Validate world)
|> Result.bind (``A creature cannot move if it has not enough movement left``.Validate world)
// etc...
```

Starting from the assumption that the command is `Ok`, we pass it through every rule for validation, and will either get back our command, validated, or an `Error` message describing the first failing rule that was encountered.

This is still not particularly pretty. However, with a bit of machinery, we can wrap all that up in a single function, taking the full list of rules we have implemented, and checking if all of them pass by applying a `fold`:

``` fsharp
let validate world (creatureID, command) =
    (Ok (creatureID, command), rules)
    ||> Seq.fold (fun state rule -> 
        state
        |> Result.bind (rule.Validate world)
        )
```

With that out of the way, all we have to do now is progressively add rules as we implement them, include them in the rule list, and we are done: validation will be taken care of. We can also nicely [clean up the `update` function][5], removing all the checks and simply executing the command, which is assumed to have been validated beforehand.

## Plugging the Domain into Fable Elmish

Let me start by re-iterating again that I am a total Fable beginner; so please, don't take any of the following as 'best practices', and if you have comments/suggestions on how to improve things... I would love to hear them!

With that out of the way, let's get cranking. The [minimal Fable2 sample][6] is, as its name suggest, a minimal Fable app, nicely documented and ready to go, so I lazily copied over the whole thing in its own folder in the project, to use as a starting point.

If you dig into that sample, you will see that an Elmish application boils down to 2 parts:

- a `Model` that represents the state of your application, and `Messages` that represent what actions can change that state,
- 3 functions, `init`, `update` and `view`, which respectively initialize the `Model`, update the `Model` in reaction to a `Message` received, and render the `Model` on screen.

This sounds like a pretty natural fit with our domain. We already have the `Model` and `Message` parts (our `World` and `CreatureID * Command` types), all we need then is to write out the 3 functions `init`, `update` and `view`.

First, we have a nice domain model, completely agnostic of any UI concerns, and we would like to keep it that way. To do that, we will simply add a file, `Domain.fs`, to the Fable solution, copy all of our current script into it, and wrap it in a module, `Domain`. And, because our application has now multiple files, we will give both `Domain.fs` and `App.fs` a namespace, `MonsterVault`.

Time to plug things in. Where the original Elmish application defined `Model` and `Msg` as

``` fsharp
type Model = int
type Msg = 
    | Increment 
    | Decrement
```

... we simply swap it out for our domain:

``` fsharp
open MonsterVault.Domain

type Model = World
type Msg = CreatureID * Command
```

For the time being, we will keep using the "test" world we used in our script, populated with 2 test creatures:

``` fsharp
let init () = world
```

The `update` function is equally easy to write. We need a function that, given a state of the `World` and a `CreatureID * Command`, gives us back the state of the world after the command has been applied. One question here is, what should we do for invalid commands? For the time being, we will do the simplest thing we can: when a command fails, we will just return the world as it was before. The drawback here is that we won't have any notification of what caused the command to fail, but it will be good enough for now:

``` fsharp
let update (creatureID, command) world =
    match Rules.validate world (creatureID, command) with
    | Error(msg) ->
        // the command fails: ignore it and keep the world as it was
        world  
    | Ok(creatureID, command) -> 
        update world (creatureID, command)    
```

Almost there! Our final step will be to render the state of the world, and provide a mechanism for a user to send commands. Let's do that:

``` fsharp
let view (model: Model) dispatch =

    let sendCommand cmd =
        (model.Active, cmd)
        |> dispatch

    div []
        [ 
            div [] [ str (string model) ]

            div [] [ str "Movement" ]

            button [ OnClick (fun _ -> sendCommand (Move N)) ] [ str "N" ]
            button [ OnClick (fun _ -> sendCommand (Move NW)) ] [ str "NW" ]
            button [ OnClick (fun _ -> sendCommand (Move W)) ] [ str "W" ]
            button [ OnClick (fun _ -> sendCommand (Move SW)) ] [ str "SW" ]
            button [ OnClick (fun _ -> sendCommand (Move S)) ] [ str "S" ]
            button [ OnClick (fun _ -> sendCommand (Move SE)) ] [ str "SE" ]
            button [ OnClick (fun _ -> sendCommand (Move E)) ] [ str "E" ]
            button [ OnClick (fun _ -> sendCommand (Move NE)) ] [ str "NE" ]

            div [] [ str "Actions" ]

            button [ OnClick (fun _ -> sendCommand (Action Dash)) ] [ str "Dash" ]

            div [] [ str "Other" ]

            button [ OnClick (fun _ -> sendCommand (Done)) ] [ str "Done" ]
        ]
```

We render the `Model` as a raw string, and add one button for each of the commands we support. And... that's it. `npm install`, `npm start`, and we have an application running in the browser:

![Initial version of Fable app]({{ site.url }}/assets/2018-12-15-fable-v0.gif)

This is not pretty, but... it works, and it gives us what we need, essentially a primitive debugger. We can now try out our model, and verify that the state is what we expect it to be when we execute commands.

## Making Things Less Ugly 

Before closing this episode, let's see if we can make things a bit less ugly. We will make a couple of changes. First, combat takes place on a battle grid - it would be nice to see how things look. Then, it would also be convenient to see the result of a command; in particular, in cases where it fails, getting some feedback on what went wrong would be useful.

I won't go into a step-by-step explanation of the changes, and will just outline the main modifications - [the code, which you can find here, is relatively self-explanatory][7].

The first change was to modify a bit our `Model` type, to include both the `World` and a `Journal`, a list of the most recent events that occurred:

``` fsharp
type Model = {
    World: World
    Journal: string list
    }
```

Whenever we update the model, we will now append what happened - either the command, if it succeeded, or the error message otherwise, to the `Journal`, and keep the 5 most recent ones:

``` fsharp
let update (msg: Msg) (model: Model) =
    match Rules.validate (model.World) msg with
    | Error(error) -> 
        { model with 
            Journal = 
                error :: model.Journal 
                |> List.truncate 5
        }
    | Ok (creatureID, command) -> 
        let world = update model.World (creatureID, command)
        { model with
            World = world
            Journal = 
                (sprintf "%A: %A" creatureID command) :: model.Journal
                |> List.truncate 5
        }
```

The second series of changes pertains to rendering the battle map. If we want to display that map on a grid, we need to know its size. For that matter, as we expand our model, we will also need to carry information about the terrain itself, such as walls, obstacles, trees, and whatnot. Easy enough, we just add a `BattleMap` field to the `World` itself, which we will later on flesh out as needed:

``` fsharp
type BattleMap = {
    Width: int
    Height: int
    }

type World = {
    BattleMap: BattleMap
    // rest unchanged
    }
```

Rendering the map can then be done using SVG, representing each tile on the battle grid as 15 px square, using different colors to mark empty tiles, the active creature, and other creatures:

``` fsharp
let tileSize = 15

let tileAt (model:Model) (x,y) color =
    let map = model.World.BattleMap
    let width = map.Width
    let height = map.Height
    rect [ 
        SVGAttr.X (tileSize * (width - x - 1))
        SVGAttr.Y (tileSize * (height - y - 1))
        SVGAttr.Width (tileSize - 2)
        SVGAttr.Height (tileSize - 2)
        SVGAttr.Rx 2
        SVGAttr.Ry 2
        SVGAttr.Fill color 
        ] [ ]

let battleMap (model:Model) dispatch =

    let map = model.World.BattleMap
    let width = map.Width
    let height = map.Height

    svg [                    
            SVGAttr.Width (width * tileSize)
            SVGAttr.Height (height * tileSize)
        ]
        [
            let map = model.World.BattleMap
            for x in 0 .. (map.Width - 1) do
                for y in 0 .. (map.Height - 1) do
                    yield tileAt model (x,y) "LightGray"

            for creature in model.World.Creatures do
                let state = creature.Value
                let color = 
                    if creature.Key = model.World.Active
                    then "Red"
                    else "Orange"
                yield tileAt model (state.Position.West, state.Position.North) color
        ]
```

And that's pretty much it. After a bit of additional cleanup and screen re-organization, we end up with something that, while still very crude, is beginning to look like something: 

![Battle map version of Fable app]({{ site.url }}/assets/2018-12-15-fable-v1.gif)

## What Next?

That's where we will stop for today! This post was less focused on the D&D rules than the previous ones in the series, and more on setting ourselves up so we can easily implement more rules and see how they play out.

For me, the highlight of that experience was discovering Fable-Elmish. I suspect my code isn't all that great (feedback and suggestions welcome!), and that's OK. The larger point here is that I managed to take my domain as-is and pretty much plug it right in, without having to change anything. It took about 15 minutes, and it just worked. For somebody like me who doesn't work with web applications at all, it was borderline shocking how easy the whole process was. Big thanks to the Fable community, it is beautiful work, and a pleasure to work with so far! 

Now that we have that in place, where next?

I could dive more into movement and terrain, and things like visibility and line of sight. It is a fun topic in its own right, but I think I will leave that on the backburner for now. Instead, I think my focus will be on two aspects: modeling creature attacks, and automated play. 

Observing creatures moving around a map is not all that exiting. Adding attacks will spice things up a bit, and give us a chance to revisit and incorporate into our domain some of the material we covered in earlier posts. 

As for automated play, one of my end goals here is to see if I can set up and run simulated battles, to evaluate how balanced a particular encounter is, and perhaps even have creatures learn what strategy they should follow. As a first step towards that lofty end goal, I think I need to change the design a bit, and introduce something like a `WorldView`, representing what information each creature has available at a given time, and a list of the actions they can perform. With that in place, we should then be able to treat each creature as an agent, deciding based on the information it has available what to do, by following a certain strategy/policy.

Anyways, this will be it for today, hope you find something interesting (or maybe even useful...) in this post! In the meanwhile, as always, you can find the [current state of the code here on GitHub][8] - let me know if you have comments or questions :)

[1]: {{ site.url }}/2018/12/03/give-me-monsters-part-7/  
[2]: https://elmish.github.io/elmish/
[3]: https://docs.microsoft.com/en-us/dotnet/fsharp/language-reference/interfaces#implementing-interfaces-by-using-object-expressions
[4]: https://fsharpforfunandprofit.com/rop/
[5]: https://github.com/mathias-brandewinder/MonsterVault/blob/85b069957977a448d05421bb643b9956bc04ae46/combat.fsx#L115-L251
[6]: https://github.com/fable-compiler/fable2-samples
[7]: https://github.com/mathias-brandewinder/MonsterVault/tree/615af0bc478d0276bbe82cbf798036f6f506c011/fable/app/src
[8]: https://github.com/mathias-brandewinder/MonsterVault/tree/615af0bc478d0276bbe82cbf798036f6f506c011
