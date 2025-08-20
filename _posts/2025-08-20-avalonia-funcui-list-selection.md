---
layout: post
title: Handling list view selection in Avalonia FuncUI
tags:
- F#
- Avalonia
- Elmish
---

After a brief summer hiatus, I am back! I wish this pause was due to 
exciting vacation plans, but unfortunately, the main reason was 
that I had a gas leak in my apartment, which ended up disrupting my routine 
quite a bit. Anyways, I am looking forward to enjoying simple pleasures of 
life like warm showers or home cooking again hopefully soon.  

Today's post is not anything fancy. I have been working on deskop applications 
in F# recently, using [Avalonia FuncUI][1], and getting the `ListBox` to do 
what I wanted it to do was a bit more involved than I expected. This post is 
intended mainly as notes to myself, documenting some of the details that 
tripped me up.  

Today's post will focus on handling selection. I intend to have a follow-up 
post soon, covering dynamic updates. Until that is published, you can take 
a look at the [full code example on GitHub][3].  

## The `ListBox` in Avalonia FuncUI

The `ListBox` in Avalonia is a control intended to display a collection of 
items, and track which item is selected. The [documentation][2] gives a pretty 
good description of its basic usage in FuncUI:  

``` fsharp
ListBox.create [
    ListBox.dataItems [ "Linux"; "Mac"; "Windows" ]
    ListBox.selectedItem state.os
    ListBox.onSelectedItemChanged (fun os -> dispatch ChangeOs)
]
```

- `ListBox.dataItems` expects a collection of Items to display, which would 
typically coming from the `State`,  
- `ListBox.onSelectedItemChanged` tracks changes of selection,  
- `ListBox.selectedItem` drives which Item should visually appear as selected 
in the list.

I will focus only on single-item selection in this post. Multi-selection is 
also supported, but I haven't dug into that very much, because this wasn't 
something I needed. The use case I am after is very basic:  

- Present a list of items to the user in a `ListBox`,  
- Allow the user to edit the item currently selected,
- Highlight the item currently selected in the `ListBox`.  

As it turns out, this was less straightforward than I expected. Let's dig into 
it!  

<!--more-->

## Displaying the Selected Item

The first struggle I had was with handling item selection for "complex" items. 
In the documentation example mentioned previously, the items are simple 
strings. What if our items are more complex entities?  

To simplify the question of identity, I decided to assign a unique ID, a Guid, 
to each item. In this example, we will work with the simplest possible Item, a 
record that looks like this:  

``` fsharp
type Item = {
    Id: Guid
    Name: string
    }
```

Our `State` then has a collection of Items, and maintains which item is 
selected, by tracking the corresponding ID as an `Option<Guid>`, so we can also 
handle the situation where no item is selected:  

``` fsharp
type State = {
    Items: Item []
    SelectedItemId: Option<Guid>
    }
```

We can then add a `ListBox` to the view, like so:  

``` fsharp
let view (state: State) dispatch =
    ListBox.create [
        ListBox.dataItems (state.Items)
        ListBox.selectedItem (
            match state.SelectedItemId with
            | None -> null
            | Some itemId ->
                state.Items
                |> Array.tryFind (fun item -> item.Id = itemId)
                |> function
                    | None -> null
                    | Some item -> box item
            )
        ]
```

The `selectedItem` part tripped me up quite a bit. The issue, as I understand 
it, is that the `ListBox` is not generic, but operates on objects. As an 
example, the signature of `ListBox.selectedItem` offers a hint of that:  

``` fsharp
static member selectedItem: 
    item: obj 
        -> IAttr<'t> (requires :> SelectingItemsControl)
```

As a result, we need to convert our `SelectedItemId`, an `Option<Guid>`, to 
either a `null` if nothing is selected, or `box` the selected `Item` otherwise, 
converting it to a `System.Object`.  

Without boxing, the UI will only reflect the item selected by the user, by 
clicking on items on screen. What boxing buys us is that if we change the 
`SelectedItemId` **on the `State`**, via code, the change will be properly 
reflected visually on the `ListBox`. As an example, in our `init` function, we 
can pre-select the first item of the list on initialization, like so:  

``` fsharp
let init (): State * Cmd<Msg> =
    let items =
        Array.init 10 (fun i ->
            {
                Id = Guid.NewGuid()
                Name = $"Item {i}"
            }
            )
    {
        Items = items
        SelectedItemId = Some (items.[0].Id)
        Filter = ""
    },
    Cmd.none
```

## Changing the Selected Item

In a fashion similar to how we handle highlighting the selected item, we can 
handle changes in selection sending the corresponding ID, an `Option<Guid>`, to 
the `State`. We create a message for that purpose, like so:  

``` fsharp
type Msg =
    | SelectedItemIdChanged of Option<Guid>
    // | ... other messages
```

This allows us to signal that nothing is selected (`None`), or that some ID has 
been selected (`Some itemID`). To signal that the selected item has changed, we 
use `ListBox.onSelectedItemChanged`, which, as in the previous example, expects 
an `object`:  

``` fsharp
static member onSelectedItemChanged:
    func            : (obj -> unit) *
    ?subPatchOptions: SubPatchOptions
        -> IAttr<'t> (requires :> SelectingItemsControl))
```

I might have over-complicated things a little, but below is the code I ended up
with. We check if the selected object is indeed of type `Item`, and if so, if 
its ID is different from the selected one. Otherwise, no message is needed:  

``` fsharp
let view (state: State) dispatch =
    ListBox.create [
        // same as before, omitted for brevity
        ListBox.onSelectedItemChanged (
            (fun selected ->
                match selected with
                | :? Item as selectedItem ->
                    match state.SelectedItemId with
                    | None ->
                        selectedItem.Id
                        |> Some
                        |> SelectedItemIdChanged
                        |> dispatch
                    | Some currentlySelectedId ->
                        if currentlySelectedId <> selectedItem.Id
                        then
                            selectedItem.Id
                            |> Some
                            |> SelectedItemIdChanged
                            |> dispatch
                        else ignore ()
                | _ ->
                    None
                    |> SelectedItemIdChanged
                    |> dispatch
            ),
            SubPatchOptions.Always
            )
        ]
```

The `SubPatchOptions.Always` is possibly un-necessary, but after having been 
bitten a couple of times with closures having unanticipated effects in events, 
I have become a little paranoid!  

## Parting thoughts

Part of me is wondering what it would take to make a generic version of the 
`ListBox` (or other Avalonia controls). In the end, the code I wrote does the 
job, but it feels a bit more noisy than it should.  

Anyways, that's where I will leave things for today! I plan on a follow up 
soon, going over dynamically updating a `ListBox`, to perform actions such as:  

- Adding an Item to the ListBox,  
- Deleting an Item from the ListBox,  
- Changing the name of an Item in the ListBox,  
- Dynamically filtering the contents of the ListBox.  

I am also hoping to follow up with a `TreeView` example. There is just one 
problem - I still haven't gotten it to work the way I want it to :) If the 
`ListBox` was a bit tricky, the `TreeView` feels like the boss fight of working 
with collections within Avalonia FuncUI.  

In the meantime, you can get a preview of what is coming next here, with the 
[full ListBox code example on GitHub][3]. Warning: this repository is my 
playground where I experiment with various controls and explore ideas, so it is 
a little messy, don't judge too harshly!  

[1]: https://funcui.avaloniaui.net/
[2]: https://funcui.avaloniaui.net/controls/listbox
[3]: https://github.com/mathias-brandewinder/Avalonia-FuncUI-Examples/blob/4f0757d6bd20b6909a1295423f8f2a33c4c0b8b1/ListSelection.fs
