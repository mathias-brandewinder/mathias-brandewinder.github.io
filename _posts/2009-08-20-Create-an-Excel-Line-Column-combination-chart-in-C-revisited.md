---
layout: post
title: Create an Excel Line – Column combination chart in C#, revisited
tags:
- Excel
- C#
- Interop
- Chart
- Tips-And-Tricks
---

I wrote a post a few days ago describing how to generate a [Line – Column chart]({{ site.url }}/2009/08/03/Create-Excel-Line-Column-Chart-from-C/) in Excel through C#. And then a few things happened. [Jon Peltier](http://peltiertech.com/WordPress/) proposed a much nicer approach, I realized that my code worked for Excel 2003 but not Excel 2007, and someone asked for my code, “Jon-Peltier style”. So here we go: assuming your chart has more than one series, and you want the second series to be formatted as a line, all the rest as columns, you would do something like this: 

``` csharp 
// Create your chart object first
// formatted as column
Chart chart = ExcelCharts.AddChart(targetWorkbook, “my chart”, “the chart title”, XlChartType.xlColumnClustered, dataRange, XlRowCol.xlRows);
// Select the second series and make it a line
Series series = (Series)chart.SeriesCollection(2);
series.ChartType = XlChartType.xlLine;
``` 

Here is a simplified version of my `AddChart` method, which creates the base chart. Nothing fancy, but gets the job done.

``` csharp 
public static Excel.Chart AddChart(Workbook workbook, string chartSheetName, string title, XlChartType chartType, Range dataRange, XlRowCol byRowOrCol)
{
    Excel.Chart chart;
    chart = (Excel.Chart)workbook.Charts.Add(Type.Missing, Type.Missing, Type.Missing, Type.Missing);
    chart.ChartType = chartType;
    chart.Location(XlChartLocation.xlLocationAsNewSheet, chartSheetName);
    chart.SetSourceData(dataRange, byRowOrCol);
    chart.HasTitle = true;
    chart.ChartTitle.Text = title;
    return chart;
}
``` 

As an aside, I was not happy with myself when I realized the code didn’t run on Excel 2007. I tend to write Excel-related code against Excel 2003 first, assuming it is the smallest common denominator and will likely work with Excel 2007 – but this is a perfect illustration that while it will typically be correct, it will sometimes fail, sometimes in very unexpected and trivial places, like in this example. Moral of the story: as Lenin allegedly said, “Trust is good, control is better”…
