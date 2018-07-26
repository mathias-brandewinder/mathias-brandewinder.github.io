---
layout: post
title: Give me Monsters! (Part 2)
tags:
- F#
- DnD
- Domain-Modeling
---

Time to start creating monsters! We will begin with the **Abilities** section of the Stat Block.

![Goblin Stat Block]({{ site.url }}/assets/2018-07-23-goblin.png)

First, what are **Abilities**? Every creature is described by 6 **Ability Scores**, which describe by a number from 1 to 20 (or possibly more) how able the creature is, across 6 dimensions:

- STR (Strength)
- DEX (Dexterity)
- CON (Constitution) 
- INT (Intelligence) 
- WIS (Wisdom)
- CHA (Charisma)

Ability scores have a dual usage: as raw scores, and as **Ability Modifiers**, which indicate a bonus or malus for that ability ([see the rules for details][1]). As an example, the Goblin has an INT score of 10, which is perfectly average and gives a modifier of 0; his DEX is 14, giving him a +2 bonus, and a CHA of 8, with a malus of -1. 

<!--more-->

We need to store 6 values, one for each **Ability Score**. That seems like a good case for a record:

``` fsharp
type Scores = {
    STR: int
    DEX: int
    CON: int
    INT: int
    WIS: int
    CHA: int
    }
```

## Modifiers

How would we go about getting the corresponding modifiers?

There are 2 parts to the problem: converting a score to a modifier, and getting the modifier for each ability. We could of course mechanically transcribe the rules, and convert along these lines:

``` fsharp
let scoreToModifier (score:int) = 
    if score <= 1 then -5
    elif score <= 3 then -4
    elif score <= 5 then -3
    // more of it, omitted for brevity
```

This is a bit silly, however: there is a clear pattern here, with modifiers moving by 1 as scores move by 2. So instead, we'll go for a compact, albeit perhaps less immediately readable version:

``` fsharp
let scoreToModifier score = 
    (score / 2) - 5
    |> min 10
    |> max -5
```

As an aside, D&D conveniently uses the rule "always round down", which happens to fit quite nicely with the way integer operations are handled in .NET.

To extract modifiers from **Ability Scores**, we would like to be able to request the modifier for any **Ability**. This sounds like a good case for a discriminated union:

``` fsharp
type Ability = 
    | STR
    | DEX
    | CON 
    | INT 
    | WIS
    | CHA
```

Armed with this, all we need now is to write a function, which, given an **Ability**, will retrieve the correct score, and convert it to a modifier:

``` fsharp
let modifier scores ability =
    match ability with
    | STR -> scores.STR
    | DEX -> scores.DEX
    | CON -> scores.CON
    | INT -> scores.INT 
    | WIS -> scores.WIS
    | CHA -> scores.CHA
    |> scoreToModifier
```

We can replicate the Goblin case now:

``` fsharp
let goblin = {
    STR = 8
    DEX = 14
    CON = 10
    INT = 10
    WIS = 8
    CHA = 8
    }

modifier goblin STR // -1
```

## Basic Markdown rendering

One of the reasons I want to create my own model of monsters, is to easily create cards for them, formatted the way I want. Let's take a stab at that, formatting the Abilities using Markdown.

Using a table to display the Abilities seems reasonable; we would represent our Goblin along these lines:

```
STR | DEX | CON | INT | WIS | CHA
:---: | :---: | :---: | :---: | :---: |  :---:
8 | 14 | 10 | 10 | 8 | 8
-1 | +2 | 0 | 0 | -1 | -1
```

To achieve this, we need to iterate over the list of abilities, in a predictable order, extract and format the score and the modifier, and join them with a column separator, `|`. We'll need a couple of small things here. First, we need a list to iterate on. Then, we cannot access the score for a specific Ability yet. Finally, we would like to be explicit about modifiers, and preprend a `+` sign in front of positive multipliers, for easier reading.

Let's get to work. First, let's write a `score` function, and refactor `modifier` accordingly:

``` fsharp
let score scores ability =
    match ability with
    | STR -> scores.STR
    | DEX -> scores.DEX
    | CON -> scores.CON
    | INT -> scores.INT 
    | WIS -> scores.WIS
    | CHA -> scores.CHA

let modifier scores ability =
    ability
    |> score scores
    |> scoreToModifier
```

