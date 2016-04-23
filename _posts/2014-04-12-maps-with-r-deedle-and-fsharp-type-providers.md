---
layout: post
title: Creating maps using R, Deedle and F# type providers
tags:
- F#
- Type-Provider
- R
- Deedle
---

A lightweight post this week. One of my favorite F# type providers is the World Bank type provider, which enables ridiculously easy access to a boatload of socio-economic data for every country in the world. However, numbers are cold – wouldn’t it be nice to visualize them using a map? Turns out it’s pretty easy to do, using another of my favorites, the R type provider. The rworldmap R package, as its name suggests, is all about world maps, and is a perfect fit with the World Bank data.

The video below shows you the results in action; I also added the code below, for good measure. The only caveat relates to the integration between the Deedle data frame library and R. I had to manually copy the Deedle.dll and Deedle.RProvider.Plugin.dll into packages\RProvider.1.0.5\lib for the R Provider to properly convert Deedle data frames into R data frames. Enjoy!

<iframe height="315" src="//www.youtube.com/embed/-w7o9PHsnP8" frameborder="0" width="560" allowfullscreen="allowfullscreen"></iframe>

<!--more-->

Here is the script I used:

``` fsharp
#I @"..\packages\"
#r @"R.NET.1.5.5\lib\net40\RDotNet.dll"
#r @"RProvider.1.0.5\lib\RProvider.dll"
#r @"FSharp.Data.2.0.5\lib\net40\FSharp.Data.dll"
#r @"Deedle.0.9.12\lib\net40\Deedle.dll"
#r @"Deedle.RPlugin.0.9.12\lib\net40\Deedle.RProvider.Plugin.dll"
 
open FSharp.Data
open RProvider
open RProvider.``base``
open Deedle
open Deedle.RPlugin
open RProviderConverters
 
let wb = WorldBankData.GetDataContext()
wb.Countries.France.CapitalCity
wb.Countries.France.Indicators.``Population (Total)``.[2000]
 
let countries = wb.Countries
 
let pop2000 = series [ for c in countries -> c.Code => c.Indicators.``Population (Total)``.[2000]]
let pop2010 = series [ for c in countries -> c.Code => c.Indicators.``Population (Total)``.[2010]]
let surface = series [ for c in countries -> c.Code => c.Indicators.``Surface area (sq. km)``.[2010]]
 
let df = frame [ "Pop2000" => pop2000; "Pop2010" => pop2010; "Surface" => surface ]
df?Codes <- df.RowKeys
 
open RProvider.rworldmap
 
let map = R.joinCountryData2Map(df,"ISO3","Codes")
R.mapCountryData(map,"Pop2000")
 
df?Density <- df?Pop2010 / df?Surface
df?Growth <- (df?Pop2010 - df?Pop2000) / df?Pop2000
 
let map2 = R.joinCountryData2Map(df,"ISO3","Codes")
R.mapCountryData(map2,"Density")
R.mapCountryData(map2,"Growth")
```

Have a great week-end, everybody! And big thanks to [Tomas](https://twitter.com/tomaspetricek) for helping me figure out a couple of things about Deedle.