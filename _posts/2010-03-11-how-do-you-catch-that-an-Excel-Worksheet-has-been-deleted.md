---
layout: post
title: How do you catch that a Worksheet has been deleted?
tags:
- Excel
- VSTO
- Worksheet
- Event
- Delete
---

While working on my VSTO Excel add-in tutorial, I came across the following issue: I need to know whether a worksheet has been deleted. The reason I care is that when it happens, I need to update the display of the worksheets that are currently open, and remove it from there.  

I was very surprised to find out that there seems to be no event for this. The `Application` object, which represents the Excel application, has a `WorkbookBeforeClose` event; the Workbook object has an event `BeforeClose`, triggered when the Workbook is being closed. So naturally, I expected to find something equivalent for the Worksheet object, at either the Application, Workbook, Sheets, Worksheets, or Worksheet level – no such luck.  

I looked around on the web, and from what I can tell, there is no native event for this, and I came across multiple posts advocating to handle this through `Worksheet.Activate` and/or `Worksheet.Deactivate`. I see how this catches the obvious use case, namely, the user selects the sheet and deletes it – which causes the sheet to be activated, and then another worksheet to be activated once the deletion is performed. Unfortunately, this doesn’t catch all the cases: as far as I can tell, it is perfectly possible to delete a worksheet without ever changing which sheet is active. To prove the point, create a workbook, and add the following macro:  

``` vb
Public Sub DeleteSheet3()
    Application.DisplayAlerts = False
    Sheets("Sheet3").Delete
    Application.DisplayAlerts = True
End Sub
``` 

<!--more-->

This (silly) VBA macro looks for the sheet named “Sheet3” in the Active Workbook, and deletes it – and if the user executes that macro while another sheet is active – say, Sheet1 – the active worksheet won’t change.

In a desperate attempt, I looked into the SheetChange event from the Workbook class, but this was another miserable failure – this one catches the changes in the contents of the ranges, but doesn’t blink when the sheet is deleted.

I guess I’ll have to accept that the best I can do is through the sheet activation, but I am really puzzled by what seems to me an incomprehensible oversight – and a very annoying one.

For the Excel and VSTO gurus out there, am I missing something obvious? Is there a secret Jedi trick which will unambiguously reveal that a worksheet is gone, or that the Worksheets collection has been modified?
