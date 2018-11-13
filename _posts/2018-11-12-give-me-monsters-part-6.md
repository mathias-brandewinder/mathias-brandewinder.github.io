---
layout: post
title: Give me Monsters! (Part 6)
tags:
- F#
- DnD
- Domain-Modeling
---

It's been a while since I posted any update in this series, but we are back! Besides life and work getting in the way, I also needed to give some thought on where I wanted to take this next. We have a reasonable draft model to represent Monsters at that point, but I feel it's time to take a slightly different direction. 

The driving question behind this whole project was, how can we check if an encounter between Adventurers and Monsters is balanced? To do this, I think the easiest approach is to simulate encounters. Put together some Monsters and Adventurers, let them fight it out, repeatedly, and see what happens.

This requires two distinct pieces: 

- an engine responsible for enforcing the rules, to determine what actions a creatures can take, and resolve what the results are,  
- some form of AI, to make reasonable decisions for the creatures, so we can simulate how an encounter might unfold.

The engine modeling the game itself is a prerequisite to build the AI system, so that is what we will start with. Once we have that piece in place, we should be able to deal with the AI part, and hopefully refactor the code we wrote so far to plug it in.

<!--more-->

## The Rules of Engagement

First, what are we trying to model here, exactly?

A typical Dungeons & Dragons game alternates between 2 fairly different "modes": **Combat**, and what I will call free-form role playing. During free-form playing, the general rules apply, but they take a back seat to story telling. By contrast, when an encounter turns into **Combat**, [the rules become fairly rigid, akin to a wargame][1]. The flow is broken down in **Rounds**, and follows **Initiative Order**: each protagonist gets a **Turn**, representing 6 seconds of real time, during which they can take a limited set of actions, typically combining some **Move**, and some combat-related action(s).

Our focus here will be to model **Combat**.

We briefly touched on the topic [in our previous post][2]; let's revisit it a bit, to set the frame. During **Combat**, we have 2 groups of creatures (at least), Monsters and Adventurers. When **Combat** begins, each of them gets assigned a position in **Initiative Order**, based on dice rolls and their **Dexterity**. 

> Note: there is an interesting assymmetry between Monsters and Adventurers Initiative. While each Adventurer is slotted based on his/her roll, a group of identical monsters gets one roll, and will be assigned initiative as a whole group. As a result, a whole group of monsters could go first (or last), which I suspect would result in very extreme results with large groups, with potential for a fast TPK.

> Note: we will leave aside the possibility of confrontations with more than 2 groups involved. 

On their **Turn**, each creature can do a couple of things. It can **Move** to any of the 8 adjacent squares (if reachable), for as long as its movement is not exhausted. During its turn, if the conditions allow it, it can take one **Action**, at any time between the **Move** "steps": **Attack**, **Hide**, **Dash**, ... In addition, some creatures may have the option to take a **Bonus Action**.

Finally, and without going into detail yet, two things will need to be taken into account. First, not every creature sees the same thing at the same time. Some creatures might be hidden from some others, and some creatures have different abilities to see in the dark. Then, during movement, coming in contact, or traversing the zone occupied by another creature has implications, too.

## Preliminary Thoughts on Overall Design

So, how do we approach this?

Given the turn-based nature of combat, a command-based approach seems like a natural fit. At any given time, one creature is up, and, based on the state of the world, can take one of many possible actions (**Move** or **Action**). Based on the result, it can either take another action, or it exhausted what it could do during its turn, and the next creature in initiative order can start.

In other words, what we are after is something like an `update` function, along these lines (any similarity with things Elmish is obviously a coincidence):

``` fsharp
World -> Command -> World
```

Or, in plain English, "Given the current state of the World, and a Command representing what a Creature wants to do, give me back the state of the World after executing the Command".

Before diving into code, a couple of additional thoughts. First, we will need to be explicit about who is taking action. `Move North` is ambiguous - which creature is moving? In other words, we expect that commands will look along the lines of `(CreatureID * Command)`, that is, who wants to do what.

Then, our goal is to build a system which we can ultimately use to simulate strategies for any creature. Now what a creature can do depends on its current situation; for instance, if there is a wall north of me, I can't move north. In that context, it would be very convenient to know what actions a creature is allowed to perform, so we don't have to try potentially illegal ones to figure out what we can actually do. 

> Note: credit where credit is due, I think I heard a similar idea in a talk by Scott Wlaschin demonstrating how to do Tic-Tac-Toe, the Enterprise way.

On a related note, creatures operate on asymmetric information. They do not see the world in its entirety, and operate on different information. Some might be hidden from others, some might not know how strong another is, and so on. If we want to properly simulate strategies for creature, we will need to know what information each creature has, to determine the appropriate action it should take.

In other words, at some point, we will probably need to provide something like a `WorldView` for each creature, that is, what they know about the world, and what exact list of commands they can chose from.

## Modeling Movement

Enough talking - let's jump into coding, and see if that teaches us anything. As a first step, we will focus on movement. We will begin with the most naive implementation possible, and refine as we go.

