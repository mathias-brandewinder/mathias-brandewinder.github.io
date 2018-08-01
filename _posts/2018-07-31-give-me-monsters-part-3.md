---
layout: post
title: Give me Monsters! (Part 3)
tags:
- F#
- DnD
- Domain-Modeling
---

Now that we have a reasonably working **Abilities** block, let's take a stab at a slightly more challenging section of the Stat Block, the **Hit Points**.

![Goblin Stat Block]({{ site.url }}/assets/2018-07-23-goblin.png)

**Hit Points** represent the "life force" of a creature, so to speak. Mechanically, this is how much damage a creature can take until it dies, and is expressed in dice rolls (`2d6` for a Goblin), and a default average number, if one doesn't want to roll the dice (7 for a Goblin). What this means is that, when creating a Goblin, you could either give him 7 hit points, or roll and add 2 6-sided dice, which would result in hit points between 2 and 12.

Things can get a tad more complicated - for instance, Constitution influences hit points. A creature with high `CON` will get a bonus (more on this later), resulting in expressions likes `4d10+8`, which translates to `roll 4 10-sided dice, sum them, and add 8 to the result`.

Beyond **Hit Points**, dice rolls play a central role in D&D, and show up everywhere (see for instance the _Hit_ description for the Goblin's Scimitar and Shortbow, under Actions). We need a reasonably general way to model them.

<!--more-->

## Dice Rolls

One fun aspect of D&D is its usage of [uncommon dice shapes][1]. Besides the iconic 20-sided dice, dice rolls involve 4, 6, 8, 10 and 12-sided dice.

![20 sided dice]({{ site.url }}/assets/2018-07-31-20-sided-die.jpg)
_[Source: Scott Ogle / Wikimedia.][2]_

> Side note: I will use "dice" for both singular and plural forms. My apologies to the purists!

The mechanical resolution of situations in D&D involves rolling different types of dice and adding them together, potentially in combination with numbers / modifiers, as in `4d6+2d10+8`.

So how would we go about modeling that? First, we need dice:

``` fsharp
type Dice = | D of Sides : int
```

We can now create dice of any type: `let myD8 = D 8`.

What we need next is a way to express formulas such as `4d6+2d10+8`. Stated differently, we want to create expressions. Scanning through the way we previously described rolls, these involve either dice rolls or numbers, and can be combined by addition. That's fairly straightforward:

``` fsharp
type Roll = 
    | Roll of int * Dice
    | Value of int
    | Add of Roll list
```

We have now all we need to represent expressions like `4d6+2d10+8`:

``` fsharp
let example = Add [ Roll(4, D 6); Roll(2, D 10); Value 8 ]
```

We may be able to do better in terms of elegance, but our expressions aren't too far off from what we intended to represent. And the nice thing about having expressions built using discriminated unions like this is that we can inspect and manipulate them in all sorts of ways, for instance, to render them:

``` fsharp
type Roll = 
    | Roll of int * Dice
    | Value of int
    | Add of Roll list
    static member Render (roll:Roll) =
        match roll with
        | Roll(times,D(sides)) -> sprintf "%id%i" times sides
        | Value(value) -> sprintf "%i" value
        | Add(rolls) -> 
            rolls 
            |> List.map Roll.Render 
            |> String.concat "+"

Add [ Roll(4, D 6); Roll(2, D 10); Value 8 ] |> Roll.Render
// val it : string = "4d6+2d10+8"
```

We mentioned earlier that the average value of a roll was commonly used for **Hit Points**. That might come in handy in other situations, so let's add that, too:

``` fsharp
type Roll = 
    | Roll of int * Dice
    | Value of int
    | Add of Roll list
    static member Average (roll:Roll) =
        let rec average (roll:Roll) =
            match roll with
            | Roll(times,D(sides)) -> (times * (sides + 1)) / 2
            | Value(value) -> value
            | Add(rolls) ->
                rolls |> List.sumBy average
        average roll

Roll(2, D 6) |> Roll.Average
// val it : int = 7
```

> Note: I am assuming here that all dice have a lowest possible value of 1

From a mathematical standpoint, this definition of the average is intriguing. A typical definition of the average gives 3.5 for a 6-sided dice. However, D&D is purely integers based, and rounds down by default, hence our implementation. As an interesting side-effect, `average 2d6` is not equal to `average 1d6 + average 1d6`!

## Prettier Dice Rolls

Compared to the way rolls appear in D&D, our expressions are a bit heavy-looking. The main reason is that, as a list can contain only items of one type, we cannot mix-and-match rolls and integers, which we have to wrap in `Value`.

Let's make that prettier, and kill 2 birds with one stone (`DEX` ability check, difficulty `Very Hard`), by overloading the `+` operator. First, whenever we see a `Roll` before and after the `+` operator, we will concatenate the rolls into one `Add [ ... ]`:

``` fsharp
type Roll = 
    | Roll of int * Dice
    | Value of int
    | Add of Roll list
    // omitted for brevity
    static member (+) (v1:Roll,v2:Roll) = 
        match v1,v2 with
        | Add(rolls1), Add(rolls2) -> Add(rolls1 @ rolls2)
        | Add(rolls1), roll2 -> Add(rolls1 @ [ roll2 ])
        | roll1, Add(rolls2) -> Add(roll1 :: rolls2)
        | roll1, roll2 -> Add [ roll1 ; roll2 ]

Roll(2, D 6) + Value 10 + Roll(4, D 10)
// val it : Roll = Add [Roll (2,D 6); Value 10; Roll (4,D 10)]
```

Progress! In the example above, can we get rid of `Value 10`, and simply use `10` instead? Sure, all we need is to wrap the integer into a `Value`:

``` fsharp
type Roll = 
    | Roll of int * Dice
    | Value of int
    | Add of Roll list
    // omitted for brevity
    static member (+) (v1:Roll,v2:Roll) = 
        match v1,v2 with
        | Add(rolls1), Add(rolls2) -> Add(rolls1 @ rolls2)
        | Add(rolls1), roll2 -> Add(rolls1 @ [ roll2 ])
        | roll1, Add(rolls2) -> Add(roll1 :: rolls2)
        | roll1, roll2 -> Add [ roll1 ; roll2 ]
    static member (+) (roll:Roll,num:int) = roll + Value num
    static member (+) (num:int,roll:Roll) = Value num + roll

Roll(2, D 6) + 10 + Roll(4, D 10)
// val it : Roll = Add [Roll (2,D 6); Value 10; Roll (4,D 10)]
```

This looks pretty decent at that point, and I would normally stop there. However, I got curious and wondered if I could go a bit further, and simplify `Roll(4, D 8)` into `4*d8`, which turned out to be easier than anticipated:

``` fsharp
type Dice = 
    | D of Sides : int
    static member ( *) (times:int,dice:Dice) = Roll(times,dice)
and Roll = 
    | Roll of int * Dice
    | Value of int
    | Add of Roll list
    // omitted
    static member (+) (v1:Roll,v2:Roll) = 
        match v1,v2 with
        | Add(rolls1), Add(rolls2) -> Add(rolls1 @ rolls2)
        | Add(rolls1), roll2 -> Add(rolls1 @ [ roll2 ])
        | roll1, Add(rolls2) -> Add(roll1 :: rolls2)
        | roll1, roll2 -> Add [ roll1 ; roll2 ]
    static member (+) (roll:Roll,num:int) = roll + Value num
    static member (+) (num:int,roll:Roll) = Value num + roll

let d4 = D 4
let d6 = D 6
let d8 = D 8
let d10 = D 10
let d12 = D 12
let d20 = D 20

2 * d6 + 10 + 4 * d10 
// val it : Roll = Add [Roll (2,D 6); Value 10; Roll (4,D 10)]
```

## Hit Points

We are now armed with a reasonable representation of dice rolls, time to go back to **Hit Points**!

I could not find a canonical formula describing how a monster hit points are computed. However, scanning through the Monster Manual, it turns out that empirically, all monsters follow a similar pattern:

**Hit Points** = `multiplier` * `dice type` + `bonus`.

The type of dice matches the creature **Size**, and the `bonus` is directly related to its **`CON` modifier**: `bonus = CON modifier * multiplier`.

This is somewhat consistent with [the rules driving character **Hit Points**][3], which are computed by adding their `CON` modifier to a certain type of dice (determined by the **Class**), and multiplying by their **Level**. There are also assymmetries here: Monsters do not have a notion of **Level**, and, unlike Adventurers, the type of dice used is given by their race, and not their **Class**, which isn't defined. There are also a few other differences (maximum hit points at level 1, rounding up in average hit points calculation). In other words, while the overall logic is similar, there doesn't seem to be an obvious way to compute hit points for Monsters and Adventurers in a consistent manner.

At any rate, we have enough to create a model for a Monster **Hit Points**. First, we need to convert a Monster **Size** into the appropriate type of dice:

``` fsharp
type Size = 
    | Tiny
    | Small 
    | Medium 
    | Large 
    | Huge 
    | Gargantuan

let hitPointsDice (size:Size) =
    match size with
    | Tiny -> d4
    | Small -> d6 
    | Medium -> d8
    | Large -> d10
    | Huge -> d12
    | Gargantuan -> d20
```

All that's left to do is to create a type `Monster`, which will incorporate **Abilities**, and the additional information we need:

``` fsharp
type Monster = {
    Name: string
    Size: Size
    HitDice: int
    Abilities: Abilities
    }
    with
    static member HitPoints (monster:Monster) = 
        monster.HitDice * hitPointsDice monster.Size
        + monster.HitDice * modifier monster.Abilities CON
```

We added a value **HitDice**, which plays the same role as **Level** for an Adventurer. We can now modify our example, and define monsters and variants along these lines, using Hobgoblins this time (Monster Manual, p186), to illustrate the impact of the `CON` modifier:

``` fsharp
let hobgoblin = {
    Name = "Hobgoblin"
    HitDice = 2
    Size = Medium       
    Abilities = {
        Scores = {
            STR = 13
            DEX = 12
            CON = 12
            INT = 10
            WIS = 10
            CHA = 9
            }
        Bonuses = [ ]
        }
    }

let hobgoblinCaptain = {
    hobgoblin with
        Name = "Hobgoblin Captain"
        HitDice = 6
        Abilities = {
            hobgoblin.Abilities with
                Bonuses = [
                    { Ability = STR; Bonus = 2 }
                    { Ability = DEX; Bonus = 2 }
                    { Ability = CON; Bonus = 2 }
                    { Ability = INT; Bonus = 2 }
                    { Ability = CHA; Bonus = 4 }
                    ]
        }
    }

hobgoblin |> Monster.HitPoints
// val it : Roll = Add [Roll (2,D 8); Value 2]
hobgoblin |> Monster.HitPoints |> Roll.Average
// val it : int = 11
hobgoblinCaptain |> Monster.HitPoints
// val it : Roll = Add [Roll (6,D 8); Value 12]
hobgoblinCaptain |> Monster.HitPoints |> Roll.Average
// val it : int = 39
```

First, reassuringly, our results match the Monster Manual. This doesn't prove the code correct, but at least it isn't blatantly wrong. Then, it's rather nice to see how, once we are past the initial effort of modeling rolls by creating our own expressions, everything starts to flow nicely. We can now express fairly clearly how **Hit Points** are computed (`monster.HitDice * hitPointsDice monster.Size + monster.HitDice * modifier monster.Abilities CON`), the hit dice changes from Hobgoblin to Hobgoblin captain automatically propagate into the computation, and anywhere we encounter rolls, we should be able to reuse what we wrote.

Anyways, that's enough adventuring for one day! The current state of affairs described in this post is [here on GitHub][4], let me know if you have questions or comments. Not sure yet what I'll do in the next installment, we'll see where the code leads us :)


[1]: https://en.wikipedia.org/wiki/Dice#Polyhedral_dice
[2]: https://commons.wikimedia.org/wiki/File:Dice_in_B%26W.jpg
[3]: http://media.wizards.com/2016/downloads/DND/PlayerBasicRulesV03.pdf#page=10
[4]: https://github.com/mathias-brandewinder/MonsterVault/tree/f2a25d444a0a5304788ce1054d7532443b925948
