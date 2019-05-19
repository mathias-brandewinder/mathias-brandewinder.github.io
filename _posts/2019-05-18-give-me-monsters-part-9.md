---
layout: post
title: Give me Monsters! (Part 9)
tags:
- F#
- DnD
- Domain-Modeling
- Fable
- Fable-Elmish
---

After a long period of silence, time to get back to our series on modelling D&D using F#! In our [last installment][1], we plugged our code into Fable Elmish, to create a crude application simulating and visualizing combat. 

The main reason I didn't write for so long was that, as I put things together, I realized there were flaws in the design. I made heavy changes during the December holidays to address some of them, but found it hard to break it down in smaller steps that would fit a blog post after the fact. I don't see a reason why things would magically get easier if I wait longer, so I'll bite the bullet and try to explain these changes today.

## Design issues

What were the issues I ran into?

Our initial version was a direct implementation of a naive interpretation of [the rules][2], which state that 

> On your turn, you can move a distance up to your speed and take one action.

This roughly translated to a model where each creature, on their turn, could issue one or more commands, updating the state (`World`), one command at a time:

``` fsharp
type Command = 
    | Move of Direction
    | Action of Action
    | Done
```

So what was the problem with that? 

<!--more-->

First, there was no end state, a problem that became obvious as it was now possible to easily play out an entire fight to the bitter end. What should happen when every creature is dead, for instance? In the initial version, a new command was expected each turn, with no end to combat.

Then, our interpretation of the rules was a bit simplistic. The rules state that a creature can take one **Action** on their turn. One piece that is left unsaid here is that they can also take a **Reaction**: depending on the **Action** taken, a creatures can potentially react, out of their turn. The most common example is the [**Opportunity Attack**][3], which states that 

> You can make an **Opportunity Attack** when a hostile creature that you can see moves out of your reach. To make the opportunity attack, you use your reaction to make one melee attack against the provoking creature. The attack occurs right before the creature leaves your reach.

This is problematic on many levels. Instead of simply following the initiative order to determine which creature has their turn and can perform actions, we also need to accommodate out-of-turn reactions from other creatures, and keep track of which creatures still have a **Reaction** available. Furthermore, this also breaks our nice and simple model, where each command is immediately executed: if an action triggers a reaction, the action will not be processed until the reaction has been completely executed. In the case of the **Opportunity Attack**, for instance, if a creature moves away from a hostile creature and triggers such an attack, the movement is not executed until the attack has been fully resolved. As a possible result, the creature moving could be killed, for instance, in which case their **Move** action doesn't even take place.

To make things worse, a **Reaction** could also trigger another **Reaction**. It is an unlikely scenario, but it is possible. For instance, the Fighter class has two manoeuvers available, **Parry** (a reaction that reduces the damage taken from a successful melee attack / PHB p74), and **Riposte** (a reaction that allows to make a melee attack against a creature that just failed theirs, PHB p74). We could now have a full cascade of reactions to handle, for instance in a scenario like this one: 

"The Fighter moves, triggering an Opportunity Attack from the Goblin. That Goblin Attack is successful, and the Fighter decides to react with Parry. The Opportunity Attack is now reduced by the Parry, but doesn't save the Fighter who dies, invalidating their initial Move action".

Our initial take is clearly not going to cut it. Time to go back to the drawing board, and redesign our model a bit.

## Actions and Reactions

So how could we go about modeling this?

The first issue (the end state) suggests that we need to distinguish between 2 situations: combat is either finished, or not. If combat is not finished, we are in the situation covered by our initial model, and someone needs to make a decision. If not, we are done, and may be interested in the combat outcome. This suggests a type along these lines:

``` fsharp
type ActionNeeded = {
    // who needs to act?
    Creature: CreatureID
    // what choices do they have?
    Alternatives: list<Action>
    }

type CombatState = 
    | CombatFinished of CombatOutcome
    | ActionNeeded of ActionNeeded
```

How about reactions? This is where things become hairy. We probably want something similar to `ActionNeeded`, but we will need to know more than just who can take a reaction and what choices they have. To illustrate why, let's revisit the **Parry** and **Riposte** examples. Both of them are triggered by an attack, but we need to know whether or not the attack is successful. At the same time, the result of the triggering action is not processed until the reaction is taken: we need to keep track of that result, which is "unconfirmed" until the impact of the reaction has been applied. Furthermore, as we saw earlier, the trigger for a **Reaction** could be either an **Action**, or a **Reaction**.

The approach I took here was to build up a chain for **Reaction**s, keeping track of what triggered it, and is still waiting to be confirmed: 

``` fsharp
type CombatState = 
    | CombatFinished of CombatOutcome
    | ActionNeeded of ActionNeeded
    | ReactionNeeded of ReactionNeeded * WaitingForConfirmation
```

... where `WaitingForConfirmation` looks like this:

``` fsharp
type WaitingForConfirmation = 
    | Action of UnconfirmedActionResult
    | Reaction of UnconfirmedReactionResult * WaitingForConfirmation
```

In essence, `WaitingForConfirmation` is a very specialized linked list. It cannot be empty, and will be either a single **Action** (in which case we store its unconfirmed result), or a chain of **Reaction**s leading eventually to the original **Action**. Without going into too much detail, this is (slightly simplified) how our complicated scenario, involving the Fighter and the Goblin, would look like:

