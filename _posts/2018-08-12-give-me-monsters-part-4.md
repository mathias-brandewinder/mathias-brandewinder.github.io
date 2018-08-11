---
layout: post
title: Give me Monsters! (Part 4)
tags:
- F#
- DnD
- Domain-Modeling
---

In our previous episode, [we took at stab at modeling **Hit Points**][1], which lead us to exploring the representation of dice rolls as expressions. Today, we'll relax a bit, and finish up the missing parts of the top section of the Monster description:

![Goblin Stat Block]({{ site.url }}/assets/2018-07-23-goblin.png)

What are we missing at that point? The creature type ("small humanoid"), **Alignment** ("neutral evil"), the **Armor Class**, and **Speed**. Let's add that in, and improve our Markdown renderer in the process.

<!--more-->

## The Low Hanging Fruits

But first, where were we? Our Monsters are currently represented by the following record type:

``` fsharp
type Monster = {
    Name: string
    Size: Size
    HitDice: int
    Abilities: Abilities
    }
    // omitting members for brevity
```

Including **Speed** is straightforward - all we need is an additional label, `Speed`, of type `int`.

How about **Alignment**? [A creatures' alignment describes its attitude, on two different axes][2], which, as far as I can tell, don't have a proper canonical name. A creature can be **Good**, **Neutral** or **Evil**, and it can be **Lawful**, **Neutral** or **Chaotic**. Any combination is possible, and the "Neutral-Neutral" combination is typically simply referred to as **Neutral**.

Choices between exclusive "or" options are a good hint that we will need some Discriminated Unions, aka sum types. I'll name these 2 axes "Social" and "Moral":

``` fsharp
type Social = 
    | Lawful 
    | Neutral 
    | Chaotic 

type Moral = 
    | Good 
    | Neutral 
    | Evil 
```

A creatures' alignment can be any combination of these two - this is a good fit for a Tuple, aka product type:

``` fsharp
type Alignment = Social * Moral
```

I could also have used a Record here, something like `type Alignment = { Social:Social; Moral:Moral }`, which would arguably be a bit more explicit. I ended up keeping the Tuple, because the creation of an alignment ends up being a bit lighter: `let alignment = Lawful, Good`.

The creature description is (mostly) straightforward. Each creature belongs to one of a given set of [**Creature Types**][3] - again, a good case for a Discriminated Union:

``` fsharp
type CreatureType = 
    | Aberration 
    | Beast 
    // omitted for brevity
    | Plant 
    | Undead 
```

> Side note: I will ignore the Creature **Tag** for now ("goblinoid" in our example). It isn't directly useful at that point, and I couldn't figure out if there was a relationship between the Tag and the Creature Type, that is, whether there were any rules around what combinations are possible. A Goblinoid Plant doesn't seem to make much sense :)

## Armor Class

Almost there - the last missing piece is the **Armor Class** (aka **AC**), which describes how good a creature is at avoiding getting hit.

For Adventurers, the **Armor Class** depends on two things: [Dexterity, and what **Armor** and/or **Shield**) is worn][4]. As we can see in our Goblin example, the same general rules appear to apply to Monsters. However, the correspondence is only partial. Monsters come in different shapes, and some Monsters - say, a Bear - cannot wear an Armor or a Shield. Furthermore, looking through the Monster Manual, some Monsters without armor appear with either just an Armor Class number, with no further indication (for instance, a basic [frog][5]), or a Natural Armor (for instance, a [boar][6]). 

This is guesswork, but my interpretation is that the first case describes a creature with no armor, following the same **AC** rules as an un-armored Adventurer, that is, `10 + DEX modifier`, whereas the second describes creatures with natural defenses that provide a bonus in addition to their `DEX` modifier.

So how could we go about modeling this?

First, it looks like we have two different cases to handle: a Creature either can or cannot wear protective equipment. This smells like potentially another Discriminated Union. In the first case, they _can_ wear one of the possible **Armor** types, and potentially a **Shield**.  In the second case, they can have an **AC** bonus.

Let's first list the canonical types of **Armor** available, as defined in the rules:

``` fsharp
type Armor = 
    | Padded 
    | Leather 
    // omitted for brevity
    | Splint 
    | Plate 
```

... and then what the Creature wears:

``` fsharp
type ProtectiveGear = {
    Armor: Armor option
    Shield: bool
    }
```

We use an `Option` for **Armor**, because a Creature doesn't necessary wear **Armor**, even if they can. We'll keep the **Shield** as a plain `bool` for now, because all we need to know is whether or not the creature wears one, which translates into a straight **AC** bonus.

