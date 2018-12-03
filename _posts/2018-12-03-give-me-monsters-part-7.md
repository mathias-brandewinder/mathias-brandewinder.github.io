---
layout: post
title: Give me Monsters! (Part 7)
tags:
- F#
- DnD
- Domain-Modeling
---

Welcome back to our ever-expanding series attempting to model D&D 5e rules in F#! In [our previous episode][1], we began to dive in the representation of turn-based combat. We left off with a sketch of a design, where we keep track of the state of affairs in a `World` entity, updating the position of each creatures by applying a `Move` command to it.

We also left a few open issues that need to be addressed. The most glaring issue at that point is that, in our current model, every creature can move in any direction, at any moment. This isn't right: [according to the rules][2], 

> _On your turn, you can move a distance up to your speed. You can use as much or as little of your speed as you like on your turn. [...] You can break up your movement on your turn, using some of your speed before and after your action._

To make that happen, we need to incorporate turns (which creature can currently make decisions), and movement (how many feet a creature is allowed to move).

<!--more-->

## Taking Turns

The first thing we will tackle is turns. Let's start with the easy part: in order to determine if a creature can pass a command, we need to know whose turn it is. That's easy, all we need is to add that information to the `World`:

``` fsharp
type World = {
    Active: CreatureID
    Creatures: Map<CreatureID, Position>
    }
```

We will punt on making any serious decision around error handling for now, and simply throw an exception if a creature acts out of turn:

``` fsharp
let update (creatureID: CreatureID, cmd: Command) (world: World) = 
    
    if world.Active <> creatureID
    then 
        sprintf "Error: it is not %A's turn." creatureID
        |> failwith
    else
    // rest unchanged
```

Not particularly elegant, but it will do for now. We can revisit once we have a better overall sense for error cases.

Now that we know whose turn it is, we need a way to handle change. How do we know a creature is done with their turn, and who comes up next? Per the rules,  

> _You can use as much or as little of your speed as you like_

... which means that we cannot, for instance, wait until all of a creature's movement is used to finish a turn. Not moving, or not doing anything at all, is a valid course of action for a creature on their turn. Therefore, we will need an explicit signal from the creature that they are Done. Let's incorporate that in the commands, then:

``` fsharp
type Command = 
    | Move of Direction
    | Done
```

In other words, until a creature states that they are done with their turn, we assume they are not.

What should happen when a creature is `Done`? Combat follows what is called the **Initiative Order**:

> _The DM ranks the combatants in order [...] (called the initiative order) in which they act during each round. The initiative order remains the same from round to round._

So each creature is ranked when combat begins, and every time a creature finishes their turn, the next one comes up, cycling back to the head of the initiative list when the last one is done. That sounds like a good fit for a list:

``` fsharp
type World = {
    Initiative: CreatureID list
    Active: CreatureID
    Creatures: Map<CreatureID, Position>
    }
```

All we need to do then is handle the `Done` command in our `update` function.

``` fsharp
let update (creatureID: CreatureID, cmd: Command) (world: World) = 
    
    if world.Active <> creatureID
    then 
        sprintf "Error: it is not %A's turn." creatureID
        |> failwith
    else
        match cmd with
        | Move(direction) ->
            // omitted, same as before
        | Done ->
            let activeIndex = 
                world.Initiative 
                |> List.findIndex (fun id -> id = creatureID)
            let nextUp = (activeIndex + 1) % world.Initiative.Length
            let nextActive = world.Initiative.Item nextUp
            { world with 
                Active = nextActive
            }
```

We look up the position of the creature in the initiative list, and increase it by 1, modulo the number of creatures, so we cycle back to the head of the list when the end is reached.

> Note: I debated using an array instead of a list here, because it is better suited for index-based lookups. However, given that I expect that list to be very short, I ended up sticking with the immutable list.

Progress! At that point, by passing a `Done` command for a creature, we can move through the **Initiative Order**, and keep track of who is up. We can now take on movement rules.

## Movement

The main rule we are missing now is this one:

> _On your turn, you can move a distance up to your speed._

Instead of nitpicking the units inconsistency between distance and speed in that statement, let's focus on the intended meaning here, namely "during its turn, a creature can move up to its total allowed movement per turn".  

To implement that rule, we need to know how many feet of **Movement** a creature is allowed per turn. We also need to convert a **Move**, which is cell-based, into a distance. With that in place, we can then compute after each **Move** how much movement the creature has left, and decide whether a movement is permissible.

We have two things at play here. The **Movement** a creature can take won't change, it is a given. On the other hand, how much movement a creature has left in their turn is going to change. Let's separate these two aspects, with a creature statistics, and its current state:

``` fsharp 
[<RequireQualifiedAccess>]
module Creature = 

    type Statistics = {
        Movement: int
        }

    type State = {
        MovementLeft: int
        Position: Position
        }
```

We can now incorporate that into our `World`, which now stores in 2 separate maps the current state of each creature, and its statistics:

``` fsharp
type World = {
    Initiative: CreatureID list
    Active: CreatureID
    Creatures: Map<CreatureID, Creature.State>
    Statistics: Map<CreatureID, Creature.Statistics>
    }
```

