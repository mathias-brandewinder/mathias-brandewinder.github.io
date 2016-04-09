---
layout: post
title: Textogramme
tags:
- F#
- fsAdvent
- Fun
- Caligramme
- Useless
---

_This post is December 20th' part of the [English F# Advent](https://sergeytihon.wordpress.com/2014/11/24/f-advent-calendar-in-english-2014/) [#fsAdvent](https://twitter.com/search?q=%23fsadvent) series; make sure to also check out the [Japanese series](http://connpass.com/event/9758/), which also packs the awesome!_

As I was going around Paris the other day, I ended up in the Concorde metro station. Instead of the standard issue white tiles, this station is decorated with the French constitution, rendered as a mosaic of letters.

![Metro Concorde]({{ site.url }}/assets/Metro-Concorde.jpg)

[Source: Wikipedia](http://fr.wikipedia.org/wiki/Concorde_(m%C3%A9tro_de_Paris)

<!--more-->

My mind started wandering, and by some weird association, it reminded me of [Calligrammes](http://en.wikipedia.org/wiki/Calligrammes), a collection of poems by Guillaume Apollinaire, where words are arranged on the page to depict images that compliment the text itself.

![Apollinaire Calligramme]({{ site.url }}/assets/Guillaume-Apollinaire-Calligramme-La_Mandoline,_l’œillet_et_le_bambou.png)

[Source: Wikipedia](http://en.wikipedia.org/wiki/Calligrammes)

After some more drifting, I started wondering if I could use this as an inspiration for some playful F# fun. How about taking a piece of text, an image, and fusing them into one?

There are many ways one could approach this; being rather lazy, I thought a reasonably simple direction would be to decompose the original image into dark and light blocks, and fill them with the desired text. As simple as it may sound, the task is not entirely trivial. First, we need to decide on an appropriate threshold to separate "dark" and "light" areas on the image, to get a contrast good enough to recognize the image rendered in black & white. Then, we also have to resize the image appropriately into a new grid, where the characters from the original text fit the mapped dark area as closely as possible.

_Note: I don't think the warning "don't put this in production, kids" is useful, unless someone thinks there is a market for Calligramme as a Service. However, I'll say this: this is me on "vacation hacking fun" mode, so yes, there are quite probably flaws in that code. I put it up as a [Gist here](https://gist.github.com/mathias-brandewinder/ec37edfad6bf5a7ca2ff) - flame away, or tell me how to make it better on Twitter ;)_

## Separating dark and light

So how could we go about splitting an image into dark and light pixels? First, we can using the color brightness from the System.Drawing namespace to determine how light the color of an individual pixel is:

``` fsharp
open System.Drawing
 
let brightness (c:Color) = c.GetBrightness ()
 
let pixels (bmp:Bitmap) =
    seq { for x in 0 .. bmp.Width - 1 do
        for y in 0 .. bmp.Height - 1 ->
            (x,y) |> bmp.GetPixel }
```

We still need to decide what boundary to use to separate the image between dark and light. What we want in the end is an image which is reasonably balanced, that is, it should be neither overwhelmingly dark or light. A simple way to enforce that is to arbitrarily constrain one third of the pixels at least to be either dark or light. Then, we want a boundary value that is as clear cut as possible, for instance by finding a value with a large brightness change margin. Let's do that:

``` fsharp
let breakpoint (bmp:Bitmap) =
    let pixelsCount = bmp.Width * bmp.Height
    let oneThird = pixelsCount / 3
    let pixs = pixels bmp
    let threshold =
        pixs
        |> Seq.map brightness
        |> Seq.sort
        |> Seq.pairwise
        |> Seq.skip oneThird
        |> Seq.take oneThird
        |> Seq.maxBy (fun (b0,b1) -> b1 - b0)
        |> snd
    let darkPixels =
        pixs
        |> Seq.map brightness
        |> Seq.filter ((>) threshold)
        |> Seq.length
    (threshold,darkPixels)
```

We iterate over every pixel, sort them by brightness, retain only the middle third, and look for the largest brightness increase. Done - breakpoint returns both the threshold value (the lightness level which decides whether a pixel will be classified as dark or light), as well as how many pixels will be marked as dark.

## Resizing

Now that we have a boundary value, and know how many pixels will be marked as dark, we need to determine the size of the grid where our text will be mapped. Ignoring for a moment rounding issues, let's figure out a reasonable size for our grid.

First, how many characters do we need? We know the number of dark pixels in the original image - and in our target image, we want the same ratio of text to white space, so the total number of characters we'll want in our final image will be roughly total chars ~ text length * dark pixels / (width * height).

Then, what should the width of the target image, in characters? First, we want [1] target width * target height ~ total chars. Then, ideally, the proportions of the target image should be similar to the original image, so target width / target height ~ width / height, which gives us target height ~ target width * height / width. Substituting in [1] gives us target width * target width * height / width ~ total chars, which simplifies to target width ~ sqrt (total chars * width / height).

Translating this to code, conveniently ignoring all the rounding issues, we get:

``` fsharp
let sizeFor (bmp:Bitmap) (text:string) darkPixels =
    let width,height = bmp.Width, bmp.Height
    let pixels = width * height
    let textLength = text.Length
    let chars = textLength * pixels / darkPixels
    let w = (chars * width / height) |> float |> sqrt |> int
    let h = (w * height) / width
    (w,h)
```

## Rendering

Good, now we are about ready to get down to business. We have an original image, a threshold to determine which pixels to consider dark or light, and a "target grid" of known width and height. What we need now is to map every cell of our final grid to the original image, decide whether it should be dark or light, and if dark, write a character from our text.

Ugh. More approximation ahead. At that point, there is no chance that the cells from our target grid map the pixels from the original image one to one. What should we do? This is my Christmas vacation time, a time of rest and peace, so what we will do is be lazy again. For each cell in the target grid, we will retrieve the pixels that it overlaps on the original image, and simply average out their brightness, not even bothering with a weighted average based on their overlap surface. As other lazy people before me nicely put it, "we'll leave that as an exercise to the reader".

Anyways, here is the result, a mapping function that returns the coordinates of the pixels intersected by a cell, as well as a reducer, averaging the aforementioned pixels by brightness, and a somewhat un-necessary function that transforms the original image in a 2D array of booleans, marking where a letter should go (I mainly created it because I had a hard time keeping track of rows and columns):

``` fsharp
let mappedPixels (bmp:Bitmap) (width,height) (x,y) =
 
    let wScale = float bmp.Width / float width
    let hScale = float bmp.Height / float height
    
    let loCol = int (wScale * float x)
    let hiCol =
        int (wScale * float (x + 1)) - 1
        |> min (bmp.Width - 1)
    let loRow = int (hScale * float y)
    let hiRow =
        int (hScale * float (y + 1)) - 1
        |> min (bmp.Width - 1)
    
    seq { for col in loCol .. hiCol do
            for row in loRow .. hiRow -> (col,row) }
 
let reducer (img:Bitmap) pixs =
    pixs
    |> Seq.map img.GetPixel
    |> Seq.averageBy brightness
 
let simplified (bmp:Bitmap) (width,height) threshold =
 
    let map = mappedPixels bmp (width,height)
    let reduce = reducer bmp
    let isDark value = value < threshold
    
    let hasLetter = map >> reduce >> isDark
    
    Array2D.init width height (fun col row ->
        (col,row) |> hasLetter)
```

Almost there - wrap this with 2 functions, applyTo to transform the text into a sequence, and rebuild, to recreate the final string function:

``` fsharp
let applyTo (bmp:Bitmap) (width,height) threshold (text:string) =
 
    let chars = text |> Seq.toList
    let image = simplified bmp (width,height) threshold
    
    let nextPosition (col,row) =
        match (col < width - 1) with
        | true -> (col+1,row)
        | false -> (0,row+1)
    
    (chars,(0,0))
    |> Seq.unfold (fun (cs,(col,row)) ->
        let next = nextPosition (col,row)
        match cs with
        | [] -> Some(' ',(cs,next))
        | c::tail ->
            if image.[col,row]
            then
                Some(c,(tail,next))
            else Some(' ',(cs,next)))
 
let rebuild (width,height) (data:char seq) =
    seq { for row in 0 .. height - 1 ->
            data
            |> Seq.map string
            |> Seq.skip (row * width)
            |> Seq.take width
            |> Seq.toArray 
            |> (String.concat "") }
    |> (String.concat "\n")
```

## Trying it out

Let's test this out, using the [F# Software Foundation logo](http://fsharp.org/foundation/logo.html) as an image, and the following text, from fsharp.org, as a filler:

> F# is a mature, open source, cross-platform, functional-first programming language. It empowers users and organizations to tackle complex computing problems with simple, maintainable and robust code.

Run this through the grinder…

``` fsharp
let path = @"c:/users/mathias/pictures/fsharp-logo.jpg"
let bmp = new Bitmap(path)
 
let text = """F# is // snipped // """
 
let threshold,darkPixels = breakpoint bmp
let width,height = sizeFor bmp text darkPixels
 
text
|> applyTo bmp (width,height) threshold   
|> rebuild (width,height)
```

… and we get the following:

```                        
           F#           
           is           
         a matu         
        re, open        
        source, c       
      ross-platfor      
     m, fun  ctiona     
    l-firs t   progr    
   amming  l   anguag   
  e. It  emp    owers   
 users  and      organi 
 zation s to     tackle 
   compl ex    computi  
   ng pro bl  ems wit   
    h simp l e, main    
     tainab le and      
      robust code.   
```   

Not too bad! The general shape of the logo is fairly recognizable, with some happy accidents, like for instance isolating "fun" in "functional". However, quite a bit of space has been left empty, most likely because of the multiple approximations we did along the way.

## Improved resizing

Let's face it, I do have some obsessive-compulsive behaviors. As lazy as I feel during this holiday break, I can't let go of this sloppy sizing issue. We can't guarantee a perfect fit (there might simply not be one), but maybe we can do a bit better than our initial sizing guess. Let's write a mini solver, a recursive function that will iteratively attempt to improve the fit.

Given a current size and count of dark cells, if the text is too long to fit, the solver will simply expand the target grid size, adding one row or one column, picking the one that keeps the grid horizonal/vertical proportions closest to the image. If the text fits better in the new solution, keep searching, otherwise, done (similarly, reduce the size if the text is too short to fit).

For the sake of brevity, I won't include the solver code here in the post. If you are interested, you can [find it in the gist here](https://gist.github.com/mathias-brandewinder/ec37edfad6bf5a7ca2ff).

Below are the results of the original and shiny new code, which I ran on a slightly longer bit of text.

Before:

```                                  
               F#is               
              amatur              
             eopenso              
            urcecross             
           -platformfun           
          ctional-firstp          
         rogramminglangua         
        geItempowersusersa        
       ndorganiz  ationstot       
      acklecomp    lexcomput      
     ingproble ms   withsimpl     
    emaintain abl    eandrobus    
   tcodeF#ru nson     LinuxMacO   
  SXAndroid iOSWi      ndowsGPUs  
 andbrowse rsItis       freetouse 
  andisope nsourc       eunderanO 
  SI-approv edlic      enseF#isu  
   sedinawid eran     geofappli   
     cationar eas   andissuppo    
      rtedbybo th   anactive      
      opencommu    nityandin      
       dustry-le  adingcomp       
         aniesprovidingpr         
          ofessionaltool          
          s                       
```

… and after:

```
               F #               
              is am              
             atu reo             
            pens ourc            
           ecros s-pla           
          tformf unctio          
         nal-fir stprogr         
        ammingla nguageIt        
       empowers   usersand       
      organiza t   ionstota      
     cklecomp le    xcomputi     
    ngproble msw     ithsimpl    
   emaintai nabl      eandrobu   
  stcodeF# runso       nLinuxMac 
 OSXAndro  idiOS       WindowsGP 
  Usandbro wsers      Itisfreet  
   ouseandi sope     nsourceun   
    deranOSI -ap    provedlic    
     enseF#is us   edinawide     
      rangeofa p  plication      
       areasand  issupport       
        edbyboth anactive        
         opencom munitya         
          ndindu stry-l          
           eadin gcomp           
            anie spro            
             vid ing             
              pr of              
               e s               
```

We still have a small mismatch, but the fit is much better.

And this concludes our F# Advent post! This was a rather useless exercise, but then, the holidays are about fun rather than productivity. I had fun doing this, and hope you had some fun reading it. In the meanwhile, I wish you all a holiday period full of fun and happiness, and… see you in 2015! And, as always, you can ping me on twitter if you have comments or questions. Cheers!
