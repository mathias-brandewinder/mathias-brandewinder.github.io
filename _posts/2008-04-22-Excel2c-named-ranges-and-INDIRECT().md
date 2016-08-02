---
layout: post
title: Excel, named ranges and INDIRECT()
tags:
- Excel
- Named-Ranges
- Indirect()
---

I am just wrapping up a project which involved adding some new functionality to an existing Excel financial model. The model was fairly typical: in a nutshell, it contains financial forecasts for every product of a company, and aggregates the results into the overall value of the portfolio of products.


One aspect which ended up being pretty tedious was the creation of summaries. The spreadsheet was very nicely structured; it made good use of named ranges to describe input variables  -  but it also used them heavily in output summaries. As it turns out, this is error-prone and makes the maintenance and reorganization of sheets quite a hassle.


So I struggled for a while with this issue, and came up with a way to build summaries in Excel using a different technique; it relies on the INDIRECT function, and offers a few interesting benefits.

<!--more-->

[Named ranges are a great feature](http://www.cpearson.com/excel/named.htm) -  they allow you to give explicit names to cells on sheets, and refer to the content of the cell by its name. This provides a nice way to make formulas in workbook understandable. The workbook attached, 
[UnitedFruit.xls (70.50 kb)]({{ site.url }}/assets/UnitedFruit.xls), illustrates the principle. It represents a fictional (sort of) company, which sells 3 types of fruits, in 3 states. If you go to the &ldquo;Apple&rdquo; sheet, and select cell F4, you will see that it contains the formula &ldquo;=AppleUnitPrice&rdquo;, which refers to cell B5 in the &ldquo;Inputs&rdquo; sheet. Select cells F4:M4 in &ldquo;Apple&rdquo;, and you will see that it is named &ldquo;AppleCaliforniaPrice&rdquo;. Cell F6, which contains the revenue, contains the pretty straightforward formula =AppleCaliforniaPrice*AppleCaliforniaUnitsSold.

So what&rsquo;s wrong with named ranges?

For one thing, until the introduction of the &ldquo;Name Manager&rdquo; with Excel 2007, the interface to deal with names was absolutely horrendous. In particular, renaming or removing existing names, or checking for obsolete names, was a nightmare. Another source of problems is that checking the name of a single cell is easy (just select it), but verifying a named ranges requires the selection of the entire range, which is pretty tedious.

Sprinkle this with some copy-paste, and you are in for bad surprises. Copying named ranges is fine, as Excel will not copy the names. On the other hand, any formula that uses names will be copied as is: once pasted, it will still refer to values that are valid. As a result, the cells will look all fine and give you a number, but that number is most likely not the one you want.

So should you discard named ranges altogether? I don&rsquo;t think so, but I advise to use them with discipline, and only when you need them. The more named ranges you will have in your workbook, the harder it will be to modify it. An interesting way to leverage named ranges while keeping your workbooks maintainable is to use the INDIRECT() function.

=INDIRECT() takes as first argument a string, which corresponds to a (range of) cells in the workbook. For instance, =INDIRECT(&ldquo;A1&rdquo;) would return the value in cell A1 (note the quotation marks around A1). This usage seems marginally useful at best; on the other hand, what I had not realized until recently is that it is perfectly legitimate to pass in the name of a named range. For instance, =INDIRECT(&ldquo;Price&rdquo;) will work if there is a range named &ldquo;Price&rdquo; in the workbook.

This can be used to great effect to create easy-to-update summary sheets. The &ldquo;United Fruit&rdquo; workbook provides two examples of how this technique can be leveraged.

The first example is the sheet named &ldquo;Total&rdquo;. That type of summary table is very typical in financial workbooks. The long way to create that summary would be to create the structure, and enter in each cell a formula like =BananaNewJerseyRevenue. Alternatively, if a consistent naming convention has been applied throughout the workbook, all revenue lines refer to ranges with names of the form ProductName RegionName Revenue; the name of the corresponding named range can then be created by concatenation, and passed in INDIRECT() to get the appropriate value.

If you expand columns C and D of the &ldquo;Total&rdquo; sheet, you will notice that they have been named respectively &ldquo;Region&rdquo; and &ldquo;Product&rdquo;, and filled with existing region or product names. Each cell in the summary (see cell F6 for instance) uses the formula =INDIRECT(Product &amp; Region &amp; &ldquo;Revenue&rdquo;) to concatenate the appropriate range name to pull data from.

What I like about this approach is that it provides a very flexible and maintainable way to create summaries. The same exact result could be obtained by directly writing = BananaNewJerseyRevenue in the appropriate cell; but if you ever need to change the organization of the summary, or add, delete or rename some ranges, the INDIRECT() approach will be far superior: the only thing you will need to do is to change the names listed in columns C and D, and the entire summary will be updated. 

What I also like about it is that it provides a nice way to validate the consistency of your naming convention. If one of your ranges is named inconsistently, or has not been named, the concatenated name will be invalid and that inconsistency will jump at you on the summary sheet.

The second example is shown on sheet &ldquo;Selection&rdquo;. On this sheet, users can select any combination of product and region, and see the corresponding financial data. The technique used is the same as before: the two combo boxes are populated with values coming from lists of regions and products in sheet &ldquo;Lists&rdquo;, and the selected value is linked to cells A4 and A5, which have been named &ldquo;SelectedRegion&rdquo; and &ldquo;SelectedProduct&rdquo;. The bottom section of the sheet simply retrieves the values in SelectedRegion and SelectedProduct, and concatenates it into names such as &ldquo;AppleCaliforniaPrice&rdquo;, which correspond to named ranges.

The result is a light-weight and easily maintainable sheet, which dynamically generates a summary based on one or more selected items. Sheet &ldquo;SelectionChart&rdquo; illustrate one case where this will turn out to be very practical. If you need to generate charts for each product and region, rather than creating (and maintaining) by hand 9 charts, you would just need to create a chart reading its data from the selection sheet, select the combination you are interested in, and voila! Your chart is updated.

What are the limits of this approach? Quite frankly, I am not sure. I suspect that calling a named range through INDIRECT() must be slower than simply referring to the range itself, but I have not noticed a clear slowdown on the examples I have worked on.

One clear drawback of the method is the loss of clarity. =AppleCaliforniaRevenue is clearer than =INDIRECT(Product &amp; Region &amp; &ldquo;Revenue&rdquo;). For that reason, I do not advocate to use that approach systematically: use it where it is most useful, that is, in sheets which are likely to be reorganized over time, or in sheets where it is valuable to check the consistency of naming conventions.

[UnitedFruit.xls (70.50 kb)]({{ site.url }}/assets/UnitedFruit.xls)
