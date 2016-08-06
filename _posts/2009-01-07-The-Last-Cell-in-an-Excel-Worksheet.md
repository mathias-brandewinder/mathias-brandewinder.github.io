---
layout: post
title: The Last Cell in an Excel Worksheet
tags:
- C#
- VBA
- Excel
---

I am currently working on an application which requires reading the contents of an Excel worksheet into a 2-dimensional array. I want to avoid loading the entire contents of the worksheet, and want to read only the upper-left quadrant, and leave out all the empty cells on the left and the bottom of the sheet. Problem is, how do you find out the last cell that contains something, that is, the cell such that no cell below it or on its right has content?  Everything Google turned up looked pretty nasty - either brute force, or acrobatic usage of Excel functions, until I [stumbled](http://www.vbforums.com/archive/index.php/t-234942.html) across this [little gem](http://msdn.microsoft.com/en-us/library/aa213567(office.11).aspx): 

``` csharp
var lastCell = xlWorksheet.Cells.SpecialCells(
    Microsoft.Office.Interop.Excel.XlCellType.xlCellTypeLastCell, 
    Type.Missing);
```

You learn everyday. 