Each creature in D&D has a speed statistic, which describes how many feet it can move during a turn, under standard circumstances. Combat traditionally takes place on a map divided in a grid, either square or, less commonly, hexagonal. We will use a square grid, with cells of 5 x 5 ft., largely because it is much easier to work with.

A creature is located on a cell (or multiple cells, for large ones), and can potentially move to any of the 8 adjacent cells, if it has enough remaining movement to do so. Movement is taken step-by-step / cell-by-cell, so that if the overall move is interrupted, say, by a trap being triggered or any other event, the location of the creature is known, and it can chose what to do next.

> Note: from a geometry standpoint, this is somewhat flawed: all moves are considered equivalent, even though diagonal moves correspond to a longer distance traveled. As a result, a circle of diameter 20 ft. becomes a square of side 20 ft. Anyways.

Let's model that. A straighforward approach would be to represent the 8 possible directions first:

``` fsharp
type Direction = 
    | N
    | NW
    | W
    | SW
    | S
    | SE
    | E
    | NE
```

... which we can then use to determine the position of a creature, expressed in cell coordinates, after one of these moves:

``` fsharp
type Position = {
    North: int
    West: int
    }

let move (dir: Direction) (pos: Position) = 
    match dir with
    | N -> { pos with North = pos.North + 1 }
    | NW -> 
        { pos with 
            North = pos.North + 1
            West = pos.West + 1
        }
    | W -> { pos with West = pos.West + 1 }
    // etc...
```

Let's try this out:

``` fsharp
{ North = 0; West = 0 }
|> move N
|> move NW
|> move W

// val it: Position = { North = 2; West = 2 }
```

This is a decent start. However, if we want to keep track of multiple creatures, we are missing a piece here, namely the world. First, we will need some form of identifier for creatures:

``` fsharp
type CreatureID = | CreatureID of int
```

For each creature, we will need to know its current position. Let's do that:

``` fsharp
type World = {
    Creatures: Map<CreatureID, Position>
    }
```

And we can now write a first version of our `update` function:

``` fsharp
let update (cmd: CreatureID * Direction) (world: World) = 
    
    let creatureID, direction = cmd
    let currentPosition = world.Creatures.[creatureID]
    let updatedPosition = currentPosition |> move direction 
    
    { world with
        Creatures = 
            world.Creatures 
            |> Map.add creatureID updatedPosition
    }
```

> Note: `Map` behaves essentially like an immutable dictionary, with the `Map.add` function performing an "insert or update" operation.

Let's test this out:

``` fsharp
let world = {
    Creatures = [
        CreatureID 1, { North = 0; West = 0 }
        CreatureID 2, { North = 5; West = 5 }
        ]
        |> Map.ofList
    }

world 
|> update (CreatureID 1, N)
|> update (CreatureID 2, W) 

(*
val it : World =
    { Creatures = map [
        (CreatureID 1, { North = 1; West = 0; })
        (CreatureID 2, { North = 5; West = 6; })
        ]
    }
*)
```

Progress! Let's do a bit of cleanup here. We are going to add more commands as we grow this thing, so passing in a `Direction` is probably not what we want. Let's fix this:

``` fsharp
type Command = 
    | Move of Direction

let update (creatureID: CreatureID, cmd: Command) (world: World) = 
    
    let currentPosition = world.Creatures.[creatureID]

    match cmd with
    | Move(direction) ->
        let updatedPosition = currentPosition |> move direction         
        { world with
            Creatures = 
                world.Creatures 
                |> Map.add creatureID updatedPosition
        }

// omitted for brevity

world 
|> update (CreatureID 1, Move N)
|> update (CreatureID 2, Move SE) 
```

## What Next?

We got the very basics of movement in place - what next?

There are a lot of obvious issues we need to address. Some graceful error handling would be nice: in our example, `update (CreatureID 42, N)` will throw a gnarly `System.Collections.Generic.KeyNotFoundException` - we should be able to do better. There is also a looming ambiguity between distances, expressed in feet, and coordinates on the grid.

However, these are somewhat tactical details. The piece I want to tackle first is the proper handling of turns and movement. Specifically, here is a list of potentially tricky issues we need to address:

- Which creature is currently allowed to move? How about if the creature doesn't want to move? A creature doesn't have to use its full movement, so we will need to signal the end of a turn (probably with a `Done` command), and identify who comes next in initiative order. 
- Which of the 8 possible movements is allowed? This depends on how much movement is left, but also on the terrain or obstacles such as walls.
- Extending movement with the `Dash` action, or potentially bonus action.
- Entering another creature's space.

In other words, plenty of questions to tackle! We will explore that further in our next post. In the meanwhile, the code we discussed today can be found [here on GitHub][3].

[1]: http://media.wizards.com/2016/downloads/DND/PlayerBasicRulesV03.pdf#page=69 
[2]: {{ site.url }}/2018/09/15/give-me-monsters-part-5/  
[3]: https://github.com/mathias-brandewinder/MonsterVault/blob/b045c08584a1ac11c17adc856bc02927c8d4bc59/combat.fsx
