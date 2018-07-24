---
layout: post
title: Give me Monsters! (Part 1)
tags:
- F#
- DnD
- Domain-Modeling
---

I have been going through a bit of coding demotivation lately. Nothing dramatic, I simply did not feel like writing code, and most of my creative energy has gone into other activities, most notably Dungeons & Dragons (D&D in short).

And then, unexpectedly, I got excited again. Long story short, I take my new Dungeon Master duties seriously, and have been spending quite a bit of time preparing the campaign for my Adventurers. For those of you not familiar with D&D, the game works along these lines: a group of Adventures (the players) are immersed in a fictional universe (think Lord of the Rings), where they can decide to do whatever they please. One person plays the role of the Dungeon Master (or DM), responsible for the universe around them, constructing an (hopefully) engaging storyline, narrating events, reacting to the Adventurers' choices and resolving their outcomes based on a [fairly dense rule set][1].

So what does this have to do with programming?

<!--more-->

In essence, D&D is about story-telling. However, keeping a story flowing while simultaneously making sure the rules are followed can be challenging. As a result, I have been digging deep in the manuals, trying to deconstruct them and get a good understanding of the underlying logic. Within that larger context, I have been thinking quite a bit about how to create fun encounters with monsters. I nearly wiped out my Adventurers within their first 30 minutes, because the monsters they encountered were too strong; I over-compensated later on, and gave them under-powered foes. Neither situation is satisfying: a good battle should be challenging, but, if the Adventurers make reasonable decisions, it should not be impossible to survive.

Preparing balanced encounters by hand is complex and tedious, so I started to wonder if I could encode the rules, to help me focus on the story part, without getting too bogged down by the mechanical aspects.

And, as I started playing with the idea, three things happened. First, I had fun coding again! Then, I realized that this was a rather interesting domain modeling problem, perhaps less far from conventional business modeling than it appears. And finally, other people seemed interested as well:

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">Because I really have nothing better to do with my life, I started coding the D&amp;D monsters creation rules in F#. It&#39;s a fun - and non-trivial - domain modeling exercise!</p>&mdash; Mathias Brandewinder (@brandewinder) <a href="https://twitter.com/brandewinder/status/1020386786663469056?ref_src=twsrc%5Etfw">July 20, 2018</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

So... as I am just getting started on this, I figured I could just try and publicly document my efforts at modeling monster creation as I progress. I don't know yet how the final result might look like, I will probably fumble along the way, but, in the spirit of Dungeons & Dragons, the fun is in the adventure iteself more than in its result, so... let's do this! 

## Monster Stats Block

Where do we start? We won't start in the traditional smoke-filled, dimly lit tavern as a starting point; instead we will focus on the monster stats block, which summarizes the description of a monster, from a mechanical standpoint:

![Goblin Stat Block]({{ site.url }}/assets/2018-07-23-goblin.png)

[Goblin Stat Block on the Roll20 Compendium][2]

Every monster, in the canonical rules, is represented following that general structure. At a high level, the document is broken down in sections:

- a minimal "verbal" description of the monster ("a goblin is a small humanoid, with an evil neutral **Alignment**"),
- some combat-related characteristics (**Armor Class**, **Hit Points** and **Movement**),
- the creature 6 **Abilities**,
- a list of "skills" / characteristics, and a description of the monster danger level, the Challenge Rating (CR),
- a separate list of "skills" (in this case **Nimble Action**),
- a list of **Actions** that it can take in combat, typically attacks.

I used **Bold** here to denote terms that have a well-defined meaning in the rules, and "quotes" for terms I use loosely.

Let's make a couple of comments here.

First, while every monster in the canon follows a similar structure, some parts differ slightly from monster to monster. As an example, the "skills" section for the Goblin lists **Skills** and **Senses**. [Other monsters][3] might include additional sections, such as **Vulnerabilities**, and might not include some others (Skeletons have no **Skills** listed, for instance).

Spotting irregularities is important when modeling a domain; assuming they are not mere accidents, they indicate something we are missing to understand the underlying model. Is there a reason for the irregularity here?

My interpretation is the following: every monster shares the same set of underlying "skill classes" (for the lack of a better word at that point). They all have a list of skills, senses, vulnerabilities and whatnot, but when a particular list is empty, rather than waste space rendering an empty list, the category is omitted altogether in the stat block. In other words, for a given monster, the stat block displays only the characteristics that differ from the norm, and omits everything else.

Similarly, while typically monsters only have **Actions**, some also have **Reactions**, and, presumably, **Bonus Actions**, in a fashion similar to Adventurers.

This is reasonable: after all, Adventurers and Monsters are both creatures living in the same world, governed by the same rules. What makes a hero or a monster is in the eye of the beholder. Practically, what this means is that if we are to reconstruct the rules that govern monsters, we will likely end up reconstructing the same rules used for character creation. Which brings up another irregularity: while players have a level, there is no such notion for monsters; Conversely, monsters have a Challenge Rating, with no equivalent for adventurers. What should we make of that?

What is the moral of the story so far? From our observation of stat blocks, which is a representation / projection of what we are interested in (the monster), we noted some irregularities in the structure. The stat block implicitly embeds the same rules used to create characters - which we will have to replicate - and highlights only the specific traits of each monster. To reconstruct the implicit ontology (if that words means what I believe it does!), we will have to inspect monsters as different as possible. There is also plenty of language ambiguity, as indicated by my use of "quoted text". What appears to be sections in the document seem to mix and match elements of different nature, with no obvious name to bind them together.

Next time, we'll begin diving into actual code; and, given the potentially problematic areas identified so far, we'll start by the easier parts and warm up with the pieces that appear reasonably simple - namely, the **Abilities** section. If you want to take a sneak peak, you can already [take a look at what's in the repository at that point][4]!

[1]: http://dnd.wizards.com/articles/features/basicrules
[2]: https://roll20.net/compendium/dnd5e/Monsters:Goblin/#pageAttrs
[3]: https://roll20.net/compendium/dnd5e/Monsters:Skeleton/#pageAttrs
[4]: https://github.com/mathias-brandewinder/MonsterVault/tree/69eefde247928f5d22132733e302b29cdd02d9c1
