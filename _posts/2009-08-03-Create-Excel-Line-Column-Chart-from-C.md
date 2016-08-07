---
layout: post
title: Create Excel Line - Column Chart from C#
tags:
- C#
- Excel
- Chart
- Office
- OBA
---

I just completed a fun project a few days ago, a C# application which performed lots of reading from and writing to Excel. One small problem got me stumped: I know how to&#160; [add a standard chart]({{ site.url }}/2009/04/06/Manipulating-Excel-embedded-charts/), but I couldn’t figure out how to add charts from the Custom Types selection. Most of these are utterly useless (There is an “Outdoors Bar” type, which is “A bar chart with an outdoor look”. I am not making this up.), except for one: the “Line – Column” chart type, and its variations on 2 axes.  

![OutdoorBars]({{ site.url }}/assets/2009-08-03-OutdoorBars_thumb.png)
*I like Outdoorsy charts*  

The VBA macro recorder spat out this:  

``` vb
ActiveChart.ApplyCustomType ChartType:=xlBuiltIn, TypeName:="Line - Column"
``` 

So I check the Chart object in C# and sure enough it has a method `ApplyCustomType(Excel.XlChartType CharType, object TypeName)`. Problem: the enumeration `Excel.XlChartType` does not contain anything like `XlBuiltIn`. Damn.

Long story short: `xlBuiltIn` is to be found in the enum `XlChartGallery`, and the type name is passed as a good old magic string. This code does the job:

*Edit, August 20, 2009: this code works for Excel 2003, but not for Excel 2007. Check [this post]({{ site.url }}/2009/08/20/Create-an-Excel-Line-Column-combination-chart-in-C-revisited) for an updated version of the code which follows the suggestion of [Jon Peltier, Master of Charts](http://peltiertech.com/WordPress/).*

``` csharp 
// create your chart first
string builtInType = "Line - Column";
Excel.XlChartType customChartType = (XlChartType)XlChartGallery.xlBuiltIn;
chart.ApplyCustomType(customChartType, builtInType);
``` 
