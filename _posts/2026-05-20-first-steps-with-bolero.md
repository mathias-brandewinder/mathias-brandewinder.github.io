---
layout: post
title: "Drawing mountains: setting up Bolero"
tags:
- F#

---

With a return to dungeon master duties, making maps has made a come back in my 
weekend activities, and I started revisiting an old side-project of mine, 
drawing mountains in a style similar to [topographic maps][1]. The aspect I am 
mostly interested in is not the contour lines, but rather the usage of shadows 
to visualize the relief.  

My goal here is as follows: given a grid of altitudes describing a terrain, can 
I draw it and suggest the relief by rendering the shadows of mountains?  

I am pretty certain that there must exist solutions to this. I am less 
interested in the result than in understanding lights and shadows. In other 
words, this project is entirely pointless, except as an exploration exercise!  

In aprevious series of posts, [I used SVG][2] to draw geometric figures and 
found it reasonably enjoyable, so that's what I decided to use.  

One aspect of that previous project wasn't very pleasant, though: the process 
of generating documents by manually running a scripts to create a html file, 
and opening it it the browser to see the results. So I figured I would try 
something different, and use this as an excuse to give 
[Bolero, the F# WebAssembly library][3], a spin.  

## Initial setup

The setup of Bolero was [completely straightforward][4]:  

- install the template,  
- create a project, using the `--minimal` option,  
- start the server with `dotnet watch run`,  
- go to the browser, a basic elmish app is running, with hot-reload.  

<!--more-->

I am not a web developer by any stretch of the imagination, so anything I will 
say should be taken with a grain of salt. However, the experience was 
pleasantly straightforward. Compared to SAFE, there were way less dependencies 
involved, compared to Avalonia FuncUI, the minimal template was wired just 
enough to get me started immediately.  

> Note: I deliberately picked the `--minimal` option because, not knowing 
anything about Bolero or WASM, I wanted to see as clearly as possible how 
things were wired together in their simplest form, without including anything 
un-necessary. I appreciate having that option!  

Hot-reload would perhaps be better described as lukewarm reload. Changing the 
code and saving does automatically reload the running app, but involves running 
a dotnet build, which is not exactly blazing fast. This gave me a new 
appreciation for hot-reload in Fable applications.  

## Using SVG

Bolero uses an approach for UI elements that is different from either 
Fable / Feliz or Avalonia FuncUI. Instead of lists of children, it relies on 
computation expressions, like so:  

``` fsharp
div {
    h1 { "Title" }
    button {
        on.click (fun _ -> Clicked |> dispatch)
        "Click me!"
        }
    }
```

At first glance, not particularly complicated to figure out. I haven't used 
it enough yet to form an opinion on what I like and dislike about it - more on 
this in a later post, perhaps!  

My goal being to use `svg`, I immediately tried `svg { ... }`, and lo and
behold, it worked. Great!  

And then I hit a roadblock. I wanted to express something like this:  

``` html
<svg width="100" height="100">
  <circle cx="50" cy="50" r="40" fill="yellow" />
</svg>
```

But when I try the following  

``` fsharp
svg {
    circle { }
    }
```

... I was greeted by a compiler complaint 
`The value or constructor 'circle' is not defined`.  

The [documentation on Writing HTML][5] helped overcome that first block:  

``` fsharp
svg {
    elt "circle" { }
    }
```

... but I then immediately hit a second roadblock, how to set `cx` or `cy`? 
The examples I saw in the documentation all relied something like `attr.name` 
or `attr.style`, but none of the attributes I was hoping for was showing up for 
`circle`.  

Thankfully, [@tarmil][6] came to the rescue with a helpful pointer, the `=>` 
operator, which I completely missed [in the Attributes docs][7], and lead to 
the following code:  

``` fsharp
svg {
    circle {
        "cx" => 50
        "cy" => 50
        // etc...
        }
    }
```

And with that, I have all I need to start drawing `svg` elements and get to
what I am interested in, drawing mountains! Next time, we'll dive into some 
geometry. In the meantime, you can see the [work in progress on Codeberg][8].  

[1]: https://en.wikipedia.org/wiki/Topographic_map
[2]: https://brandewinder.com/2025/04/30/delaunay-super-triangle-revisited/
[3]: https://fsbolero.io/
[4]: https://fsbolero.io/docs/
[5]: https://fsbolero.io/docs/HTML#elements
[6]: https://mastodon.tarmil.fr/@tarmil
[7]: https://fsbolero.io/docs/HTML#attributes
[8]: https://codeberg.org/mathias-brandewinder/cartographer