Let's also define a canonical list of **Abilities**:

``` fsharp
let abilities = [ STR; DEX; CON; INT; WIS; CHA ]
```

... and attack the markdown part:

``` fsharp
[<RequireQualifiedAccess>]
module Markdown = 

    let signed (value) = 
        if value > 0
        then sprintf "+%i" value
        else sprintf "%i" value

    let abilities (scores:Scores) =
        [
            abilities 
            |> List.map (sprintf "%A") 
            |> String.concat " | "
            
            abilities 
            |> List.map (fun _ -> ":---:") 
            |> String.concat " | "
            
            abilities 
            |> List.map (score scores >> sprintf "%i") 
            |> String.concat " | "
            
            abilities 
            |> List.map (modifier scores >> signed) 
            |> String.concat " | "
        ]
        |> String.concat "  \n"
```

And we are done - we can now run this:

``` fsharp
goblin |> Markdown.abilities
```

... which produces the following:

STR | DEX | CON | INT | WIS | CHA
:---: | :---: | :---: | :---: | :---: |  :---:
8 | 14 | 10 | 10 | 8 | 8
-1 | +2 | 0 | 0 | -1 | -1

## Going a bit further

We have enough here to represent a creature's abilities, and could stop here. However, the representation of an Adventurer or Monster by its abilities scores hides a small issue, namely that raw scores are sometimes modified by score bonuses.

Let me provide two examples. In the case of Adventurers, some races come with **Ability Score Increases**. For instance, any [Elf will receive a `+2` bonus on its `DEX` score][2]. In the case of Monsters, it is common to create "variants" of a Monster by modifying their standard Ability Scores. For instance, one could create a "Goblin Boss" (Monster Manual, p166), which has a `STR` of 10 instead of 8, and a `CHA` of 10 instead of 8.

If we bake both the original score and the bonus together into the Ability Score, we loose some information which could be valuable when modifying a creature. 

How could we avoid that? The approach I took was to separate explicitly these two parts, along these lines:

``` fsharp
type ScoreBonus = {
    Ability: Ability
    Bonus: int
    }

type Abilities = {
    Scores: Scores
    Bonuses: ScoreBonus list
    }

let score abilities ability =
    let baseScore = 
        let scores = abilities.Scores
        match ability with
        | STR -> scores.STR
        | DEX -> scores.DEX
        | CON -> scores.CON
        | INT -> scores.INT 
        | WIS -> scores.WIS
        | CHA -> scores.CHA
    let bonuses = 
        abilities.Bonuses 
        |> List.sumBy (fun bonus -> 
            if bonus.Ability = ability 
            then bonus.Bonus 
            else 0)
    baseScore + bonuses 
```

This allows me then to do things like this, where I can define a Goblin Boss as "A Goblin, with a STR and CHA bonuses":

``` fsharp
let goblin = {
    Scores = {
        STR = 8
        DEX = 14
        CON = 10
        INT = 10
        WIS = 8
        CHA = 8
        }
    Bonuses = [ ]
    }

let goblinBoss = {
    goblin with
        Bonuses = [
            { Ability = STR; Bonus = 2 }
            { Ability = CHA; Bonus = 2 }
            ]
    }
```

In other words, I can now create a template for a canonical Monster, and create a variant, by specifying what changes should be applied to the original.

I will likely revisit this aspect of the model at a later point, because conceptually, there is something different about racial abilities and modified monsters. In the second case, I could apply any modification I want, whereas in the first, the bonus is set by the rules, and explicitly depends on the creature race. However, this will do for now, and we will leave it there!

If you want to take a look at the code in a more convenient manner, the current state of affairs is [here on GitHub][3]. Let me know if you have questions or comments, and next time, we'll probably dig into **Hit Points** and modeling dice rolls and how to represent them as expressions!

[1]: http://media.wizards.com/2016/downloads/DND/PlayerBasicRulesV03.pdf#page=57
[2]: https://roll20.net/compendium/dnd5e/Elf#content
[3]: https://github.com/mathias-brandewinder/MonsterVault/tree/69eefde247928f5d22132733e302b29cdd02d9c1
