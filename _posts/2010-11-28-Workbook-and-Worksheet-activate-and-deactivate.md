---
layout: post
title: Workbook and Worksheet activate and deactivate
tags:
- C#
- VSTO
- Excel
---

Sometimes, you need to know when your user decided to move to another Worksheet in Excel. Fortunately, Excel exposes some events for this. At the workbook level, `Workbook.SheetActivate` and `Workbook.SheetDeactivate` are fired when the user activates or deactivates a sheet in the Workbook, and at the application level, `Application.WorkbookActivate` and `Application.WorkbookDeactivate` are triggered when the user changes Workbooks.

This looks all nice and simple, except that there is a small catch, which caused me a bit of grief on my current project. I naively thought that when a user activated a new Workbook, it would fire `WorkbookActivate`, and `SheetActivate`. Wrong – when you activate a new Workbook, only `WorkbookActivate` is triggered.

The following VSTO code illustrates the point: Excel traps when a new Workbook is added, and begins tracking the Sheet activation/deactivation for that new Workbook. 

``` csharp
private void ThisAddIn_Startup(object sender, System.EventArgs e)

{
    var excel = this.Application;
    WorkbookAdded(excel.ActiveWorkbook);
    ((Excel.AppEvents_Event)this.Application).NewWorkbook += WorkbookAdded;
    excel.WorkbookOpen += WorkbookAdded;
    excel.WorkbookActivate += WorkbookActivated;
    excel.WorkbookDeactivate += WorkbookDeactivated;
}

private void WorkbookAdded(Excel.Workbook workbook)
{
    workbook.SheetActivate += SheetActivated;
    workbook.SheetDeactivate += SheetDeactivated;
}

private void WorkbookActivated(Excel.Workbook workbook)
{
    MessageBox.Show("Workbook activated.");
}

private void WorkbookDeactivated(Excel.Workbook workbook)
{
    MessageBox.Show("Workbook deactivated.");
}

private void SheetActivated(object sheet)
{
    MessageBox.Show("Sheet activated.");
}

private void SheetDeactivated(object sheet)
{
    MessageBox.Show("Sheet deactivated.");
}
```

If you run this code, you will note that when you change sheets within a Workbook, the Message Box “Sheet deactivated” pops up, followed by “Sheet activated”. However, if you add multiple workbooks, and start changing workbooks, only “Workbook activated” / “Workbook deactivated” shows up.

The morale of the story is that if you are interested in tracking when a user changed the active worksheet across workbooks, you can’t simply rely on SheetActivated: you will need to look out for Workbook level events, and when these occur, figure out through the Workbook active worksheet which sheet has been activated or deactivated.

I think the reason this caught me off-guard is that I had this Worksheet-centric mental image of Excel: when I am changing workbooks, my goal is to select a Worksheet in that Workbook, the Workbook is simply a means to an end – and I expected the events to reflect that. However, if you consider the Workbook as its own isolated entity, it makes sense: when I leave a Workbook, it simply becomes invisible, but otherwise nothing changed: the Worksheet that is active remains active, and will still be active when I come back later.

The other interesting pitfall is that when you start Excel, there is a Workbook active – but because it is created before you can begin trapping events, you have to register it manually if you want to track its behavior as well.