``` fsharp
ReactionNeeded (
    // the fighter can take the parry reaction, or pass
    { CreatureID = fighter; Alternatives = [ parry; pass ] },
    // this is a Reaction
    Reaction (
        // Reaction to the opportunity attack of the monster, tentatively successful
        { CreatureID = goblin; Reaction = opportunityAttack; Outcome = successfulAttack },
        // which itself is a reaction to the original Move action
        Action { CreatureID = fighter; Action = Move North; Outcome = Move North }
        )
    )
```

That takes care of part of our problem. In our Elmish application, we can ask for what **Action** a creature decides to take by displaying the **ActionNeeded**, and handle the corresponding message. If that **Action** triggers a **Reaction**, we simply build up the corresponding **ReactionNeeded**, and keep building up until no new **Reaction** is triggered, keeping track of the entire chain of events leading to it in the `WaitingForConfirmation` part. Progress!

## Processing Actions and Reactions

Once I got that piece sorted out, I realized there was another problem. In the original approach, each time a creature took an action, the result was immediately computed. This created a straightforward sequence of operations: determine who needs to act and what their alternatives are, make a decision in the user interface, update the state of the world, and repeat until combat is over.

Unfortunately, that sequence breaks down once **Reaction**s are involved, because a decision taken is not always immediately executed. Let's consider again the complex **Parry** **Reaction** example:

1) Fighter decides to Move
2) This triggers a potential Opportunity Attack: Move result is on hold 
3) Goblin decides to take the Opportunity Attack reaction
4) This triggers a potential Parry Reaction: attack result is on hold
5) Fighter decides to take the Parry Reaction
6) No further Reaction is triggered: Fighter Parry Reaction is executed
7) Goblin Opportunity Attack is modified accordingly and executed
8) Fighter Move is executed
9) Action is complete, either Combat is over or someone needs to take an Action

The core of the issue shows up in steps 6, 7 and 8. Here, 3 actions are being executed in succession, without any user input happening in between. This is a problem with the original design: we decide in the UI which action to take, and we immediately execute it. Both go hand in hand, and we need to disconnect them.

The way I approached it was by introducing a second model, `Transition`, representing each of the possible states of combat. The version shown below is a slight simplification of the code currently in use, in part to make it easier to follow, in part because I am not sure I got it 100% right just yet:

``` fsharp
type Transition = 
    | AttemptAction of (CreatureID * Actions.Action)
    | ConfirmAction of UnconfirmedActionResult
    | ExecuteAction of (CreatureID * Outcome)
    | ActionCompleted
    | ActionCancelled
    | ReactionTriggered of (CreatureID * ReactionNeeded)
    | AttemptReaction of (CreatureID * Reactions.Reaction)
    | ConfirmReaction of UnconfirmedReactionResult
    | ReactionCompleted
    | ReactionCancelled of CreatureID
    | ExecuteReaction of (CreatureID * Outcome)
```

How is this useful? It helps, because we can now write a function `execute` which, given a `GlobalState` and a `Transition`, can move to the next `Transition`, and will continue to do so until it cannot, because it needs some information / input. 

As an illustration, here is a sketch of what happens when processing a new **Action**: we start in the `AttemptedAction` state, where we know that a creature wants to take an **Action**. We determine the tentative outcome of that action, and verify whether or not anyone can take a **Reaction**. If not, we move to `ExecuteAction`, where we apply the effect to the `GlobalState`, and move then to `ActionCompleted`, where we determine who needs to take an **Action** next, and return the corresponding `CombatState.ActionNeeded`, waiting for a decision to be made. The situation is a bit more hairy when **Reaction**s are involved, but follow the same pattern: each step, the `execute` function moves from one `Transition` to the next, until some input is needed, in what case it returns the proper `ActionNeeded` or `ReactionNeeded`, or until combat is over.

All we need to do at that point is wire it up in the Elmish `update` function: given a `Message` describing what decision has been made by a creature in their turn, we call the `execute` function, which will recursively walk through `Transition`s and update the state accordingly, until we reach an `ActionNeeded` or `ReactionNeeded` state, and ask for input again in the UI.

## Conclusion

Hopefully, this post will help figure out some of the [code changes I made in December and January][4]. I left quite a few low-level details out, and tried to focus primarily on how these changes came to be, and the overall approach. The code works: in its current state, **Opportunity Attacks** works properly, and I even tested out **Parry** to confirm that it could handle deeper reaction chains. That being said, the code is also a bit messy at that point, and the design could benefit from a bit of cleanup, I will do that over the next few weeks.

Next time, I will take a stab at explaining the other major change I made around the same time, adding an automated mode so that the game could play itself, with each agent making decisions following a strategy. Until then, please let me know if you have comments or questions :) 


[1]: {{ site.url }}/2018/12/15/give-me-monsters-part-8/  
[2]: http://media.wizards.com/2018/dnd/downloads/DnD_BasicRules_2018.pdf#page=72
[3]: http://media.wizards.com/2018/dnd/downloads/DnD_BasicRules_2018.pdf#page=76
[4]: https://github.com/mathias-brandewinder/MonsterVault/tree/c8821708bdad02535eb8b545b6a619598d8e0ba0