By convention, as mentioned in our previous post, we are operating on a square grid, with cells of 5 x 5 ft., which we name `cellSize`. As a result, a creature can move only if it has more that 5 feet of movement left. If that is a case, we perform the movement, and update the movement they have left.

Let's add this in the update function:

``` fsharp
let cellSize = 5

let update (creatureID: CreatureID, cmd: Command) (world: World) = 
    // omitted for brevity    
    let currentState = world.Creatures.[creatureID]

    match cmd with
    | Move(direction) ->
        let movementLeft = currentState.MovementLeft
        if movementLeft < cellSize
        then
            sprintf "Error: %A does not have enough movement left" creatureID
            |> failwith 
        else
            let destination = 
                currentState.Position 
                |> move direction
            let updatedState = 
                { currentState with 
                    Position = destination 
                    MovementLeft = currentState.MovementLeft - cellSize
                }
            { world with
                Creatures = 
                    world.Creatures 
                    |> Map.add creatureID updatedState
            }
    // rest unchanged
```



We have a small problem, though. Every time a creature makes a **Move**, their movement decreases accordingly. However, the movement they have left never goes back up. As a result, once they have consumed their movement, they are stuck. This is not right - every turn, creatures get their full movement back. Let's fix this, and reset `MovementLeft` when they are `Done`:

``` fsharp
let update (creatureID: CreatureID, cmd: Command) (world: World) = 
    // omitted for brevity    
    match cmd with
        // omitted for brevity    
        | Done ->
            let creatureStats = world.Statistics.[creatureID]
            let creatureState = 
                { currentState with 
                    MovementLeft = creatureStats.Movement 
                }
            let activeIndex = 
                world.Initiative 
                |> List.findIndex (fun id -> id = creatureID)
            let nextUp = (activeIndex + 1) % world.Initiative.Length
            let nextActive = world.Initiative.Item nextUp
            { world with 
                Active = nextActive
                Creatures = 
                    world.Creatures 
                    |> Map.add creatureID creatureState     
            }
```

## Cleanup

We have a working model at that point. Given an initial state of the `World`, we can simulate the movement of creatures, following (some of) the rules of movement. However, that initial state of the world will be unpleasant to set up. We need to manually set up the Initiative Order, the Active creature, and 2 maps with each of the creatures' statistics and initial state. On top of that, nothing prevents us from creating inconsistent states, say, an active creature that is not listed in initiative, or an incomplete map for state or statistics.

Let's fix that. The minimal information we need to set the world up is the list of creatures, in initiative order, their statistics, and their starting position. Given that information, we can determine the active creature (the first in the list), and their initial state (their position, with full movement available):

``` fsharp
[<RequireQualifiedAccess>]
module Creature = 

    // omitted for brevity
    let initialize (stats: Statistics, pos: Position) =
        {
            MovementLeft = stats.Movement
            Position = pos
        }

type World = {
    // omitted for brevity
    }
    with
    static member Initialize(creatures: (CreatureID * Creature.Statistics * Position) list) =
        let initiative = 
            creatures 
            |> List.map (fun (creatureID, _, _) -> creatureID)
        {
            Initiative = initiative
            Active = initiative |> List.head
            Creatures = 
                creatures 
                |> List.map (fun (creatureId, stats, pos) -> 
                    creatureId,
                    Creature.initialize (stats, pos)
                    ) 
                |> Map.ofList 
            Statistics = 
                creatures 
                |> List.map (fun (creatureId, stats, _) -> 
                    creatureId,
                    stats
                    ) 
                |> Map.ofList 
        }
```

As a final touch, because we can, let's add a sprinkle of Units of Measure, to disambiguate how movement works:

``` fsharp
[<Measure>]type ft

let cellSize = 5<ft>

[<RequireQualifiedAccess>]
module Creature = 

    type Statistics = {
        Movement: int<ft>
        }

    type State = {
        MovementLeft: int<ft>
        Position: Position
        }
```

We can now set our world up, and act on it, without too much pain:

``` fsharp
let creature1 = 
    CreatureID 1, 
    { Creature.Movement = 30<ft> },
    { North = 0; West = 0 } 
    
let creature2 = 
    CreatureID 2, 
    { Creature.Movement = 20<ft> },
    { North = 5; West = 5 } 

let world = 
    [
        creature1
        creature2
    ]
    |> World.Initialize 

world 
|> update (CreatureID 1, Move N)
|> update (CreatureID 1, Move N)
|> update (CreatureID 1, Done) 
|> update (CreatureID 2, Move SE) 
|> update (CreatureID 2, Done)
|> update (CreatureID 1, Move N) 

(*
val it : World =
  {Initiative = [CreatureID 1; CreatureID 2];
   Active = CreatureID 1;
   Creatures =
    map
      [(CreatureID 1, {MovementLeft = 25;
                       Position = {North = 3;
                                   West = 0;};
                       ActionTaken = None;});
       (CreatureID 2, {MovementLeft = 20;
                       Position = {North = 4;
                                   West = 4;};
                       ActionTaken = None;})];
   Statistics =
    map [(CreatureID 1, {Movement = 30;}); (CreatureID 2, {Movement = 20;})];}
*)
```

