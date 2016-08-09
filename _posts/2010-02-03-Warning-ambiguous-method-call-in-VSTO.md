---
layout: post
title: Warning - ambiguous method call in VSTO
tags:
- Activate
- Warning
- Excel
- VSTO
- Add-In
- Tips-And-Tricks
---

Activating a worksheet is a fairly common task in Office automation; however, in a VSTO project, if you call:

``` csharp 
myWorksheet.Activate();
``` 

… building the project will give you the following warning:

> Ambiguity between method 'Microsoft.Office.Interop.Excel._Worksheet.Activate()' and non-method 'Microsoft.Office.Interop.Excel.DocEvents_Event.Activate'. Using method group.

I don’t like to have warnings in my projects when I can avoid it, but I never got to look into it. After all, it was “just a warning”, so I let it go.

The answer came to me via the [Carter & Lippert VSTO book](http://www.amazon.com/gp/product/0321533216) (aka “The Brick”), which I finally started reading through, and highly recommend. The gist of it is that the Worksheet interface implements 2 interfaces, `_Worksheet` and `DocEvents_Event`. `_Worksheet` contains the properties and methods that correspond to the `Worksheet`, including the `Activate()` method, while `DocEvents_Event` owns the events, including `Activate`, and these two names collide.

To disambiguate the call, you just need to cast the `Workbook` to the appropriate interface, the one which owns the method you are interested in. In my case, I want to Activate the workbook, and therefore use the following code:

``` csharp 
((Excel._Worksheet)myWorksheet).Activate();
``` 

And sure enough, the warning is gone.
