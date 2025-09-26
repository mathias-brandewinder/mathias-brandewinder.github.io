---
layout: post
title: Editing a list in Avalonia FuncUI
tags:
- F#
- Avalonia
- Elmish
---

In my [previous post][1], I took a look at handling the selected item in an 
[Avalonia ListBox with FuncUI][2], so the ListBox properly reflects what item 
is currently selected, based on the current `State`. In this post, I will go 
into another aspect of the ListBox that gave me some trouble, handling dynamic 
updates to the list of items. Once again, this post is nothing particularly 
fancy, and is mainly intended as notes to myself so I can remember later some of 
the steps I took.  

First, what do I mean by dynamic updates? The [examples in the FuncUI docs][2] 
go over displaying a list of items that do not change. However, in many real 
world applications, you would want to be able to change that list, in a couple 
of different ways:  

- adding or removing an item,  
- editing the selected item,  
- filtering the contents of the list.  

While editing an item is not particularly complicated in general, and follows 
the standard Elmish / MVU pattern, one case that tripped me up was editing an 
item in a fashion that impacts how it is rendered in the list, such as changing 
the display name of the item. I will go over the solution I landed on, but I am 
not sure this is the best way to do it, so if anybody can suggest a better 
approach, I would be very interested in hearing about it!  

Anyways, let's dig into it, and build a simple example illustrating all of 
these features. The final result will look something like this, and, in case 
you are impatient, you can find the [full code example here][4].

![A dynamic ListBox, with add, delete, edit and filter items]({{ site.url }}/assets/2025-09-26/dynamic-listbox.png)

We'll start from [where we left off last time][1], 
with a `State` that contains a collection of Items, and the currently 
selected item:  

``` fsharp
type Item = {
    Id: Guid
    Name: string
    }

type State = {
    Items: Item []
    SelectedItemId: Option<Guid>
    }
```

<!--more-->
## Adding and Removing items

Let's start with adding and removing items to the `State`. First, we will need 
messages for this:  

``` fsharp
type Msg =
    | SelectedItemIdChanged of Option<Guid>
    | CreateItem
    | DeleteItem of Guid
```

The corresponding `update` of the `State` is fairly straightforward:  

``` fsharp
let update (msg: Msg) (state: State): State * Cmd<Msg> =
    match msg with
    | SelectedItemIdChanged selection ->
        { state with
            SelectedItemId = selection
        },
        Cmd.none

    | CreateItem ->
        let item = {
            Id = Guid.NewGuid()
            Name = "NEW ITEM"
            }
        { state with
            Items =
                state.Items
                |> Array.append (Array.singleton item)
            SelectedItemId = Some item.Id
        },
        Cmd.none

    | DeleteItem itemID ->
        { state with
            Items =
                state.Items
                |> Array.filter (fun item -> item.Id <> itemID)
            SelectedItemId = None
        },
        Cmd.none
```

When creating an `Item`, we simply pre-pend it to the list, and set the 
`SelectedItemId` to the corresponding `Id`, so it will be selected by default. 
When deleting an `Item`, we filter out the corresponding `Id` from the list, 
set the selection to `None`, and we are done.  

What about the view? By definition, a new item does not belong to the list yet. 
Let's add a button at the top of the list to create items:  

``` fsharp
let view (state: State) dispatch =
    DockPanel.create [
        DockPanel.children [

            TextBlock.create [
                TextBlock.dock Dock.Top
                TextBlock.text "Items"
                TextBlock.fontSize 16
                ]

            Button.create [
                Button.dock Dock.Top
                Button.content "Create New"
                Button.onClick (fun _ ->
                    CreateItem
                    |> dispatch
                    )
                ]

            ListBox.create [
                // same as before
                ]
                // We assign a unique key each time,
                // forcing a refresh of the ListBox.
                |> View.withKey (Guid.NewGuid().ToString())
            ]
        ]
```

Note the usage of `View.withKey` after `ListBox.create`. Without that piece of 
code, the UI freezes when an item is added to `State.Items`. Why is that piece 
necessary? I am not sure. The issue disappears if we do not set the 
`SelectedItemId` in the `update` function, so I suspect this triggers an 
infinite update loop somehow. Anyways, adding `View.withKey` fixes the issue. 
As I understand it, `View.withKey` assigns an explicit key to the corresponding 
UI element, so the view element gets redrawn when the key changes, instead of 
checking for changes in the backing `State`. In our example, we assign a new 
`Guid` as a key, which is a hack: anytime the `view` is called, a new key is 
created, and the `ListBox` is re-drawn from scratch. This is clearly not pretty 
and might also not be a great idea performance-wise, but... that's the only way 
I found to achieve my goal.  

