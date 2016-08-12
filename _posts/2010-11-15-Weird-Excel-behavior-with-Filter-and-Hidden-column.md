---
layout: post
title: Weird Excel behavior with Filter and Hidden column
tags:
- VBA
- Filter
- Bug
- Excel
---

I ran into something odd in Excel in my current project; it seems a lot like a bug to me, but that might also be simply that I know less about Excel than I think I do. Anyways, I have reproduced the issue with a simpler scenario.  

The problem goes along these lines: in a spreadsheet, I create headers for data, and write out a few records below through code. Everything works fine – even if I hide a column, data gets properly written to the worksheet.  

When I add a Filter to the header row, everything still goes great. But when I filter out some of the values in the filter of one of the columns and hide that column, then the code just doesn’t write any values in that column.  

Let’s illustrate: here is some quick and dirty VBA code that generates rows of random numbers, and writes them to a sheet, starting in row 2 (my original code was C# / VSTO, but I figured it would be smart to try out VBA as well):  

``` vb
Dim CurrentRow As Integer

Public Sub WriteData()
    If CurrentRow = 0 Then CurrentRow = 2
    Dim data(1 To 3) As Integer
    data(1) = Int(Rnd * 5)
    data(2) = Int(Rnd * 5)
    data(3) = Int(Rnd * 5)
    Dim sheet As Worksheet
    Set sheet = ActiveSheet
    Dim startCell As Range
    Set startCell = sheet.Cells(CurrentRow, 1)
    Dim endCell As Range
    Set endCell = sheet.Cells(CurrentRow, 3)
    Dim targetRange As Range
    Set targetRange = sheet.Range(startCell, endCell)
    targetRange.Value2 = data
    CurrentRow = CurrentRow + 1
End Sub
``` 

If I run the macro `WriteData` on a sheet, I’ll see something like this:

![WritingData]({{ site.url }}/assets/2010-11-15-WritingData_thumb.png)

<!--more-->

Now let’s add some headers with filters:

![AddFilters]({{ site.url }}/assets/2010-11-15-AddFilters_thumb.png)

Everything is still perfectly normal. Let’s hide column B, add a few records with the macro, and un-hide column B – everything runs fine and dandy.

Now to the not-so-fine part – let’s Filter out a few values from column B, which collapses some rows:

![FilterColumn]({{ site.url }}/assets/2010-11-15-FilterColumn_thumb.png)

Hide Column B, run the macro a few times, and un-hide column B – here is what I get:

![Ooops]({{ site.url }}/assets/2010-11-15-Ooops_thumb.png)

The macro has written values in Columns A and C, but nothing has been written in Column B. Isn’t that weird? 

In my project, the issue was even weirder: I got into a situation where the code was writing to a certain range, but values ended up being written shifted by one column to the right. I couldn’t yet write a simple example reproducing that problem, but I’ll try to do it.

As a workaround I ended up de-activating filters when code was writing data to the sheet, but it does sound like a bug to me, if only because the behavior is inconsistent. I can write in a hidden cell, I can write in a Filtered cell, but I can’t write in a cell that is both hidden and filtered, with no warning at all.

Is this a known bug with filters? Has anyone else encountered it?
