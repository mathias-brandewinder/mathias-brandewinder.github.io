---
layout: post
title: Converting Excel date format to System.DateTime
tags:
- DateTime
- Excel
- C#
- Convert
- RowTest
- NUnit
- TDD
- Testing
---

*Edit, Sept 5, 2008: nothing incorrect in the following post; however, if I had Google'd first, I would have found that DateTime date = DateTime.FromOADate(d), where d is a double, does exactly the job...*

The project I am currently working on requires reading some data from an Excel workbook into a .NET calculation engine written in C#. Most of my reads follow this pattern: read a named range into an array of objects, then convert the object to the appropriate .NET type.

``` csharp
public static object[,] GetRangeAsArray(Excel.Worksheet sheet, string rangeName)
{
    Excel.Range range = sheet.get_Range(rangeName, Missing.Value);
    object[,] rangeAsArray = range.Value2 as object[,];
    return rangeAsArray;
} 
```

However, I ran into an issue reading dates. Excel stores dates as doubles, which encode the number of days elapsed since January 0, 1900 (Yes, January 0). As a result, the object stored in the array is a double, and the Convert.ToDateTime(double) method throws an InvalidCastExpression, so standard conversion doesn&rsquo;t work.
If you look a bit deeper into it (here is a very [comprehensive page](http://www.cpearson.com/excel/datetime.htm)
 on the topic), you will discover some interesting idiosyncrasies of the date encoding in Excel. For instance, back in the days, the Excel team knowingly implemented a bug to replicate a known bug of Lotus, for the sake of backwards compatibility.

Here is the quick method I wrote to perform that conversion, addressing these issues:

``` csharp 
public static DateTime ConvertToDateTime(double excelDate)
{
    if (excelDate < 1)
    {
        throw new ArgumentException("Excel dates cannot be smaller than 0.");
    }
    DateTime dateOfReference = new DateTime(1900, 1, 1);
    if (excelDate > 60d)
    {
        excelDate = excelDate - 2;
    }
    else
    {
        excelDate = excelDate - 1;
    }
    return dateOfReference.AddDays(excelDate);
}
```

<!--more-->

The exercise was interesting to me, because it was a perfect case to try out the [`[RowTest]` and `[Row]`](http://www.andreas-schlapsi.com/2008/03/31/nunit-247-includes-rowtest-extension/) attributes which now ship with NUnit.

The classic NUnit version of the test would look something like this:

``` csharp 
[Test]
public void ConvertExcelDateToDateTimeClassic()
{
    double excelDate = 1.00;
    DateTime expectedDate = new DateTime(1900, 1, 1);
    DateTime date = ExcelTools.ConvertToDateTime(excelDate);
    Assert.AreEqual(expectedDate, date);
}
```

However, in order to replicate the multiple border cases, you would have to write the same test over and over again. `[RowTest]` allows to do this in a very compact form, with this syntax:

``` csharp 
[RowTest]
[Row(1.0, 1900, 1, 1)]
[Row(59.0, 1900, 2, 28)]
[Row(60.0, 1900, 3, 1)]
[Row(61.0, 1900, 3, 1)]
[Row(36526.0, 2000, 1, 1)]
[Row(401769.0, 3000, 1, 1)]
public void ConvertExcelDateToSimpleDateTime(double excelDate, int year, int month, int day)
{
    DateTime expectedDate = new DateTime(year, month, day);
    DateTime date = ExcelTools.ConvertToDateTime(excelDate);
    Assert.AreEqual(expectedDate, date);
} 
``` 

I struggled a bit with getting it to work initially, because it seemed that I was missing a reference and the attributes were not recognized. Thanks to [Donn Felker](http://blog.donnfelker.com/post/NUnit-247-and-the-RowTest-Attribute-with-Example.aspx) for the walkthrough on what to include to "make it work"!