How about deletions? We could add a button at the top of the list, in a fashion 
similar to what we did for additions, and delete the selected `Item` that way. 
However, we will do something else instead, and add a Delete button to the 
`Item` displayed in the `ListBox` instead, which reduces the interactions needed.  

Let's do that, with a `DataTemplate` in the `ListBox`:  

``` fsharp
ListBox.create [
    // Omitted, same as before
    ListBox.itemTemplate (
        DataTemplateView<Item>.create(fun item ->
            DockPanel.create [
                DockPanel.children [
                    Button.create [
                        Button.dock Dock.Right
                        Button.fontSize 8
                        Button.content "X"
                        Button.onClick (
                            (fun _ ->
                                item.Id
                                |> DeleteItem
                                |> dispatch
                            ),
                            SubPatchOptions.Always
                            )
                        ]
                    TextBlock.create [
                        TextBlock.text $"{item.Name}"
                        ]
                    ]
                ]
            )
        )
    ]
```

The `DataTemplateView` allows us to define a template and apply it to each 
`Item` in the list, creating a "custom" view to render the list elements. We 
could (and probably should) extract that view into a separate function, but for 
the sake of simplicity, we won't do so here.  

And with that we are done! We have a `ListBox`, bound to an `Item` collection 
on the `State`, with proper selection and the ability to add and delete items.  

## Editing Items

Now that we can add / remove / select Items, let's look into editing them. 
First, we need something to edit, so we will expand our `Item` and add a 
`Description` field, a `string`, and make the corresponding changes to the 
code:  

``` fsharp
type Item = {
    Id: Guid
    Name: string
    Description: string
    }
```

We can now create a basic view for the selected item:  

``` fsharp
module SelectedItem =

    let view (item: Item) dispatch: IView =
        DockPanel.create [
            DockPanel.children [
                StackPanel.create [
                    StackPanel.children [
                        TextBlock.create [
                            TextBox.text item.Name
                            ]
                        TextBox.create [
                            TextBox.text item.Description
                            ]
                        ]
                    ]
                ]
            ]
```

... and bolt that view to the main view, on the right of the `ListBox`:  

``` fsharp
let view (state: State) (dispatch: Msg -> unit): IView =
    // main dock panel
    DockPanel.create [
        DockPanel.margin 10
        DockPanel.children [
            // left section: item selector
            Border.create [
                Border.dock Dock.Left
                Border.width 200
                Border.child (
                    Selector.view state dispatch
                    )
                ]
            // left section: end

            // right section: selected item
            Border.create [
                Border.child (
                    state.SelectedItemId
                    |> Option.bind (fun selectedItemID ->
                        state.Items
                        |> Array.tryFind (fun item ->
                            item.Id = selectedItemID
                            )
                        )
                    |> function
                    | None ->
                        TextBlock.create [
                            TextBlock.text "Select an Item"
                            ]
                        :> IView
                    | Some item ->
                        SelectedItem.view item dispatch
                    )
                ]
            // right section: end
            ]
        ]
```

All we need at that point is to propagate name or description changes, which is 
easily done. First, we add 2 new messages:  

``` fsharp
type Msg =
    // omitted, same as before
    | NameChanged of string
    | DescriptionChanged of string
```

Next, we modify the `update` function accordingly:  

``` fsharp
let update (msg: Msg) (state: State): State * Cmd<Msg> =
    match msg with
    // omitted, same as before
    | NameChanged name ->
        match state.SelectedItemId with
        | None -> state, Cmd.none
        | Some selectedId ->
            let items =
                state.Items
                |> Array.map (fun item ->
                    if item.Id = selectedId
                    then { item with Name = name }
                    else item
                    )
            { state with Items = items },
            Cmd.none
    | DescriptionChanged description ->
    // omitted, similar to above
```

And finally, we emit messages via events in the view:  

