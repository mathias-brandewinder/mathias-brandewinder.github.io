---
layout: post
title: Converting a DSL to Executable F# Code On-the-Fly, Part 2
tags:
- F#
- DSL
- FParsec
---

In [our previous post][1], we started attacking the following problem: we want our application to take in raw strings, representing code written in our own, custom domain-specific language, and convert them on the fly to F# functions, so that our use can change the behavior of the application at run time. In our particular example, to keep simple, we are simply trying to inject arbitrary functions of the form f(x) = (1 + 2 * x) * 3, that is, functions that take in a float as input, and return a float by combining addition and multiplication.

As a first step, we created an internal representation for our functions, using F# discriminated unions to [model functions as nested expressions][2]. This internal DSL gave us a type-safe, general representation for any function we might want to handle. However, we are still left with one problem: what we want now is to convert raw strings into that form. If we manage to do that, we are done: our user can, for instance, write functions in our own language in a text file, and have the application pick that file and convert it to F# code it can run.

<!--more-->

## Setting up FParsec

To achieve our goal, we are going to use [FParsec][3], an F# parser-combinator library. The general idea behind FParsec goes along these lines:

* create small parsers, functions that recognize and convert simple elements of your custom language in a string of text,
* combine them into larger functions that can process increasingly complex pieces of the language, using built-in combinators.

Rather than go into explaining how and why FParsec works, we will illustrate in this post how to use it as we go, working through our example, progressively introducing useful elements of the library. First, we'll add a reference to the FParsec NuGet package using Paket, and include it in our script:

``` fsharp
#I @"../packages/"
#r @"fparsec/lib/net40-client/fparseccs.dll"
#r @"fparsec/lib/net40-client/fparsec.dll"
open FParsec
```

Next, we will add a "convenience" function in our script, which will allow us to test out "live" if our parsers work the way we expect:

``` fsharp
let test parser text =
    match (run parser text) with
    | Success(result,_,_) -> printfn "Success: %A" result
    | Failure(_,error,_) -> printfn "Error: %A" error
```

Inspecting the signature of `test` is instructive:

```fsharp
val test : parser:Parser<'a,unit> -> text:string -> unit
```

`test` expects a function `parser`, which is expected to recognize / extract a generic type `'a` from a raw string `text`. `test` calls `run`, a built-in FParsec function, which can produce two results. Either

* parsing succeeds, and we get back a `Success`, containing 3 elements, an instance of `'a` and some additional information,
* parsing fails, and we get back a `Failure`, containing 3 elements, the second one being a `ParserError`.

Let's try this out, using [`pfloat`][4], one of the built-in parser functions that ship with FParsec. `pfloat` is a function that parses floats; that is, it will recognize and extract a floating-point number from text:

``` fsharp
test pfloat "1.23"
>
Success: 1.23

test pfloat "abc"
>
Error: "Error in Ln: 1 Col: 1
abc
^
Expecting: floating-point number
"
test pfloat " 1.23"
>
Error: "Error in Ln: 1 Col: 1
 1.23
^
Expecting: floating-point number
"
```

Note how convenient this is: we can try out that function, right from our script, and we immediately get usable error messages, pointing out what went wrong, and where. In the first error case, `pfloat` signals with a little caret symbol `^` that instead of a floating-point number, it found the character `a` in line 1, column 1 of the input. In the second case, it also spots an issue: the string starts with a space. FParsec is not trying to find a match in the entire string, like, for instance:

``` fsharp
open System.Text.RegularExpressions
let pattern = Regex(@"\d+")
pattern.Match "   123   "
```
