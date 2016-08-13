---
layout: post
title: Create an Excel chart in C# without worksheet data
tags:
- Excel
- Chart
- VSTO
- C#
- LINQ
---

I am putting together a demo VSTO add-in for my talk at the [Excel Developer Conference](http://xlconf.wordpress.com/2011/11/22/uk-excel-developer-conference-london-january-2012/). I wanted to play with charts a bit, and given that I am working off a .NET model, I figured it would be interesting to produce charts directly from the data, bypassing the step of putting data in a worksheet altogether.  

In order to do that, we simply need to create a `Chart` in a workbook, add a `Series` to the `SeriesCollection` of the chart, and directly set the `Series` `Values` and `XValues` as an array, along these lines:   

``` csharp
var excel = this.Application;
var workbook = excel.ActiveWorkbook;
var charts = workbook.Charts;
var chart = (Chart)charts.Add();

chart.ChartType = Excel.XlChartType.xlLine;
chart.Location(XlChartLocation.xlLocationAsNewSheet, "Tab Name");

var seriesCollection = (SeriesCollection)chart.SeriesCollection();
var series = seriesCollection.NewSeries();

series.Values = new double[] {1d, 3d, 2d, 5d};
series.XValues = new string[] {"A", "B", "C", "D"};
series.Name = "Series Name";
``` 
<!--more-->

This will create a simple Line chart in its own sheet – without any reference to a worksheet data range.

Now why would I be interested in this approach, when it’s so convenient to create a chart from data that is already in Excel?

Suppose for a moment that you are dealing with the market activity on a stock, which you can retrieve from an external data source as a collection of `StockActivity` .NET objects:

``` csharp
public class StockActivity
{
   public DateTime Day { get; set; }
   public decimal Open { get; set; }
   public decimal Close { get; set; }
}
``` 

In this case, extracting the array for the X and Y values would be a trivial matter, making it very easy to produce a chart of, say, the Close values over time:

``` csharp
// Create a few fake datapoints
var day1 = new StockActivity()
              {
                 Day = new DateTime(2010, 1, 1), 
                 Open = 100m, 
                 Close = 110m
              };
var day2 = new StockActivity()
              {
                 Day = new DateTime(2010, 1, 2), 
                 Open = 110m, 
                 Close = 130m
              };
var day3 = new StockActivity()
              {
                 Day = new DateTime(2010, 1, 3), 
                 Open = 130m, 
                 Close = 105m
              };
var history = new List<StockActivity>() { day1, day2, day3 };

var excel = this.Application;
var workbook = excel.ActiveWorkbook;
var charts = workbook.Charts;
var chart = (Chart)charts.Add();

chart.ChartType = Excel.XlChartType.xlLine;
chart.Location(XlChartLocation.xlLocationAsNewSheet, "Stock Chart);

var seriesCollection = (SeriesCollection)chart.SeriesCollection();
var series = seriesCollection.NewSeries();

series.Values = history.Select(it => (double)it.Close).ToArray();
series.XValues = history.Select(it => it.Day).ToArray();
series.Name = "Stock";
``` 

Using LINQ, we Select from the list the values we are interested in, and pass them into an array, ready for consumption into a chart, and boom! We are done.

If what you need to do is explore data and produce charts to figure out potentially interesting relationships, this type of approach isn’t very useful. On the other hand, if your problem is to produce on a regular basis the same set of charts, using data coming from an external data source, this is a very interesting option!
