---
layout: post
title: Wonderland Katas, F# style
tags:
- F#
- Clojure
- Katas
- Unquote
- Property-Based-Testing
---

A couple of days ago, I stumbled across the [Wonderland Clojure Katas](https://github.com/gigasquid/wonderland-clojure-katas), by [@gigasquid](https://www.twitter.com/gigasquid). It's a wonderful project, with 7 independent coding exercises, inspired by Lewis Carrol's "Alice in Wonderland". I love that type of stuff, and saw that [@byronsamaripa](https://twitter.com/byronsamaripa) had already made a [Scala port](https://github.com/bsamaripa/Wonderland-Scala-Katas), so I figured, why not port it to F#?

<!--more-->

As it happens, I had to travel to Seattle this week; this gave me enough idle airplane time to put together a [first version here](https://github.com/mathias-brandewinder/wonderland-fsharp-katas). I also had a chance to chat with [@tomaspetricek](https://twitter.com/tomaspetricek) and [@reedcopsey](https://twitter.com/reedcopsey), which always helps - thanks for the great input, guys :)

I am sure improvements can be made, but it's good enough to ship, so... let's ship it. I have only solved a couple of Katas myself so far, and focused mainly on getting the infrastructure in place. I tried to stay true to the spirit of the original project, but at the same time, F# and Clojure are different, so I also made some changes, and figured it might be interesting to discuss them here. I'd love to hear feedback, so try it out, and let me know what you think, and how to make it better!

## Overall structure

The Clojure version is organized in separate projects, one per Kata, each with source code and a separate test suite. This is perfectly reasonable, and I considered the same organization, but in the end, opted for something a bit different. When exploring some code in F#, I tend to work primarily in the scripting environment, so I decided to collapse the code and tests in one single script file for each Kata. This is a TDD-inspired pattern I often follow: I simply write my assertion in the script itself, without any testing framework, and get to work. As an example, for the alphabet cipher, I would start with something like this:

``` fsharp
let encode key message = "encodeme"
encode "scones" "meetmebythetree" = "egsgqwtahuiljgs"
```

... and then proceed from there, implementing until it works, that is, until the assertion evaluates to true when I run the script.

Given that most of the Katas come with a test suite pre-implemented, sticking to simple assertions like this would have been a bit impractical. Rather than implement my own crude testing function, I decided to use [Unquote](https://github.com/swensensoftware/unquote), and included a test suite in each script, using the following pattern:

``` fsharp
#r @"../packages/Unquote/lib/net45/Unquote.dll"
open Swensen.Unquote

let tests () =

// verify encoding
test <@ encode "vigilance" "meetmeontuesdayeveningatseven" = "hmkbxebpxpmyllyrxiiqtoltfgzzv" @>
test <@ encode "scones" "meetmebythetree" = "egsgqwtahuiljgs" @>

// run the tests
tests ()
```

That way, the only thing you need to do is change the code that sits on the top section of the script, select all, and execute. tests () will run the tests, producing outputs like:

``` fsharp
Test failed:

encode "vigilance" "meetmeontuesdayeveningatseven" = "hmkbxebpxpmyllyrxiiqtoltfgzzv"
"encodeme" = "hmkbxebpxpmyllyrxiiqtoltfgzzv"
false

Test failed:

encode "scones" "meetmebythetree" = "egsgqwtahuiljgs"
"encodeme" = "egsgqwtahuiljgs"
false
```

The upside is, the whole code is in one place, and Unquote produces a nice analysis of what needs to be fixed. The downside is, you have to run the tests manually, without any pretty test runner, and I had to take a dependency, managed with [Paket](https://fsprojects.github.io/Paket/). I think it's worth it, especially because I am considering changing some of the tests to use property-based testing with [FsCheck](https://fscheck.github.io/FsCheck/), but if you have opinions on making this simpler or better, I'd love to hear it.

## Types

The other main difference with the Clojure original revolves around types. In some cases, this was necessary, just to "make it work". As an example, the card game war Kata uses a card deck, which in Clojure is defined in a couple of lines:

``` clojure
(def suits [:spade :club :diamond :heart])
(def ranks [2 3 4 5 6 7 8 9 10 :jack :queen :king :ace])
```

The F# side requires slightly heavier artillery, because I can't just mix-and-match integers and "heads":

``` fsharp
type Suit =
  | Spade
  | Club
  | Diamond
  | Heart

type Rank =
  | Value of int
  | Jack
  | Queen
  | King
  | Ace

type Card = Suit * Rank
```

In this particular case, the lightness of Clojure is clearly appealing. In other cases, though, I deliberately changed the model, to get some benefits out of types. The best example is the fox, goose, bag of corn Kata. The Clojure version represents the world like this:

``` clojure
(def start-pos [[[:fox :goose :corn :you] [:boat] []]])
```

We have 3 vectors, representing who is currently on the left bank of the river, the boat, and the right bank of the river. This works, and I had an initial F# version that was essentially the same, using 3 sets to represent the 3 locations. However, this required writing a few annoying tests to validate whether states where possible. I am lazy, and thought this would be a good place to use types, so I took the liberty to modify the domain this way:

``` fsharp
type Location =
  | LeftBank
  | RightBank
  | Boat

type Positions = {
  Fox:    Location
  Goose:  Location
  Corn:   Location
  You:    Location }
```

This is a bit heavier than the Clojure version, but quite convenient. First, I am guaranteed that my goose can be in one and only one place at a time. Then, positions are fairly easy to decipher. Finally, checking that the Goose is safe, for instance, simply becomes

``` fsharp
let gooseIsSafe positions =
(positions.Goose <> positions.Fox)
|| (positions.Goose = positions.You)
```

Long story short: I really enjoyed the exercise of taking the Clojure representation, and rewriting it as I would with my F# hat on. In some cases, the 2 versions are virtually identical. The alphabet cipher, or wonderland number, for instance, differ only because of the added type annotations. They could be removed, but I thought they made the intent more obvious:

In other cases, F# types introduced a bit of verbosity, sometimes with clear benefits, sometimes less obviously so.

## Tests

In a totally different direction, going through the unit tests was a fun exercise. Tests tend to bring out the inner, closet mathematician in me, with questions such as ‘does a solution exist’, and ‘is the solution unique’? This was no exception, and I caught myself repeatedly asking these questions.

Let's start with a simple one: is there a wonderland number at all? And might there be more than one? Of course, this is rather silly. In general, I think it's safe to assume that the Kata has not been created to trick me. Checking that there is at least a solution is rather quick, and scanning all possible 6-digit numbers isn't too bad either. However... if I were to generalize this, and search for, say, a wonderland with 50 digits, what should the signature be? Should it be an option, or a (possibly empty) list of integers, assuming I could have more than one?

Perhaps more interesting: in the doublets case, how do I know that doublets ("head", "tail") = ["head"; "heal"; "teal"; "tell"; "tall"; "tail"] **IS** the right solution? And what if I had multiple possible doublets? Should I prefer a shorter doublet to a longer one? If we swapped the words source to a larger dictionary, for instance, we could well end up with a different, shorter solution, and our test would break. A possible approach around that issue would be to use property-based testing, checking for an invariant along the lines of:

>"if doublets returns a non-empty solution, each pair should differ by exactly one character"

However, a trivial implementation then would be "always return an empty list". Don't even try to return doublets - do nothing, and you will never be wrong! It's a very efficient implementation, but it's clearly not very satisfying. I am actually not entirely sure how one should go about writing a good test suite, to cover the case of an arbitrary source of words. Perhaps generate words such that there is a unique shortest doublet, and words with no doublets?

## Parting words

First, big thanks to [@gigasquid](https://www.twitter.com/gigasquid) for creating the original Clojure project; it's an awesome idea, and I had a great time digging into it. Reading through the Clojure code was quite interesting, and rekindled my interest in learning a LISP-family language. In 2016, I will learn Racket!

Then, big thanks again to [@tomaspetricek](https://twitter.com/tomaspetricek) and [@reedcopsey](https://twitter.com/reedcopsey) for discussing the code with me, it was both helpful and fun! And I hear this may or may not have inspired Tomas to try something awesome, looking forward to what might come out of it...

Again, this is work in progress; I still haven't solved the Katas, and might change a couple of things here and there as I do so. [@isaac_abraham](https://twitter.com/isaac_abraham) suggested to provide some indication as to which Katas might be easier than others, I'll add that as soon as I go through them. If you have suggestions or comments, about the code, the setup, or anything that might help make this better or more accessible, feel free to ping me on Twitter, or to simply send a pull request or issue on Github. Until then, hope you have fun with it!