## A Dash of Action

We have the basics of a model for movement in place. It is not complete yet, but it is getting there! We could stop here, but let's push ourselves, and go a bit further, with the [**Dash** action][3]. Per the rules again,

> _When you take the Dash action, you gain extra movement for the current turn. The increase equals your speed, after applying any modifiers. With a speed of 30 feet, for example, you can move up to 60 feet on your turn if you dash._ 

How could we go about that?

First, **Dash** is an **Action**. Restating the rules slightly, this means that a creature can choose to take **Dash** as their one **Action** in a turn, which will double the movement they would have available otherwise. To make that work, we need to add a new command for **Dash**, and, when a creature uses it as an **Action**, make sure that they haven't taken other actions before, and modify the movement they have left accordingly. Let's do this.

First, we create a new type, `Action`, and model whether or not an action has been taken by incorporating it as an `Option` in the creature state:

``` fsharp
type Action = 
    | Dash

[<RequireQualifiedAccess>]
module Creature = 

    // omitted for brevity
    type State = {
        MovementLeft: int<ft>
        Position: Position
        ActionTaken: Action option
        }
    
    let initialize (stats: Statistics, pos: Position) =
        {
            MovementLeft = stats.Movement
            Position = pos
            ActionTaken = None
        }
```

Then, we expand our commands, adding the case where a creature decides to take an `Action`:

``` fsharp
type Command = 
    | Move of Direction
    | Action of Action
    | Done
```

And finally, we modify the `update` function. If the command is `Action Dash`, we check that no action has been taken yet, and simply increase the movement the creature has left in the turn by its total movement, and, when a creature is `Done` with its turn, we reset its state to `ActionTaken = None`.

``` fsharp
let update (creatureID: CreatureID, cmd: Command) (world: World) = 
    
    // omitted for brevity
    let currentState = world.Creatures.[creatureID]

    match cmd with
    | Move(direction) ->
        // omitted for brevity
    | Action(action) ->
        match currentState.ActionTaken with
        | Some(_) -> 
            sprintf "Error: %A has already taken its action" creatureID
            |> failwith
        | None ->
            match action with
            | Dash ->
                let creatureStats = world.Statistics.[creatureID]
                let creatureState = 
                    { currentState with 
                        MovementLeft = currentState.MovementLeft + creatureStats.Movement
                        ActionTaken = Some Dash
                    }
                { world with
                    Creatures = 
                        world.Creatures 
                        |> Map.add creatureID creatureState
                }
    | Done ->
        let creatureStats = world.Statistics.[creatureID]
        let creatureState = 
            { currentState with 
                MovementLeft = creatureStats.Movement 
                ActionTaken = None
            }
        // omitted for brevity
```

And that's pretty much it! Now we can `Move` and `Dash`:

``` fsharp
world 
|> update (CreatureID 1, Move N)
|> update (CreatureID 1, Move N)
|> update (CreatureID 1, Action Dash)

(*
val it : World =
  { // omitted
   Creatures =
    map
      [(CreatureID 1, {MovementLeft = 50;
                       Position = {North = 2;
                                   West = 0;};
                       ActionTaken = Some Dash;});
*)
```

## What Next?

Our model for movement is in reasonably good shape at that point, but we are missing a few ingredients. First, we are completely ignoring terrain. What if there are walls or obstacles? How about a swampy terrain, where progression might be slowed? Depending on how much complexity we want to handle, that part shouldn't be overly hard to add to our `World` (famous last words). 

Then, so far we have been ignoring creatures around us. That part is a bit tricky. Entering the space occupied by a creature is sometimes possible (for example, a small creature can go through the space occupied by a much larger creature), but staying there is not allowed, which should make for some fun with rules validation. 

To illustrate the challenge, consider a creature entering the space of a larger creature. Because it cannot stay there at the end of its turn, deciding whether that move is or isn't possible would require checking that leaving that space will still be possible before the turn ends. The other intricate issue ahead is **Attacks of Opportunity**. Essentially, any time a creature moves away from direct contact with a hostile creature, that hostile creature can attack them, out of turn, which breaks the natural list-based initiative order.

In other words, the devil is in the details, and it seems that we have a couple of devilish details that will need handling soon. Where I think I'll go next is, try to reach some reasonable closure around movement, and wrap the code we have in a simple Fable Elmish application, so we can actually see what is happening. In the meanwhile, you can find the code we discussed today [here on GitHub][4].

[1]: {{ site.url }}/2018/11/12/give-me-monsters-part-6/  
[2]: http://media.wizards.com/2016/downloads/DND/PlayerBasicRulesV03.pdf#page=70
[3]: http://media.wizards.com/2016/downloads/DND/PlayerBasicRulesV03.pdf#page=72
[4]: https://github.com/mathias-brandewinder/MonsterVault/blob/53a33c21581aba2620db5146085f62eae2032fae/combat.fsx
