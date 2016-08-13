---
layout: post
title: Add an Excel In-Cell DropDown in C#
tags:
- User-Interface
- Data-Validation
- Excel
- C#
- Tips-And-Tricks
---

Excel Data Validation provides a nice mechanism to help users select from a set of acceptable choices, by adding a drop-down directly in a cell and displaying the list of options when the cell is selected. To do that within Excel, just go to the Data ribbon, and the Data Validation button displays a dialog like the one below. Selecting allow “List”, and typing in a few comma-separated values in the Source section will do the job. How would we go about to do the same thing from .NET?   

![DataValidationDialog]({{ site.url }}/assets/2011-01-23-DataValidationDialog_thumb.png)  

Turns out it’s not very complicated, as I just found out. Just create a [Validation](http://msdn.microsoft.com/en-us/library/microsoft.office.interop.excel.validation(v=office.14).aspx) object, Add it to a Range, and you are good to go. Here is a code snippet to do just that, from a VSTO project:  

``` csharp
var excel = Globals.ThisAddIn.Application;
var worksheet = (Worksheet)excel.ActiveSheet;
         
var list = new List<string>();
list.Add("Alpha");
list.Add("Bravo");
list.Add("Charlie");
list.Add("Delta");
list.Add("Echo");

var flatList = string.Join(",", list.ToArray());

var cell = (Range)worksheet.Cells[2, 2];
cell.Validation.Delete();
cell.Validation.Add(
   XlDVType.xlValidateList,
   XlDVAlertStyle.xlValidAlertInformation,
   XlFormatConditionOperator.xlBetween,
   flatList,
   Type.Missing);

cell.Validation.IgnoreBlank = true;
cell.Validation.InCellDropdown = true;
``` 

Nothing fancy, but as usual it took a bit of searching to figure out the right enumerations to use in the method call – hopefully it will be useful to someone else!

In the process, I found out two things. First, I wondered what would happen if I tried to set through code the contents of a cell to a value that isn’t valid. The answer is, Data Validation doesn’t validate anything in that case – it appears to be strictly a UI mechanism. Then, I realized that I had no clear idea what the 2nd and 3rd tab in the dialog do; turns out, these are potentially pretty cool. Input Message behaves like a ToolTip that shows up on cell selection, with a title and message, in a way similar to Comments, but not editable. Error Alert defines the message that should show up when an invalid value is entered – and allows to disable the Error Alert if need be. So if all you wanted was a DropDown with “suggested” choices, you could just disable the error alert, and you would have a cell with a DropDown, where users could still type any freeform text they please. 
