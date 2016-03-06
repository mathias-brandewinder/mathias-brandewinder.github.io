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

## Parsing simple expressions with FParsec

So how do we use this to solve our problem? The `Expression` type we defined earlier gives us a clear path:

``` fsharp
type Expression =
    | X
    | Constant of float
    | Add of Expression * Expression
    | Mul of Expression * Expression
```

We need to recognize 4 cases in our language: a variable X, a constant value, additions and multiplications. Let's start with the low-hanging fruits, the variable and the constants. Constants are straightforward: if we find a floating-point number in our user input, we need to extract it, and wrap it into a `Constant`.

To achieve this, we will use `|>>`, one of the [built-in operators][5], which applies the parser on the left, takes the result, and passes it as an argument to the function on the right, in a fashion somewhat similar to the `|>` operator:

``` fsharp
let parseConstant = pfloat |>> Constant

test parseConstant "123.45"
>
Success: Constant 123.45
```

> If you do not add the test case `test parseConstant "123.45"` to your script, F# will complain about a Value Restriction problem. The issue here is that there is not enough information for F# type inference to determine what types `parseConstant` is supposed to work with. Providing an actual example, as we did, is one way to address this; the other option is to add type annotations.

Great - that's one case covered. The case of variables is fairly easy as well: we need to look for a constant denoted `x` in the text, and if we find it, return `X`, the first case in our discriminated union. By analogy with the previous example, we could look for a string parser, `pstring`, and do something like this:

``` fsharp
let parseVariable = pstring "x"
test parseVariable "x"
>
Success: "x"
```

This doesn't quite work, though - `pstring` recognizes a string, and returns it; we don't care about the string itself, we just want to return `X` when we found "x" in the text. There is another built-in function for that purpose, `stringReturn`:

``` fsharp
let parseVariable = stringReturn "x" X
test parseVariable "x"
>
Success: X
```

In a nutshell, what `parseVariable` does is the following: when it finds the string "x" in the text, it returns `X`.

## Using our basic parser

Now that we can parse 2 of the elements of our expressions, can we do something with it? Let's try. What we can write at that point is a parser which will recognize either a variable, or a constant:

``` fsharp
let parseExpression = parseVariable <|> parseConstant

test parseExpression "123.45"
>
Success: Constant 123.45

test parseExpression "x"
>
Success: X
```

We are using another [combinator][6] here, `<|>`: `parseExpression` will try to apply `parseVariable` first, and if that doesn't succeed, try `parseConstant` next, as the following example illustrates:

``` fsharp
test parseExpression "nope"
>
Error: "Error in Ln: 1 Col: 1
nope
^
Expecting: floating-point number or 'x'
```

All we need to do now is to refactor a bit our earlier code: instead of taking in an `Expression`, `Program.Run` should instead take in a string, and attempt to parse it into an `Expression`. We are not guaranteed that the input will be well-formed, so we need to handle the case where the parser fails:

``` fsharp
type Program () =

    member this.Run (x:float,code:string) =
        match (run parseExpression code) with
        | Failure(message,_,_) ->
            printfn "Malformed code: %s" message
        | Success(expression,_,_) ->
            let f = interpret expression
            let result = f x
            printfn "Result: %.2f" result
```

We can only handle trivial functions for now, but still - progress! At that point, we can pass in arbitrary strings, and attempt to run them:

``` fsharp
let program = Program()

let code = "42"
program.Run(10.0,code)
>
Result: 42.00

let code2 = "x"
program.Run(10.0,code2)
>
Result: 10.00
```

In the first case, we are running the function `f(x)=42.0`, and in the second, `f(x)=x`, evaluating both for `x=10.0`. Our program now accepts raw strings, converts them into expressions, and creates and executes an F# function on the fly. On the one hand, this is definitely going the right direction; on the other hand, the functions we are handling right now are completely trivial. Let's fix that, and extend our parser, so that it handles less uninteresting cases.

## Parsing operations, first take

At that point, I hope that things are starting to make sense, on an intuitive level. We built 2 small parsers for trivial cases, the next step is to expand our parser to handle the 2 missing cases in our `Expression`, `Add of Expression * Expression` and `Mul of Expression * Expression`. Before going all in, we will warm up with a smaller problem, introducing a few more ideas in the process.