Armed with this (sorry for the bad pun) we can now represent our two cases with a Discriminated Union:

``` fsharp
type Protection = 
    | Natural of Bonus : int
    | Equipment of ProtectiveGear
```

We can at that point replicate the [**Armor Class** calculations from the rules][4]:

``` fsharp
let armorClass protection dex =
    match protection with
    | Natural(bonus) -> 10 + dex + bonus
    | Equipment(gear) ->
        match gear.Armor with
        | None -> 10 + dex
        | Some(armor) ->
            match armor with
            | Padded -> 11 + dex
            | Leather -> 11 + dex
            | StuddedLeather -> 12 + dex
            | Hide -> 12 + min 2 dex
            // omitted for brevity
            | Plate -> 18
        |> match gear.Shield with
            | true -> (+) 2
            | false -> id
```

... and incorporate all that new information into our Monsters:

``` fsharp
type Monster = {
    Name: string
    Size: Size
    CreatureType: CreatureType
    Alignment: Alignment
    Protection: Protection
    Speed: int
    HitDice: int
    Abilities: Abilities
    }
    with
    static member HitPoints (monster:Monster) = 
        monster.HitDice * hitPointsDice monster.Size
        + monster.HitDice * modifier monster.Abilities CON
    static member AC (monster:Monster) =
        armorClass monster.Protection (modifier monster.Abilities DEX)
```

## Monster Stats to Markdown

Let's see if we can update our Markdown rendering. We already have the [**Abilities** block ready from episode 2][7] - let's add the rest. 

One way to look at the Monster description is as a sequence of sections/paragraphs. In Markdown, paragraphs breaks are denoted by a double space and a line break, so we could generate our document by creating a sequence of strings with Markdown formatting - the paragraphs - and concatenate them like this:

``` fsharp
let paragraphs (blocks:string seq) = 
    blocks 
    |> String.concat "  \n"

[
    "This is paragraph one"
    "This is paragraph two"
]
|> paragraphs
```

All we need to do then is create a couple utility functions to handle formatting, and render each of the sections. We won't go through all of the details (you can take a look at the code here), but will illustrate a couple of relevant pieces.

Let's start the sheet with the Monster name formatted as a title, using title case:

``` fsharp
[<RequireQualifiedAccess>]
module Markdown = 

    let textInfo = CultureInfo("en-US",false).TextInfo
    let titleCase (txt:string) = txt |> textInfo.ToTitleCase

    // omitted: abilities block, done in episode 2 

    let monsterSheet (monster:Monster) =
        [
            sprintf "# %s" monster.Name |> titleCase      

            monster.Abilities |> abilities 
        ]
        |> paragraphs
```

Let's check that it works with our Goblin:

``` fsharp
let goblin = {
    Name = "Goblin"
    HitDice = 2
    Size = Small
    CreatureType = Humanoid
    Alignment = Social.Neutral, Evil
    Protection = 
        Equipment { 
            Armor = Some Leather 
            Shield = true
            }
    Speed = 30
    Abilities = {
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
    }

goblin |> Markdown.monsterSheet
```

... which produces the following Markdown:

# Goblin  
STR | DEX | CON | INT | WIS | CHA  
:---: | :---: | :---: | :---: | :---: | :---:  
8 | 14 | 10 | 10 | 8 | 8  
-1 | +2 | 0 | 0 | -1 | -1  

Progress! From there on, all we need is to incrementally add each of the pieces we want rendered. Let's just take the **Armor Class** block, for illustration purposes. In our Goblin example, what we want is the following:

**Armor Class** 15 (Leather Armor, Shield)

We already have a function `armorClass` that will compute the **AC** value for a Monster, the only part missing is the equipment description. That part is a bit unpleasant if we want to faithfully replicate the Monster Manual formatting:

- For natural armor, we only want to display something if there is a non-zero bonus,
- For gear, we want to display the equipment as a comma-separated list, if there is equipment,
- If there are any items to display, they should be capitalized and parenthesized.

Our solution is not particularly elegant, but it works. We will separate the rendering in 2 parts: first, generate a list of items we might have to display, then, format that list if it contains something.

