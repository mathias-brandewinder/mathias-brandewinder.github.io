---
layout: post
title: Give me Monsters! (Part 5)
tags:
- F#
- DnD
- Domain-Modeling
---

Let's face it, one of the main purposes of Monsters in D&D is to serve as battle fodder for Adventurers. It's time to explore the bottom section of the Monster stats, and talk **Weapons** and **Combat**.

> Warning: I have tried my best to make the contents of this series understandable without too much knowledge of the D&D 5e rules. This post goes into more arcane details than the previous ones, because the rules of combat are pretty intricate, and the details matter. I guess that is unavoidable: anything non trivial domain modeling effort will require diving into nitty-gritty details at some point. 

![Goblin Stat Block]({{ site.url }}/assets/2018-07-23-goblin.png)

From a domain modeling standpoint, this part is a bit messy. We have a sub-section labeled "Actions", but the items listed there are _not_ actions - a **Scimitar** or a **Shortbow** are weapons. To make things even more confusing, right above, we have a section that isn't even labeled, but contains actions - **Nimble Escape** allows the Goblin to take special **Bonus Actions**, **Disengage** or **Hide**.

So... what should we make of this?

<!--more-->

## Combat and Attacks

Let's take a step back. In D&D 5e, when [**Combat** occurs, specific rules apply][2]. During each **Round**, creatures involved take their **Turn**, following **Initiative Order**. During their **Turn**, a creature can **Move**, take one "standard" **Action** (**Hide**, **Dodge**, **Attack**...), and potentially a **Bonus Action**. They can also take a **Reaction** out-of-turn, based on what other creatures do.

As a possible **Action**, a creature can **Attack** another, using either the **Weapons** it has equipped, or some natural ability, for instance, [Bite and Claw attacks for a Black Bear][3], which are represented in the same fashion as Weapons.

In that context, here is what the Goblin stat block is telling us:

- **Nimble Escape** modifies the structure of the default turn, granting Goblins additional actions they can perform,  
- Goblins typically carry a **Scimitar** and a **Shortbow**, which they can use to make an **Attack** as an **Action**.

Today, we will focus on modeling **Attacks** with **Weapons**. Later on, we will look at turns, and ideally, explore whether we can use that to simulate battles, and maybe even identify winning fighting strategies for monsters with a sprinkle of machine learning.

So let's dig deeper into **Attacks** using **Weapons**, starting by an examination of the Goblin sheet. 

The **Scimitar** and **Shortbow** lines both display similar indications, `+4 to hit`, and `Hit: (1d6 + 2)`. These are used to resolve the result of an **Attack**. An **Attack** starts with an **Attack Roll**: roll a d20, add a modifier (in this case, `+4`), and compare it to the **AC** of the target. If the roll is greater or equal to the **AC**, it is a hit, which will cause damage determined by a `1d6 + 2` roll, to be deduced from the targets' hit points.

The two lines also have some differences. The **Scimitar** is marked as a **Melee** attack, that is, close-combat, while the **Shortbow** is a **Ranged** attack, that is, made at a distance. Both define a range (how far the attack can reach), but the **Shortbow** has 2 numbers, `80/320 ft.`, describing the short and long distances for a bow shot. Finally, each weapon deals a different type of damage, **Slashing** vs. **Piercing**.

## Weapon Attacks

Where are all these bits of information coming from?

Let's assume the rules governing Monsters and Adventurers are mostly the same, and look into how an **Attack** gets resolved, in the simple cases. To determine if a **Melee Attack** hits, a d20 roll is rolled, and two modifiers applied: the **STR** modifier, and, if the Adventurer is **Proficient** with the **Weapon** (or type of weapon), the Adventurer **Proficiency Bonus**, which depends on their level. The damage dealt is resolved with a **Damage Roll**, determined by the Weapon itself, to which the **STR** modifier is added. In the case of a **Ranged Attack**, the rules are similar, but use **DEX** instead of **STR**. 

In other words, to determine the result of an attack, we need to know the attacker **Abilities** and their **Level**, whether a **Melee** or **Ranged** **Weapon** is being used, and what the **Weapon** **Damage** is. 