Let's start with a limited version of addition, where we ignore nested expressions, and simply support "flat" expressions `add(x,1)` or `add(x,x)`. Here is how we will approach it: we are looking for the string `add`, followed by 2 expressions (either constant or variable), separated by a comma, between parenthesis. If we find this, we want to parse the two expressions, retrieve them inside a tuple, and construct an instance of `Add(expression1,expression2)`.

All the building blocks for this are directly available in FParsec. Let's go inside-out: first, we need to parse 2 expressions, separated by a comma, into a tuple. FParsec has a built-in parser `tuple2`, which takes 2 parsers, and wraps their result into a tuple, like this:

``` fsharp
let parseExpressionsPair =
    tuple2 parseExpression parseExpression
```

This is close, but not exactly what we need - we need to specify that a comma is separating the arguments. What we want to say is "parse an expression, parse a comma (but ignore it), and parse another expression". For this, we'll use yet another built-in operator, `.>>`. This one allows you to combine two parsers, but retain only the result on the left, where the dot is located. Similarly, `>>.` combines two parsers, but keeps only the result from the right-hand side, where the dot is.

Using this operator, we can now fix our parser:

``` fsharp
let parseExpressionsPair =
    tuple2
        (parseExpression .>> pstring ",")
        parseExpression

test parseExpressionsPair "x,42"
>
Success: (X, Constant 42.0)
```

We parse a tuple, using a first parser that looks for an expression followed by a comma (which we ignore), and a second one that just looks for an expression. We can now combine this into a parser for addition:

``` fsharp
let parseAddition =
    pstring "add" >>.
    between
        (pstring "(")
        (pstring ")")
        parseExpressionsPair
    |>> Add

test parseAddition "add(1,x)"
>
Success: Add (Constant 1.0,X)
```

Let's break it down a bit: first, we look for the string "add", and ignore it, parsing what comes next with `>>.`. The built-in `between` function allows us to combine 3 parsers: the first one, `pstring "("`, will parse an opening parenthesis, the second, `pstring ")"`, parses a closing parenthesis, and the third one defines what we are looking for between these two, in this case, a pair of expressions. And... that's it. This will extract the pair of arguments, and send it as a tuple into `Add`. Done.

We could write the parser for multiply the same way; we will refactor a bit, to eliminate some of the blatant code duplication, ending up with this:

``` fsharp
let parseExpressionsPair =
    between
        (pstring "(")
        (pstring ")")
        (tuple2
            (parseExpression .>> pstring ",")
            parseExpression)

let parseAddition =
    pstring "add" >>.
    parseExpressionsPair
    |>> Add

let parseMultiplication =
    pstring "mul" >>.
    parseExpressionsPair
    |>> Mul
```

We can now modify the `Program`, creating first (at least for now) a parser that handles the 2 new cases:

``` fsharp
let fullParser = parseVariable <|> parseConstant <|> parseAddition <|> parseMultiplication

type Program () =

    member this.Run (x:float,code:string) =
        match (run fullParser code) with
        | Failure(message,_,_) ->
            printfn "Malformed code: %s" message
        | Success(expression,_,_) ->
            let f = interpret expression
            let result = f x
            printfn "Result: %.2f" result

let program = Program()

let code = "add(x,42)"
program.Run(10.0,code)
>
Result: 52.00

let code2 = "mul(x,x)"
program.Run(10.0,code2)
>
Result: 100.00
```

[Gist available here][7]

## Parsing nested expressions

We are getting warmer - now we can handle constants, variables, and simple addition and multiplication. However, we are still not supporting our full language: if we pass in a more complex expression, such as `add(x,mul(x,42))`, our program will fail.

The issue here is that our type `Expression` is defined recursively; for example, an expression can be an addition, which is itself formed of 2 sub-expressions: `Add of Expression * Expression`. However, our parser is currently not recursive: `parseExpression` is handling only variables or constants. The tricky part is that to correctly define `parseExpression`, we need to define beforehand in code `parseAddition` and `parseMultiplication` - but to correctly define `parseAddition`, we also need to already have a definition for `parseExpression`.

So... what do we do?

FParsec handles this with an intimidatingly named function `createParserForwardedToRef ()`. That function allows us to declare the parser we need, `parseExpression`, but to defer its implementation, by creating an empty ref cell which will contain the actual implementation, to be filled in later. Once that is done, calls to the parser will be forwarded to that implementation.

In our case, before doing anything else, we define the full `parseExpression` parser, and declare that its actual body will be found in `implementation`, a mutable ref cell that holds nothing at the moment:

``` fsharp
let parseExpression, implementation = createParserForwardedToRef ()
```

We can then define `parseMultiplication` using `parseExpression`, but instead of the `fullParser` we had before, we can now fill in the actual implementation, which will receive the calls from `parseExpression`:

``` fsharp
implementation := parseVariable <|> parseConstant <|> parseAddition <|> parseMultiplication
```

And this time, we are really done. We can now run arbitrarily complex expressions in our program, like this:

``` fsharp
type Program () =

    member this.Run (x:float,code:string) =
        match (run parseExpression code) with
        | Failure(message,_,_) ->
            printfn "Malformed code: %s" message
        | Success(expression,_,_) ->
            let f = interpret expression
            let result = f x
            printfn "Result: %.2f" result

let program = Program()

let code = "add(x,mul(x,42))"
program.Run(10.0,code)
>
Result: 430.00
```

[Gist available here][8]

## Conclusion

When we started this post, our goal was to enable our users to write code in a DSL, and convert it to executable F# code on the fly, to change the behavior of our application at run time. It took us about 60 lines of F#, but we did it!

Let's briefly recap the process we followed:

* define an external DSL for our user
* parse it into an internal F# representation, using Discriminated Unions,
* process it using an F# interpreter

The example we used was rather simple; however, it would be pretty easy to extend it from here, to support a variety of operations, such as min/max, or exponential. I specifically picked a DSL that was simple to parse, in that it support only pairs of arguments. A more natural DSL would perhaps handle arbitrary lists, such as `add(1,X,mul(x,x,x))`, or even better, `(x*x*x)+x+1`. This is feasible, but a bit more intricate - I chose to keep the example simple, to illustrate the whole process end-to-end, without getting bogged down into too many annoying side-tracks. If you are interested in seeing more elaborate examples, I recommend taking a look at [@TheBurningMonk](https://twitter.com/theburningmonk) wonderful [Random Arts Bot][9] project, and at [@ptrelford](https://twitter.com/ptrelford) amazing series [building and extending Small Basic][10], which provides a working example of implementing a full "serious" language.

Finally, the whole exercise got me thinking quite a bit about DSLs in general. The first interesting tension I see at play is between "internal" and "external"; in our case, the F# representation for expressions is actually quite good. It's not quite what a human would write, but on the flip side, we get tooling, static types, and we can directly use .NET, which are significant benefits. By contrast, the external DSL can be made much more human-friendly: for instance, we can simply type add(4,1.0), which is obviously less annoying than Add(Constant(4.0),Constant(1.0)) - but as we create a brand-new language, instead of a "dialect" of an existing one, we are left quite naked, with no tools or support. Furthermore, my experience so far has been that defining a language that can be parsed easily is much more intricate than one might think. At what point do the benefits of that language outweigh the cost?

Along similar lines, I think FParsec itself is an interesting case. FParsec is a DSL - it is F#, but then it isn't, you have to learn its operators and constructs. The library is beautifully designed, but it also comes with the cost of learning its own dialect. What makes it worth it is I believe the fact that the domain it targets is sufficiently narrow that it doesn't require too much new vocabulary to learn, and sufficiently general that it fits the problem of many users.

At any rate, I hope there was something for you in this series! This was an interesting exercise for me, in that the approach was not something I was familiar with. This comes directly from an actual problem I had to solve on a project, and, once I got over the initial fumbling around phase, it was quite surprising how much I could achieve with very little code, and how easy solving a seemingly hard problem turned out to be. Hopefully, this will inspire you to try it out, and help you get started :)

[1]: http://brandewinder.com/2016/02/20/converting-dsl-to-fsharp-code-part-1/
[2]: https://gist.github.com/mathias-brandewinder/4c6fb72748becf2e930b
[3]: http://www.quanttec.com/fparsec/
[4]: http://www.quanttec.com/fparsec/reference/charparsers.html
[5]: http://www.quanttec.com/fparsec/reference/parser-overview.html
[6]: http://www.quanttec.com/fparsec/reference/primitives.html
[7]: https://gist.github.com/mathias-brandewinder/4c6fb72748becf2e930b
[8]: https://gist.github.com/mathias-brandewinder/4c6fb72748becf2e930b
[9]: http://theburningmonk.com/2016/01/building-a-random-arts-bot-in-fsharp/
[10]: http://trelford.com/blog/post/parser.aspx