``` fsharp
let commaSeparated (blocks:string seq) = 
    blocks 
    |> String.concat ", "
    
let parenthesized (txt:string) = sprintf "(%s)" txt

// generate a list of the protective gear worn
let protectiveGear (gear:ProtectiveGear) =
    [
        match gear.Armor with
        | None -> ignore ()
        | Some(armor) ->
            yield
                match armor with
                | Padded -> "padded"
                | Leather -> "leather armor"
                // omitted for brevity
                | Plate -> "plate"
        if gear.Shield then yield "shield"    
    ]

let armorClass (monster:Monster) =
    let ac = Monster.AC monster
    let equipment = 
        // generate list of items to display, if any
        match monster.Protection with
        | Natural(bonus) -> 
            if bonus = 0 
            then [ ]
            else [ "natural armor" ]
        | Equipment(gear) -> protectiveGear gear
        // for a non-empty list, apply formatting
        |> function
        | [] -> ""
        | items -> 
            items 
            |> commaSeparated
            |> titleCase
            |> parenthesized
    sprintf "**Armor Class** %i %s" ac equipment 
```

We can now inject this into our `monsterSheet` function:

``` fsharp
let monsterSheet (monster:Monster) =
    [
        sprintf "# %s" monster.Name |> titleCase      
        monster |> armorClass
        monster.Abilities |> abilities 
    ]
    |> paragraphs
```

The rest of the Markdown generation is more of the same - we won't go into more details. Interested readers can [check the code here][8]. As for the result, this is how our Goblin gets rendered - we are getting somewhere:

# Goblin
_Small Humanoid, neutral evil_  
**Armor Class** 15 (Leather Armor, Shield)  
**Hit Points** 7 (2d6+0)  
**Speed** 30 ft.  
STR | DEX | CON | INT | WIS | CHA  
:---: | :---: | :---: | :---: | :---: | :---:  
8 | 14 | 10 | 10 | 8 | 8  
-1 | +2 | 0 | 0 | -1 | -1  

## Parting Comments

I'll leave it at that for this episode, but I wanted to make a couple of quick comments, because I am not 100% satisfied with the code, which I will probably have to revisit at a later point.

First, the model doesn't cover some of the more obscure rules. Just to give two quick examples:

- some creatures can be used as mounts, which can be outfitted with specific types of armor,
- some creatures were unconventional armor, for instance, Frost Giants wear "Patchwork Armor" (Monster Manual, page 155).

The second issue is the more interesting of the two, in that it brings up the following question: a Discriminated Union is closed by design, so how do you go about handling potential extensions?

Then, the **Armor Class** model is incomplete. It would typically not be an issue for most monsters, but **AC** could also be modified by **Magic Items**. A **Shield**, or, even worse, an item that is neither **Armor** nor **Shield** (such as a Ring of Protection), could provide extra **AC**. In other words, we should refine our model, and attach additional properties to items carried by the Monster.

Speaking of carrying items, there is another notion missing from our model. A Creature could carry an item but not have it equipped. A reasonable example is a **Shield**; one could carry it, but choose not to equip it, so as to use a two-handed weapon. In the context of representing a Monster, it's not a major issue, which is why we will leave it at that for now, but that's also something we will likely revisit later, to better represent the disctinction between what one carries and what has currently equipped, as well as potential constraints on what can be equipped.

As a final thought, one piece I am not entirely happy with is the creation of a variant, by changing the armor of a base monster. Records make that process very easy (`let variation = { original with // whatever changes }`), and I couldn't figure out a way to make anything as smooth around `Protection`, because of the Discriminated Union. If I want to, say, create a Goblin Boss from a Goblin, I have to fully specify his equipment, like so:

``` fsharp
let goblinBoss = {
    goblin with
        Name = "Goblin Boss"
        Protection = Equipment { 
            Armor = Some ChainShirt 
            Shield = true
            }
        // omitted for brevity
```

It is not awful, but it is not pretty, either. I am not sure yet what to do about that one - suggestions welcome!

That's it for today - you can find the current state of affairs described in this post [here on GitHub][8]. Where will the Adventure lead us next time? Nobody knows, not even I - so stay tuned :)

[1]: {{ site.url }}/2018/07/31/give-me-monsters-part-3/
[2]: https://en.wikipedia.org/wiki/Alignment_(Dungeons_%26_Dragons)
[3]: https://en.wikipedia.org/wiki/Creature_type_(Dungeons_%26_Dragons)#5th_edition
[4]: http://media.wizards.com/2016/downloads/DND/PlayerBasicRulesV03.pdf#page=44
[5]: https://roll20.net/compendium/dnd5e/Frog
[6]: https://roll20.net/compendium/dnd5e/Boar
[7]: {{ site.url }}/2018/07/31/give-me-monsters-part-2/
[8]: https://github.com/mathias-brandewinder/MonsterVault/tree/1eb1a28cf63fc7f4597ec8c767f5cd5159033592
