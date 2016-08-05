---
layout: post
title: Excel extensions with VSTO power tools
tags:
- Office
- VSTO
- Excel
- Oba
---
Apparently, VSTO Power Tools have been around for a while (Feb 02), but if I had not read [this article](http://msdn.microsoft.com/en-us/magazine/dd263100.aspx), I would have missed them - which would be too bad, because they are awesome. The Power Tools consist of a few dlls, which, while not officially supported, have been released by Microsoft developers.  I started playing with the Excel Extensions, and I love it; it is a "very thin wrapper to the Office primary interop assemblies", which essentially gives you cleaner methods to access the Excel object, with type safety, and without the clumsy "Missing.Value" arguments.

<!--more-->

I always ended up adding a utility class to my projects, with a few simplified static methods to do things like find a sheet by name in a workbook; this does all of that, but way better.  For instance, instead of the awkward: 

``` csharp
Microsoft.Office.Interop.Excel.Application excel = AddIn.Application;
Excel.Workbook workbook = excel.ActiveWorkbook;
Excel.Worksheet worksheet = null;
foreach (Excel.Worksheet aSheet in workbook.Worksheets)
{
    if (aSheet.Name == "Sheet1")
    {
        worksheet = aSheet;
        break;
    }
}
Excel.Range startCell = worksheet.get_Range("A1", Missing.Value);
Excel.Range endCell = worksheet.get_Range("B2", Missing.Value);
Excel.Range range = worksheet.get_Range(startCell, endCell);
range.Select();
```

you can type something like: 

``` csharp
Microsoft.Office.Interop.Excel.Application excel = AddIn.Application;
Excel.Workbook book = excel.ActiveWorkbook;            
Excel.Worksheet worksheet = book.Sheets.Item<Excel.Worksheet>("Sheet1");
Excel.Range range = worksheet.Range("A1:B2");
range.Select();
```

Much nicer, no? 

If you like working in C# and develop for Office, go get it [there](http://www.microsoft.com/downloads/details.aspx?FamilyId=46B6BF86-E35D-4870-B214-4D7B72B02BF9&displaylang=en), and check this [post](http://blogs.msdn.com/andreww/archive/2008/02/21/vsto-vsta-power-tools-v1-0.aspx)!