Let's take a stab at coding this, returning the attack bonus and damage roll for an attack:

``` fsharp
let proficiencyBonus level =
    if level <= 4 then 2
    elif level <= 8 then 3
    elif level <= 12 then 4
    elif level <= 16 then 5
    else 6

type Attack = 
    | Melee
    | Ranged

type Weapon = {
    Damage: Roll
    Attack: Attack
    }

let attackModifiers (abilities:Abilities) (level:int) (weapon:Weapon) =
    let hit = 
        proficiencyBonus level 
        +
        match weapon.Attack with
        | Melee -> modifier abilities STR
        | Ranged -> modifier abilities DEX
    let damage = 
        match weapon.Attack with
        | Melee -> weapon.Damage + modifier abilities STR
        | Ranged(_) -> weapon.Damage + modifier abilities DEX
    hit, damage
```

We should now be able to try this out on our Goblin. We have one small issue here, namely that Monsters do not have an explicit **Level** defined. However, as we noted [in a previous episode][4], we could use the number of **Hit Dice** as a proxy, which would be consistent with the rules governing adventurers. Let's see how this works out, assuming a Goblin is proficient with both the Scimitar and the Shortbow:

``` fsharp
let scimitar = {
    Damage = Roll (1,d6)
    Attack = Melee
    }

let shortbow = {
    Damage = Roll (1, d6)
    Attack = Ranged
    }

attackModifiers goblin.Abilities goblin.HitDice scimitar
// val it : int * Roll = (1, Add [Roll (1,D 6); Value -1])

attackModifiers goblin.Abilities goblin.HitDice shortbow
// val it : int * Roll = (4, Add [Roll (1,D 6); Value 2])
```