``` fsharp
module SelectedItem =

    let view (item: Item) dispatch: IView =
        DockPanel.create [
            DockPanel.children [
                StackPanel.create [
                    StackPanel.children [
                        TextBox.create [
                            TextBox.text item.Name
                            TextBox.onTextChanged (fun text ->
                                text
                                |> NameChanged
                                |> dispatch
                                )
                            ]
                        TextBox.create [
                            TextBox.text item.Description
                            TextBox.onTextChanged (fun text ->
                                text
                                |> DescriptionChanged
                                |> dispatch
                                )
                            ]
                        ]
                    ]
                ]
            ]
```

And we are done! We can now change the name or description, with the name 
displayed in the ListBox updating live as we type, while retaining the selected 
item.  

## Dynamic filtering

One last thing for the road. Suppose that, instead of always showing all the 
items in the list, we wanted to be able to search or filter. How could we go 
about that?  

Let's add a simple version in our example, allowing users to search for 
items whose name contain certain substrings. To do that, we will add a 
`TextBox` to the UI, and filter down dynamically the items displayed in the 
`ListBox` based on whether or not they match the search string entered in the 
`TextBox`.

First, let's modify the `State`, and add a `SearchString` field, as well as a 
property `VisibleItems`:  

``` fsharp
type State = {
    Items: Item []
    SelectedItemId: Option<Guid>
    SearchString: string
    }
    with
    member this.VisibleItems =
        this.Items
        |> Array.filter (fun item ->
            item.Name.Contains this.SearchString
            )
```

We need to track down changes made to the search string, let's add a Message 
for that:  

``` fsharp
type Msg =
    // omitted, same as before
    | SearchStringChanged of string
```

We can now add a `TextBox` above the `ListBox`, where the use can enter their 
search string, and, in a fashion similar to what we 
did for the `Item` Name and Description, we can handle that message in the 
`update` function. All that is left to do then is to bind the `ListBox` to the 
`State.VisibleItems`, instead of the raw Items collection:  

``` fsharp
ListBox.create [
    ListBox.dataItems (state.VisibleItems)
    // omitted, same as before
    ]
```

... and we are done! As you type a search string in the `TextBox`, the list of 
items on display adjusts on the fly, retaining only items with a matching name. 

## Parting thoughts

Getting a `ListBox` to behave the way I wanted it, properly maintaining the 
selected item highlighted, and handling editions, took me a bit of effort. The 
example I walked through details some of the steps I had to take to make it 
work, and it mostly works.  

One minor issue I could not resolve is that when the list is long enough to 
require scrolling, selecting and editing an item way down the list 
causes an annoying flicker, and resets the scrollbar so the selected item 
becomes the last one visible in the list. I think the issue is that the entire 
list gets re-drawn when an edit occurs, losing the state of the scrollbar, 
causing it to scroll down just enough for the selected item to be visible. This 
is not the end of the world, but it is visually jarring. One direction I 
haven't tried that could maybe help address it is using keys on the Item itself, 
perhaps tracking some unique version any time the selected item changed. If 
someone knows of a better way to handle this, I am all ears :)

One minor change I would probably do as well is extract all the messages that 
pertain to an update of the Item into their own group, something like:  

``` fsharp
type ItemChanged =
    | NameChanged of string
    | DescriptionChanged of string

type Msg =
    | ItemChanged of ItemChanged
    | SelectedItemIdChanged of Option<Guid>
    | CreateItem
    | DeleteItem of Guid
    | SearchStringChanged of string
```

This would allow some code simplification in the `update` function, at the 
expense of perhaps a harder to follow code flow, due to mapping of messages.  

Finally, one thing I am not entirely clear about is the difference between 
`View.withKey` and `View.createWithKey`.  

At any rate, this is where we will leave things for today!  

> You can find the completed, [full code example here][4].

[1]: https://brandewinder.com/2025/08/20/avalonia-funcui-list-selection/
[2]: https://funcui.avaloniaui.net/controls/listbox
[3]: https://github.com/mathias-brandewinder/Avalonia-FuncUI-Examples/blob/4f0757d6bd20b6909a1295423f8f2a33c4c0b8b1/ListSelection.fs
[4]: https://github.com/mathias-brandewinder/Avalonia-FuncUI-Examples/blob/a16f00268ee65d65ccfb78fc6a891a2efd1015b3/ListSelection.fs