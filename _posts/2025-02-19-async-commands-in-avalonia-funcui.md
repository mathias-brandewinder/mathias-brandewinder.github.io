---
layout: post
title: Async Commands with Avalonia FuncUi
tags:
- F#
- Avalonia
- Elmish
---

Another [Avalonia FuncUI][1] focused post this week! One problem I struggled 
with initially with Avalonia FuncUI is how to handle `async` calls. From past 
experience with Elmish, I was familiar with the [`Cmd.OfAsync`][2] module, and 
wanted to use that if possible (Check out [Maxime Mangel's post on `Cmd`][4] if 
you are interested in some of the things you can do with these!). Anyways, 
using `Cmd.OfAsync` in Avalonia is what we will cover in this installment!  

Without further due, let's dive in, with a very basic example, with nothing 
async to begin with. Our example app will have just a `TextBox`, where the text 
of a "Request" can be entered, and a `Button`, which will send the "Request", 
and return a "Response", a string, which we will display back to our user.  

![simple app with one input and one button]({{ site.url }}/assets/2025-02-19/demo-app.png)

We'll start synchronous, and work our way up to asynchronous commands.  

<!--more-->

## Basic scaffold

First, let's set up that basic app in Avalonia FuncUI.  

``` fsharp
    let respondToRequest (request: string) =
        $"{DateTime.Now}: Request was {request}"

    type State = {
        Request: string
        Response: string
        }

    type Msg =
        | UpdateRequest of string
        | SendRequest

    let init (): State * Cmd<Msg> =
        {
            Request = ""
            Response = ""
        },
        Cmd.none

    let update (msg: Msg) (state: State): State * Cmd<Msg> =
        match msg with
        | UpdateRequest text ->
            { state with Request = text }, Cmd.none
        | SendRequest ->
            let response = respondToRequest state.Request
            { state with Response = response }, Cmd.none
```

Our `State` has 2 fields, `Request`, the request we want to send, and 
`Response`, the response we received back. We have 2 messages to represent our 
user interactions: `SendRequest`, which should be self-explanatory, and 
`UpdateRequest`, to reflect changes the user makes to the "Request".  

`init ()` creates our initial `State`, and `update` takes action based on the 
message received, to update the `State`. In particular, when `SendRequest` is 
received, we take the current `Request`, call the 100% synchronous 
`respondToRequest` function, which gives us back a "Response", a time-stamped 
string, and updates the `Response` field in `State`. Pretty simple.  

How about the UI part? Not too complicated either:  

``` fsharp
let view (state: State) (dispatch: Msg -> unit): IView =
    StackPanel.create [
        StackPanel.children [
            TextBox.create [
                TextBox.watermark "Type your request"
                TextBox.text $"{state.Request}"
                TextBox.onTextChanged (fun text ->
                    text
                    |> UpdateRequest
                    |> dispatch
                    )
                ]
            Button.create [
                Button.content "Send Request"
                Button.onClick (fun _ ->
                    SendRequest
                    |> dispatch
                    )
                ]
            TextBlock.create [
                TextBlock.text state.Response
                ]
            ]
        ]
```

In a `StackPanel`, we create a `TextBox` where our user can type in a Request. 
We bind the contents `TextBox.text` to `State.Request`, to display the current 
state of that value. When the text is changed, we dispatch `UpdateRequest` with 
the current text content.  

We add a `Button`, which dispatches `SendRequest` when pressed, and a 
`TextBlock` to display the current value of `State.Response`, and we are done. 
We have the scaffold of a working app.  

[Gist: code of version 0][3]

## Async Problems

Now imagine that the function `respondToRequest` was slow, or that for whatever 
reason we wanted it to be asynchronous. For illustration purposes, let's say 
that `respondToRequest` looks like this:  

``` fsharp
let respondToRequest (request: string) =
    task {
        // Create an artificial delay
        do! Async.Sleep 1000
        return $"{DateTime.Now}: Request was {request}"
        }
```

> Note: I could have used `async` instead of `task` here. I deliberately chose 
to use `task`, because it will highlight an interesting issue that would not 
show up otherwise.

This immediately breaks `update` here:  

``` fsharp
    let update (msg: Msg) (state: State): State * Cmd<Msg> =
        match msg with
        // omitted
        | SendRequest ->
            let response = respondToRequest state.Request
            { state with Response = response }, Cmd.none
```

Let's attempt something gross first:  

``` fsharp
let update (msg: Msg) (state: State): State * Cmd<Msg> =
    match msg with
    // omitted
    | SendRequest ->
        let response =
            respondToRequest state.Request
            |> Async.AwaitTask
            |> Async.RunSynchronously
        { state with Response = response }, Cmd.none
```

This is gross, because we are throwing away all the benefits we could get from 
`Async`: we are going to wait for the response in the update loop, completely 
blocking the UI with an un-responsive application.  

However, besides aesthetic considerations, this particular example has another 
flaw: it just doesn't work. If you run the code, the application will go in an 
endless loop and become unusable. As I understand it, the problem here is that 
updates need to happen on the UI Thread, but this is not where the response 
returns. At any rate, this we cannot ignore.  

> Note: had we used `async` instead of `task` for our function, the gross 
solution would have worked in this specific case.  

## Using Cmd.OfAsync or Cmd.OfTask

So why did I want to use `Cmd.OfAsync`, or its cousin `Cmd.OfTask`? This module 
has a couple of very useful functions, which allow you to create a `Cmd`, but 
defer its execution without blocking the `update`.  

The specific one I am interested in today is `Cmd.OfTask.perform`. It has a 
bit of an intimidating signature:  

``` fsharp
val inline perform:
   task     : ('a -> Threading.Tasks.Task<'a0>) ->
   arg      : 'a ->
   ofSuccess: ('a -> 'msg)
           -> Cmd<'msg>
```

`Cmd.OfTask.perform` expects 3 things:  
- a `task` function to perform,  
- arguments to be passed to that function,  
- a `Msg` to receive the result of the function evaluation.  

We are missing one thing in our example: a `Msg` to signal that our request has 
completed, and carry the corresponding response. Let's change our code and add 
such a message:  

``` fsharp
type Msg =
    | UpdateRequest of string
    | SendRequest
    | ReceivedResponse of string
```

We change the `update` function accordingly:  

``` fsharp
let update (msg: Msg) (state: State): State * Cmd<Msg> =
    match msg with
    | UpdateRequest text ->
        { state with Request = text }, Cmd.none
    | SendRequest ->
        let deferredCmd =
            Cmd.OfTask.perform
                respondToRequest
                state.Request
                ReceivedResponse
        state, deferredCmd
    | ReceivedResponse response ->
        { state with Response = response }, Cmd.none
```

[Gist: code of version 1][5]

Note how we separated completely starting the request, and completing it. 
`SendRequest` creates a "deferred" command, which will:

- execute `respondToRequest`,  
- passing it `state.Request` as an argument,  
- wrap the response, a `string`, in `ReceivedResponse`,  
- and dispatch that `Msg` to `update` when it is done.  

As a result, the `update` for `SendRequest` is quick - we don't change the 
`State`, all we do is enqueue a `Cmd`, which will run asynchronously, and come 
back to `update` when it's done.  

Does it work? Almost. The last change needed to make it work is to modify the 
part where your Avalonia FuncUI app starts the Elmish main loop, like so, 
replacing `Program.run` with `Program.runWithAvaloniaSyncDispatch ()`:  

``` fsharp
Elmish.Program.mkProgram Main.init Main.update Main.view
|> Program.withHost this
// |> Program.run
|> Program.runWithAvaloniaSyncDispatch ()
```

And... voilà! We are now getting all the benefits of async code, with nice, 
non-blocking updates.  

## Parting thoughts

Not much to add to this, really! I remember `Cmd.OfAsync` as one of these bits
of code which took me a little to digest at first, but that ended up feeling 
very natural quickly. If you haven't come across it before, hopefully this 
example will help you started on the right foot!  

One piece I find unfortunate is that `Program.runWithAvaloniaSyncDispatch ()` 
is not the default mode in Avalonia.FuncUI. It's probably because `Program.run` 
is already defined in Elmish itself. Anyways, it took me a bit to figure out 
that this was the piece I was missing. That gold nugget is carefully buried in 
Github issues, and not very discoverable...

Anyways, that's what I got for today!  

[1]: https://github.com/fsprojects/Avalonia.FuncUI
[2]: https://github.com/elmish/elmish/blob/v4.x/src/cmd.fs#L121-L145
[4]: https://medium.com/@MangelMaxime/my-tips-for-working-with-elmish-ab8d193d52fd
[3]: https://gist.github.com/mathias-brandewinder/991eab4598acae36f613af797a793302#file-version0-fs
[5]: https://gist.github.com/mathias-brandewinder/991eab4598acae36f613af797a793302#file-version1-fs