---
layout: post
title: Picasquez vs Velasso&#58; Classics Mashup with F#
tags:
- F#
- Mashup
- Fun
- Picasso
- Velasquez
---

It is the summer, a time to cool off and enjoy vacations – so let’s keep it light, and hopefully fun, today! A couple of days ago, during his recent San Francisco visit, [@tomaspetricek](https://twitter.com/tomaspetricek) brought up an idea that I found intriguing. What if you had two images, and wanted to recreate an image similar to the first one, using only the pixels from the second?

To make this real, let’s take two images - a portrait by Velasquez, and one by Picasso, which I have conveniently cropped to be of identical size. What we are trying to do is to re-arrange the pixels from the Picasso painting, and recombine them to get something close to the Velasquez:

![Picasso]({{ site.url }}/assets/picasso.png)

![Velasquez]({{ site.url }}/assets/velasquez.png)

<!--more-->

My thinking on the problem was as follows: we are trying to arrange a set of pixels into an image as close as possible to an existing image. That’s not entirely trivial. Being somewhat lazy, rather than work hard, I reverted to my patented strategy “what is the simplest thing that could possibly work (TM)”.

Two images are identical if each of their matching pixels are equal; the greater the difference between pixels, the less similar they are. In that frame, one possible angle is to try and match each pixel and limit the differences.

So how could we do that? If I had two equal groups of people, and I were trying to pair them by skill level, here is what I would do: rank each group by skill, and match the lowest person from the first group with his counterpart in the second group, and so on and so forth, until everyone is paired up. It’s not perfect, but it is easy.

Problem here is that there is no obvious order over pixels. Not a problem – we’ll create a sorting function, and replace it with something else if we don’t like the result. For instance, we could sort by “maximum intensity”; the value of a pixel will be the greater of its Red, Green and Blue value.

At that point, we have an algorithm. Time to crank out F# and try it out with a script:

``` fsharp
open System.IO
open System.Drawing

let combine (target:string) ((source1,source2):string*string) =
    // open the 2 images to combine
    let img1 = new Bitmap(source1)
    let img2 = new Bitmap(source2)
    // create the combined image
    let combo = new Bitmap(img1)
    // extract pixels from an image
    let pixelize (img:Bitmap) = [
        for x in 0 .. img.Width - 1 do
            for y in 0 .. img.Height - 1 do
                yield (x,y,img.GetPixel(x,y)) ]
    // extract pixels from the 2 images
    let pix1 = pixelize img1
    let pix2 = pixelize img2
    // sort by most intense color
    let sorter (_,_,c:Color) = [c.R;c.G;c.B] |> Seq.max
    // sort, combine and write pixels
    (pix1 |> List.sortBy sorter,
     pix2 |> List.sortBy sorter)
    ||> List.zip
    |> List.iter (fun ((x1,y1,_),(_,_,c2)) -> 
        combo.SetPixel(x1,y1,c2))
    // ... and save, we're done
    combo.Save(target)
```

... and we are done. Assuming you downloaded the two images in the same place as

``` fsharp
let root = __SOURCE_DIRECTORY__
 
let velasquez = Path.Combine(root,"velasquez.bmp")
let picasso = Path.Combine(root,"picasso.bmp")
 
let picasquez = Path.Combine(root,"picasquez.bmp")
let velasso = Path.Combine(root,"velasso.bmp")
 
(velasquez,picasso) |> combine velasso
(picasso,velasquez) |> combine picasquez
```

... which should create two images like these:

![Picasquez]({{ site.url }}/assets/picasquez.png)

![Velasso]({{ site.url }}/assets/velasso.png)

Not bad for 20 lines of code. Now you might argue that this isn’t the nicest, most functional code ever, and you would be right. There are a lot of things that could be done to improve that code; for instance, handling pictures of different sizes, or injecting an arbitrary Color sorting function – feel free to have fun with it!

Also, you might wonder why I picked that specific, and somewhat odd, sorting function. Truth be told, it happened by accident. In my first attempt, I simply summed the 3 colors, and the results were pretty bad. The reason for it is, Red, Green and Blue are encoded as bytes, and summing up 3 bytes doesn’t necessarily do what you would expect. Rather than, say, convert everything to int, I went the lazy route again...
