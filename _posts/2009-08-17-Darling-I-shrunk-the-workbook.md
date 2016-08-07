---
layout: post
title: Darling, I shrunk the workbook
tags:
- Excel
- VSTO
- Performance
---

I was digging through older Excel projects recently, and realized that while all my recent projects haven’t become smaller in terms of data (if anything, they have become more data-intensive), they all had very small Excel files. Which got me wondering – did my workbooks really shrink, and why?  One of the characteristics of my recent projects has been that I have progressively removed most of the calculations from the spreadsheets. Excel is used to store inputs and to display outputs, and computations happen outside, using either VSTO add-ins, or Interop (I realize it is a somewhat devious use of Excel, but I have my reasons for doing this). As a result, the Excel files contain raw data (input data, or output results), some formatting, and no formulas. This made me curious: does using formulas affect the file size significantly?  Here are the 2 key conclusions from my quick & dirty experiment:  

* Each formula costs about the double of a straight, static input.
* Besides that, the size of a file grows linearly with the number of cells used. 

<!--more-->

## Cells used and file size  

Before looking at the impact of formulas, I wanted to see how file size reacted to “non-formula” cells. For that purpose, I created multiple Excel 2003 workbooks:  

* 4 workbooks containing only one worksheet, with 100, 10,000, 100,000 and 1,000,000 cells containing the letter “A”. The chart below (in Log/Log scale) shows that besides an overhead cost for small files, the size grows linearly with the number of cells used.

![CellsVsFileSize]({{ site.url }}/assets/2009-08-17-CellsVsFileSize_thumb.png)

* One workbook containing the [pangram](http://en.wikipedia.org/wiki/The_quick_brown_fox_jumps_over_the_lazy_dog) "The quick brown fox jumps over the lazy dog" in 100 x 100 cells. The file size was identical to the 100 x 100 “A” file, which leads me to conclude that what matters is whether the cell is used, not how much content there is in the cell.
* One workbook containing the number 0.123, and 0.123456789 in 100x100 cells. This time, the file size grew a bit. However, the precision of the number does not seem to matter.
* Formatting: I added formatting to the sheet (borders, colors, patterns), and observed a barely noticeable size increase. Formatting numbers as % had no visible impact either.
* Empty cells: I created a file where cell CV:100 (the cell in position 100, 100) contained the letter A, all other cells being empty. The file size stayed minimum. I wondered about that one: if you work with an array and declare it to be a 100 x 100 array of some type, its size should be 100x100x the size of the contained type, regardless of how you fill it. This means to me that Excel is not really behaving as an array, and that what matters is how many cells are filled (and by what), but not where these cells are located in the worksheet.
* Multiple sheet: I created 10 sheets containing the same data, and the file size was roughly 10 times larger. No surprise there.  

## Formulas  

Next I started playing with formulas; rather than having 100 x 100 cells filled with the letter “A”, I filled A1 with A, and had all other cells equal the cell on its left.  
![SimpleFormula]({{ site.url }}/assets/2009-08-17-SimpleFormula_thumb.png)

This one surprised me: the file size nearly tripled.  

Just for fun, I tried a few variations:  

* More complex function. I used `=UPPER(LEFT(RIGHT(A2,1),1))`, which does nothing but is longer. The file size increased nearly 10%.
* I replaced 0.123 by =0.123 in 100 x 100 cells. The file size nearly doubled.
* Formatting and formulas referencing other worksheets did not seem to cause more increase.

## Conclusion  

I admit it, I was surprised to see that entering a formula in a cell did matter, while entering more data in a cell doesn’t. The reason I was surprised is that intuitively, I expected workbooks with formulas to take more space in memory (because they have to load both the formula and its value), but not on disk, because I though the worksheets would store and save only the formula (which shouldn’t take more space than a straight string content), and would dynamically refresh the value of the function after the file has been opened. That doesn’t seem to be the case.   

Excel Cells have 2 different properties, Cell.Text and Cell.Value2, which return respectively the text contained in the cell, and what that text evaluates too. One possible interpretation of what is going on is that for static cells (no formula), by definition the value equals the text, whereas for formula cells, the 2 differ; Excel probably stores each differently, saving the function AND its value when saving a formula cell into a file.  

In any case, this is of very limited practical use. I have seen my share of humongous workbooks, but the file size was never the issue – maintainability and speed of computation were. This and testability are the key reasons why I tend to extract the calculations from the workbook – and I take it as a pleasant side-effect that, as a cherry on the cake, file size will typically be smaller, too!
