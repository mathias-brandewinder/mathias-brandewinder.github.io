---
layout: post
title: Manipulating Excel embedded charts
tags:
- Excel
---

Just like an [embedded journalist](http://en.wikipedia.org/wiki/Embedded_journalist) becomes something else in the process, I discovered with great pain that manipulating an Excel embedded chart through .NET isn't quite the same as working with a plain chart. To add a chart programmatically, a snippet of code along these lines will do the job, creating a new sheet to host the chart:

``` csharp 
public static Excel.Chart AddChart(Excel.Workbook workbook, string chartSheetName, string title, Excel.XlChartType chartType, Excel.Range dataRange, Excel.XlRowCol byRowOrCol)
{
    Excel.Chart = (Excel.Chart)workbook.Charts.Add(Missing.Value, Missing.Value, Missing.Value, Missing.Value);
    chart.ChartType = chartType;
    chart.Location(Excel.XlChartLocation.xlLocationAsNewSheet, chartSheetName);
    chart.SetSourceData(dataRange, byRowOrCol);
    chart.HasTitle = true;
    chart.ChartTitle.Text = title;
    return chart;
}
``` 

When my client asked if it would be possible to add all the charts in the same worksheet, I expected that accessing and positioning them would be a challenge; what I didn't anticipate was that simply changing the line "Chart.Location" in the code above would cause problems, too.

<!--more-->

Initially, my code looked along these line:

``` csharp 
public static Excel.Chart AddEmbeddedChart(Excel.Workbook workbook, string chartWorksheetName, string title, Excel.XlChartType chartType, Excel.Range dataRange, Excel.XlRowCol byRowOrCol)
{
    Excel.Chart chart = (Excel.Chart)workbook.Charts.Add(Missing.Value, Missing.Value, Missing.Value, Missing.Value);
    chart.ChartType = chartType;
    chart.SetSourceData(dataRange, byRowOrCol);
    chart.Location(Excel.XlChartLocation.xlLocationAsObject, chartWorksheetName);    
    chart.HasTitle = true;
    chart.ChartTitle.Text = title;
    return chart;
}
``` 

I was very surprised to see the code run fine until hitting the "chart.HasTitle" line, and fail miserably. What the heck?
With much hair-pulling (and cursing, too), I finally got it to work, by doing the following modification:

``` csharp 
public static Excel.Chart AddEmbeddedChart(Excel.Workbook workbook, string chartWorksheetName, string title, Excel.XlChartType chartType, Excel.Range dataRange, Excel.XlRowCol byRowOrCol)
{
    Excel.Chart chart = (Excel.Chart)workbook.Charts.Add(Missing.Value, Missing.Value, Missing.Value, Missing.Value);
    chart.ChartType = chartType;
    chart.SetSourceData(dataRange, byRowOrCol);
    Excel.Chart embeddedChart = chart.Location(Excel.XlChartLocation.xlLocationAsObject, chartWorksheetName);
    
    embeddedChart.HasTitle = true;
    embeddedChart.ChartTitle.Text = title;

    return embeddedChart;
}
``` 

I assumed that calling myChart.Location was setting a property on the myChart, and that I would be fine keeping operating on that instance. How naive. Once I noticed that chart.Location returned a chart object, I suspected some foul play, and changed my assumptions - and my code. I haven't checked this any further, but I guess this means that setting the location is not simply changing properties on the chart, but rather instantiating a new chart object.

Next time I'll talk about how to access your embedded charts on the sheet, and do some stuff like changing their position, or resizing them. That was fun, too.