This is _almost_ correct (or, as less charitable people might put it, it's wrong). We get the expected results for the **Shortbow** (`+4 to hit, hit: 1d6 + 2 damage`), but the **Scimitar** is off. What are we missing?

## More Weapons

To answer this, we will need to dig deeper into **Weapons**. Per the PHB pp 146-147, each [**Weapon** can have multiple properties][4] - let's list a few that are directly relevant to attacks:

- Finesse
- Heavy
- Light
- Thrown
- Two-Handed
- Versatile

In addition to this, the PHB also breaks down weapons between **Simple** and **Martial**, which describes classes of weapons a creature is proficient with.

While Weapon Properties appear in the PHB as a flat list, these are clearly not all on the same level. How should we organize this? One way to approach this is to consider which ones are incompatible with each other - they probably belong to a Discriminated Union - and which are not - they might fit in a Record.

So how can we go about a data model for Monsters and Weapons, to determine the resolution of an attack?

The first issue we'll need to address is that the signature for our earlier `attackModifiers` function won't work, because different attacks are possible with a single **Weapon**. First, a **Weapon** that has the **Thrown** property can be used both for **Melee** and **Ranged** attacks. Then, for a **Melee** **Weapon**, there are options, too - some are **Versatile**, allowing to make attacks with one or two hands, and **Light** **Weapons** can be used for **Two-Weapon Fighting**, using a second weapon **Off-Hand**. 

This is complicated. First things first, a signature along the lines of what we had previously, `Monster -> Weapon -> AttackResult` won't do. We could specify what type of attack we are attempting, but we would need to handle the fact that the attack could be impossible. In that frame, we could try something like `Monster -> Weapon -> AttackType -> AttackResult option`. The angle we will take instead is to generate all the attacks that could be made, that is, someting like `Monster -> Weapon -> AttackResult list`.

One benefit of that approach is that we can now separately generate the list of melee and ranged attacks, each in their own function, and merge them together into a list of all possible attacks. Let's start with **Ranged** attacks, because they are a bit simpler.

As we saw earlier, the **Attack** descriptions share common characteristics; the only difference, from a data structure standpoint, is that a **Ranged** **Attack** has two ranges, while a **Melee** attack only has one. Let's represent the differences with a Discriminated Union:

``` fsharp
[<RequireQualifiedAccess>]
module Weapon = 

    type MeleeInfo = {
        Range: int
        }

    type RangedInfo = {
        ShortRange: int
        LongRange: int
        }

type Attack = 
    | Melee of Weapon.MeleeInfo
    | Ranged of Weapon.RangedInfo
```

Let's look at the common parts next. We discussed earlier the hit bonus and damage roll; in addition, we need to know if the attack is made with one or two hands (we will call that Grip), and the damage type (**Piercing**, **Slashing**, etc...):

``` fsharp
type DamageType = 
    | Acid 
    | Bludgeoning 
    // omitted for brevity

type AttackGrip = 
    | SingleHanded
    | TwoHanded

type AttackInfo = {
    Weapon: string
    Grip: AttackGrip
    HitBonus: int
    Damage: Roll
    DamageBonus: int
    DamageType: DamageType
    }
```

All we have to do now is pull the data we need from the Monster and the Weapon, to fill in the blanks. Let's start fleshing out the **Weapon** part:

``` fsharp
module Weapon = 

    type Proficiency = 
        | Simple 
        | Martial 

    type Grip = 
        | SingleHanded
        | TwoHanded

    type RangedInfo = {
        ShortRange: int
        LongRange: int
        }

    type Usage = 
        | Melee of MeleeInfo
        | Ranged of RangedInfo

type Weapon = {
    Name: string
    Proficiency: Weapon.Proficiency
    Grip: Weapon.Grip
    Damage: Roll
    DamageType: DamageType
    Usage: Weapon.Usage
    }
```

In addition to **Abilities** and **Level**, we need one extra piece of information from the attacker, its proficiency: 

``` fsharp
let rangedAttacks 
    (abilities:Abilities)
    (proficiency:Weapon.Proficiency) 
    (level:int) 
    (weapon:Weapon) =

        let ability = modifier abilities DEX
        let proficiency = 
            match weapon.Proficiency, proficiency with
            | Weapon.Martial, Weapon.Simple -> 0
            | _ -> proficiencyBonus level
        let attackGrip = 
            match weapon.Grip with
            | Weapon.SingleHanded -> SingleHanded
            | Weapon.TwoHanded -> TwoHanded

        match weapon.Usage with
        | Weapon.Ranged(info) -> 
            [
                { 
                    Weapon = weapon.Name
                    Grip = attackGrip
                    HitBonus = ability + proficiency
                    Damage = weapon.Damage
                    DamageBonus = ability
                    DamageType = weapon.DamageType
                }
            ]
            |> List.map (fun attack -> Ranged(info), attack)
        | _ -> []
```

We compute the ability modifier, based on **DEX** for a ranged attack, determine whether the proficienty bonus applies, and whether the attack is one- or two-handed. If the **Weapon** can be used for a ranged attack, we create a list, with a single item describing the attack made, and otherwise we return an empty list.

## Even More Weapons

Are we done with ranged attacks? Well, not quite - we are missing two cases.

First, some weapons, such as a **Spear** or a **Javelin**, have the **Thrown** property, which means that they can be used both for **Melee** and **Ranged** attacks. We will handle this by introducing a third case to `Usage`, `Thrown`, which will combine in a tuple both `RangeInfo` and `MeleeInfo`. This also has implications on the ability bonus: instead of **DEX**, the hit bonus for a **Thrown** **Weapon** uses **STR**.

Well, not quite. Some weapons also have the **Finesse** property. In that case, the attacker can pick either **DEX** or **STR** for the attack roll. We will simply add a `Finesse` property - a `bool` - to the `Weapon`, and update our `rangedAttacks` function:

``` fsharp
module Weapon = 

    // omitted for brevity

    type ThrownInfo = {
        Melee: MeleeInfo
        Ranged: RangedInfo
        }

    type Usage = 
        | Melee of MeleeInfo
        | Ranged of RangedInfo
        | Thrown of MeleeInfo * RangedInfo

let rangedAttacks 
    (abilities:Abilities)
    (proficiency:Weapon.Proficiency) 
    (level:int) 
    (weapon:Weapon) =

        let ability = 
            match weapon.Finesse with
            | true ->  [ STR; DEX ] 
            | false -> 
                match weapon.Usage with
                | Weapon.Thrown(_) -> [ STR ]
                | _ -> [ DEX ]
            |> Seq.maxBy (modifier abilities)
            |> modifier abilities

        // omitted for brevity

        match weapon.Usage with
        | Weapon.Thrown(_,info)
        | Weapon.Ranged(info) -> 
            // omitted for brevity
```

The main change here is that instead of using **DEX** by default, based on the weapon, we extract a list of the abilities we could use, **DEX** and/or **STR**, and select the one that gives us the best damage.

## And Even More Weapons

Now that we have the ranged attacks covered, let's dig into melee attacks, and how they are different.

The first difference is that melee weapons that have the **Versatile** property can be used with one or two hands, dealing more damage in that case. We will follow the same convention as the PHB, and represent a **Versatile** weapon as a single-handed weapon, with an optional two-handed damage roll: 

``` fsharp
module Weapon = 

    type Grip = 
        | SingleHanded of Versatile: Roll option
        | TwoHanded
```

The second difference is that a **Light** single-handed weapon can be used in combination with another light weapon, to perform an **Off-Hand** attack, with a smaller damage bonus. To handle this, we need a few additional elements to describe the **Weapon** and the **Attack**:

``` fsharp
module Weapon = 

    type Handling = 
        | Light 
        | Normal 
        | Heavy 

    type Grip = 
        | SingleHanded of Versatile: Roll option
        | TwoHanded

type Weapon = {
    Name: string
    Proficiency: Weapon.Proficiency
    Handling: Weapon.Handling
    Grip: Weapon.Grip
    Finesse: bool
    Damage: Roll
    DamageType: DamageType
    Usage: Weapon.Usage
    }
    
type AttackGrip = 
    | SingleHanded
    | TwoHanded
    | OffHand
```

Two quick comments here. First, while that term doesn't exist in the rules, we included a `Normal` `Handling` category besides `Light` and `Heavy`. A discriminated union is collectively exhaustive and mutually exhaustive: no matter what the situation, we should be in one and only one of the cases. As it turns out, some weapons are neither light nor heavy, and we need to describe them, too. It's not uncommon for people to describe only how an item is unusual, without naming the "normal" case - watch out for this! The other point perhaps worth noting is how we separated `Weapon.Grip` from `AttackGrip`. On the surface, they might appear as one thing (can a weapon be used with one or two hands), but they appear in slighty different contexts, and forcing them into a single representation would force us to handle cases that should not even be possible.

> Side note: if you are wondering how to handle creatures that have more than 2 hands, per this [RPG StackExchange discussion][5], a creature could wield multiple weapons, but is limited to attacking with at most 2 light weapons. That's one complication avoided!

This is where returning a list of attacks will start paying off, because the same exact weapon could be used to perform 2 different melee attacks - or even 3 in theory, for a **Light** **Versatile** weapon.  

So let's put this together, with a `meleeAttacks` function, displayed below without further comment:

``` fsharp
let meleeAttacks 
    (abilities:Abilities)
    (proficiency:Weapon.Proficiency) 
    (level:int) 
    (weapon:Weapon) =

        let ability = 
            match weapon.Finesse with
            | true ->  [ STR; DEX ] 
            | false -> [ STR ]
            |> Seq.maxBy (modifier abilities)
            |> modifier abilities
        let proficiency = 
            match weapon.Proficiency, proficiency with
            | Weapon.Martial, Weapon.Simple -> 0
            | _ -> proficiencyBonus level

        match weapon.Usage with
        | Weapon.Thrown(info,_)
        | Weapon.Melee(info) -> 
            [
                match weapon.Grip with
                | Weapon.SingleHanded(versatile) ->
                    yield { 
                        Weapon = weapon.Name
                        Grip = SingleHanded
                        HitBonus = ability + proficiency
                        Damage = weapon.Damage
                        DamageBonus = ability
                        DamageType = weapon.DamageType
                        }
                    match versatile with
                    | None -> ignore ()
                    | Some(versatileRoll) ->
                        yield { 
                            Weapon = weapon.Name
                            Grip = TwoHanded
                            HitBonus = ability + proficiency
                            Damage = versatileRoll
                            DamageBonus = ability
                            DamageType = weapon.DamageType
                            }
                    match weapon.Handling with
                    | Weapon.Light -> 
                        yield { 
                            Weapon = weapon.Name
                            Grip = OffHand
                            HitBonus = ability + proficiency
                            Damage = weapon.Damage
                            DamageBonus = min ability 0
                            DamageType = weapon.DamageType
                            }
                    | _ -> ignore () 
                | Weapon.TwoHanded ->
                    yield { 
                        Weapon = weapon.Name
                        Grip = TwoHanded
                        HitBonus = ability + proficiency
                        Damage = weapon.Damage
                        DamageBonus = ability
                        DamageType = weapon.DamageType
                        }
            ]
            |> List.map (fun attack -> Melee(info), attack)
        | _ -> []
```

## Attacks at Last

That is a bit of a wall of code. Fortunately, we are mostly done at that point. All we have to do is to merge all attacks available in a single function, and wire up monsters, to see what attacks they can do with their weapons:

``` fsharp
let attacks 
    (abilities:Abilities)
    (proficiency:Weapon.Proficiency) 
    (level:int) 
    (weapon:Weapon) =
        [
            yield! meleeAttacks abilities proficiency level weapon
            yield! rangedAttacks abilities proficiency level weapon
        ]

type Monster = {
    // omitted for brevity
    HitDice: int
    Abilities: Abilities
    Equipment: Weapon list
    Proficiency: Weapon.Proficiency
    }
    with
    // omitted for brevity
    static member Attacks (monster:Monster) =
        let attacks = 
            attacks monster.Abilities monster.Proficiency monster.HitDice
        monster.Equipment
        |> List.collect attacks
```

... and we are done. Let's try it out:

``` fsharp
let scimitar = {
    Name = "scimitar"
    Proficiency = Weapon.Simple
    Handling = Weapon.Light
    Grip = Weapon.SingleHanded(None)
    Finesse = true
    Damage = Roll (1, d6)
    DamageType = Slashing
    Usage = Weapon.Melee { Range = 5 }
    }

let shortbow = {
    Name = "shortbow"
    Proficiency = Weapon.Simple
    Handling = Weapon.Light
    Grip = Weapon.SingleHanded(None)
    Finesse = false
    Damage = Roll (1, d6)
    DamageType = Piercing
    Usage = Weapon.Ranged { ShortRange = 80; LongRange = 320 }
    }

let javelin = {
    Name = "javelin"
    Proficiency = Weapon.Simple
    Handling = Weapon.Normal
    Grip = Weapon.SingleHanded(None)
    Finesse = false
    Damage = Roll (1, d6)
    DamageType = Piercing
    Usage = 
        Weapon.Thrown ( 
            { Range = 5 }, 
            { ShortRange = 30; LongRange = 120 }
        )
    }

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
    Equipment = [ scimitar; shortbow ]
    Proficiency = Weapon.Simple
    }

let goblinBoss = {
    goblin with
        Name = "Goblin Boss"
        HitDice = 6
        Protection = Equipment { 
            Armor = Some ChainShirt 
            Shield = true
            }               
        Abilities = {
            goblin.Abilities with
                Bonuses = [
                    { Ability = STR; Bonus = 2 }
                    { Ability = CHA; Bonus = 2 }
                    ]
        }
        Equipment = [ scimitar; javelin ]
    }

goblin |> Monster.Attacks
(*
[(Melee {Range = 5;}, {Weapon = "scimitar";
                         Grip = SingleHanded;
                         HitBonus = 4;
                         Damage = Roll (1,D 6);
                         DamageBonus = 2;
                         DamageType = Slashing;});
   (Melee {Range = 5;}, {Weapon = "scimitar";
                         Grip = OffHand;
                         HitBonus = 4;
                         Damage = Roll (1,D 6);
                         DamageBonus = 0;
                         DamageType = Slashing;});
   (Ranged {ShortRange = 80;
            LongRange = 320;}, {Weapon = "shortbow";
                                Grip = SingleHanded;
                                HitBonus = 4;
                                Damage = Roll (1,D 6);
                                DamageBonus = 2;
                                DamageType = Piercing;})]
*)
goblinBoss |> Monster.Attacks
(*
[(Melee {Range = 5;}, {Weapon = "scimitar";
                         Grip = SingleHanded;
                         HitBonus = 5;
                         Damage = Roll (1,D 6);
                         DamageBonus = 2;
                         DamageType = Slashing;});
   (Melee {Range = 5;}, {Weapon = "scimitar";
                         Grip = OffHand;
                         HitBonus = 5;
                         Damage = Roll (1,D 6);
                         DamageBonus = 0;
                         DamageType = Slashing;});
   (Melee {Range = 5;}, {Weapon = "javelin";
                         Grip = SingleHanded;
                         HitBonus = 3;
                         Damage = Roll (1,D 6);
                         DamageBonus = 0;
                         DamageType = Piercing;});
   (Ranged {ShortRange = 30;
            LongRange = 120;}, {Weapon = "javelin";
                                Grip = SingleHanded;
                                HitBonus = 3;
                                Damage = Roll (1,D 6);
                                DamageBonus = 0;
                                DamageType = Piercing;})]
*)
```

This is _almost_ right. We get the same results as the Monster Manual, except for the Goblin Boss Hit Bonus, which we over-estimate by 1 point in every single case. I think the source of the issue is probably the proficiency bonus; I assumed that the number of Hit Dice for a monster played the same role as the Level for an adventurer. This seems to work out in many cases, but I observed the same discrepancy for the Hobgoblin Captain, which also has 6 Hit Dice. I will leave the issue open for now - I still hope somehow that Hit Dice can be mapped to a proficiency bonus, just following a different scale from the one linking level to proficiency for adventurers.

## Parting Words

I will stop here for today - you can find the [code in current state here][6]. We are not done with weapons and attacks, but this was a bit of a dense post, and I need to do some thinking on where to move from here. 

Besides the issue mentioned above, there are a few challenges ahead. First, some monsters use "natural" attacks, such as **Claws** or **Bite**. This is similar to the natural armor issue we discussed [in the previous post][1]. While some creatures can choose which weapon to use, some others can't - it would make no sense for a bear to drop their claws, and pick up a sword to fight. In other words, some creatures have the ability to carry and use equipment, and some do not. I am not sure how to represent this just yet. 

Then, there are some gaps in our model. As an example, some magical weapons deal more than one type of damage, or deal additional damage to specific creatures. This suggests that a richer model for weapon damage is needed, perhaps with a list of conditions and the corresponding damage.

Finally, we ignored one aspect of the rules here. A **Small** creature using a **Heavy** weapon will make an attack roll at a **Disadvantage**. **Advantage** and **Disadvantage** should probably be incorporated in the [model for dice rolls we fleshed out in our 3rd post][4]. However, I didn't feel ready to do so just yet. Given how pervasive dice rolls are in the game, before committing to any design change, I would like to explore more of the domain first, to get a better sense for how this might impact different areas.

In other words, we are far from done! As an intermediate goal, I hope to arrive to a representation of monsters that is good enough for me to simulate battles between various groups of adventurers and monsters, and evaluate how balanced different encounters are. So... stay tuned, more posts will be coming on the topic!

[1]: {{ site.url }}/2018/07/31/give-me-monsters-part-4/  
[2]: http://media.wizards.com/2016/downloads/DND/PlayerBasicRulesV03.pdf#page=69 
[3]: https://roll20.net/compendium/dnd5e/Black%20Bear 
[4]: {{ site.url }}/2018/07/31/give-me-monsters-part-3/  
[5]: http://media.wizards.com/2016/downloads/DND/PlayerBasicRulesV03.pdf#page=45 
https://rpg.stackexchange.com/questions/85132/what-benefit-would-races-with-extra-hands-have
[6]: https://github.com/mathias-brandewinder/MonsterVault/tree/3fbda8c51d2e4fbf48feb9a9eb436238e81ec1fc
