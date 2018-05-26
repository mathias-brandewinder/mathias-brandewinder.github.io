---
layout: post
title: Create an Excel 2007 VSTO add-in&#58; Excel events
tags:
- Excel-2007
- Add-In
- OBA
- Events
- TreeView
- VSTO
- Worksheet
- Workbook
- Excel
- C#
---

{% include vsto-series.html %}

It’s time to wrap-up the first part of this tutorial, and hook up our tree view to Excel events, to update the contents of the tree when the user changes what is open.  

We need to capture the following: we need to update the TreeView when the user  

* Opens, creates or closes a workbook 
* Adds or deletes a worksheet 

## Added Worksheets and Workbooks  

Let’s start with adding a worksheet to a workbook. Excel exposes that event, through the `Workbook.NewSheet` event. We want the `WorkbookViewModel` to take care of his children, so we modify the constructor the following way:  

``` csharp
internal WorkbookViewModel(Excel.Workbook workbook)
{
   this.workbook = workbook;
   workbook.NewSheet += new Excel.WorkbookEvents_NewSheetEventHandler(workbook_NewSheet);
   // no change here, code stays the same
}

void workbook_NewSheet(object newSheet)
{
   var worksheet = newSheet as Excel.Worksheet;
   if (worksheet != null)
   {
      var worksheetViewModel = new WorksheetViewModel(worksheet);
      this.worksheetViewModels.Add(worksheetViewModel);
   }
}
``` 

Creating event handlers can be a bit tedious; fortunately, Visual Studio simplifies the task quite a bit. When you type workbook.NewSheet +=, you should see a tooltip appear, which “suggests” an event handler. Type Tab, and Tab again – Visual Studio will create for you the empty event handler, with the right arguments and types, where you can now insert the logic of what should happen when the event is triggered.

<!--more-->

We will do some minor code refactoring here, to remove some code duplication, the explicit event handler declaration and clean up the method names. Both the constructor and handler perform the same validation when adding a sheet – let’s extract it into a method `AddWorksheet`, and rename the handler to something more palatable, to end up with the following code:

``` csharp
internal WorkbookViewModel(Excel.Workbook workbook)
{
   this.workbook = workbook;
   workbook.NewSheet += this.AddSheet;
   this.worksheetViewModels = new ObservableCollection<WorksheetViewModel>();
   var worksheets = workbook.Worksheets;
   foreach (var sheet in worksheets)
   {
      this.AddSheet(sheet);
   }
}

private void AddSheet(object newSheet)
{
   var worksheet = newSheet as Excel.Worksheet;
   if (worksheet != null)
   {
      var worksheetViewModel = new WorksheetViewModel(worksheet);
      this.worksheetViewModels.Add(worksheetViewModel);
   }
}
``` 

If you run the add-in in debug mode now, you’ll see the following: if you expand the workbook in the TreeView, and add a Worksheet, the TreeView will automatically refresh, and add that sheet to the list. This happens because we have established a binding to the `ObservableCollection` of `WorksheetViewModel`(s) in the `WorkbookViewModel`; as a result, the observable collection notifies the control that the collection has changed, and automatically updates its display.

Let’s do the same type of transformation, at the `ExcelViewModel` level. We will leverage the following events, which should be self-explanatory: `NewWorkbook`, `WorkbookBeforeClose`, `WorkbookBeforeSave` and `WorkbookOpen`.

We need a reference to the Excel application to hook our events; temporarily, we will access it in the constructor through `Globals.ThisAddIn.Application`. However, we run into a small issue here. When you type in the following code in the constructor:

``` csharp
Excel.Application excel = Globals.ThisAddIn.Application;
excel.NewWorkbook+=
``` 

… instead of auto-completing the handler, we get a warning that `NewWorkbook` is ambiguous. The reason for this can be understood if you dig into the `Excel.Application` interface. `Excel.Application` implements 2 interfaces, `_Application`, which covers most of the Excel methods and properties, and `AppEvents_Event`, which exposes all the Excel events. The reason for this somewhat confusing design isn’t quite clear to me, but if you look through the members of each of these two interfaces, you’ll see that `_Application` has a `NewWorkbook` property, and `AppEvents_Event` a `NewWorkbook` event, and these two names collide.

![EventNameCollision]({{ site.url }}/assets/2010-03-17-EventNameCollision_thumb.png)

To resolve that issue, we simply need to disambiguate our call, by explicitly casting `Excel.Application` to the interface we are interested in, with the following code:

``` csharp
internal ExcelViewModel()
{
   this.workbooks = new ObservableCollection<WorkbookViewModel>();
   Excel.Application excel = Globals.ThisAddIn.Application;
   ((Excel.AppEvents_Event) excel).NewWorkbook +=
      new Excel.AppEvents_NewWorkbookEventHandler(ExcelViewModel_NewWorkbook);
   this.RefreshWorkbooks();
}

private void ExcelViewModel_NewWorkbook(Excel.Workbook newWorkbook)
{
   throw new System.NotImplementedException();
}
``` 

The other event related to new workbooks, `Application.WorkbookOpen`, does not have that collision issue, so the cast here isn’t required, and, after some cleanup and refactoring, we end up with the following code, which automatically updates the TreeView when workbooks are opened or created:

``` csharp
internal ExcelViewModel()
{
   this.workbookViewModels = new ObservableCollection<WorkbookViewModel>();
   Excel.Application excel = Globals.ThisAddIn.Application;
   ((Excel.AppEvents_Event) excel).NewWorkbook += this.AddWorkbook;
   excel.WorkbookOpen += this.AddWorkbook;
   var workbooks = excel.Workbooks;
   foreach (var workbook in workbooks)
   {
      var book = workbook as Excel.Workbook;
      if (book != null)
      {
         var workbookViewModel = new WorkbookViewModel(book);
         this.workbookViewModels.Add(workbookViewModel);
      }
   }
}

private void AddWorkbook(Excel.Workbook newWorkbook)
{
   var workbookViewModel = new WorkbookViewModel(newWorkbook);
   this.workbookViewModels.Add(workbookViewModel);
}
``` 

## Removed worksheets and Workbooks

Now we just need to perform the reverse operations when a workbook or a Worksheet is closed – and this is where the pain begins. I had forgotten that Excel – whether through VBA or VSTO - exposes only a surprising limited set of events regarding deletions, which are rather inadequate to track whether a workbook or worksheet has been closed.

There is simply [no event to signal Worksheet deletion]({{ site.url }}/2010/03/11/how-do-you-catch-that-an-Excel-Worksheet-has-been-deleted/), and `Application.WorkbookBeforeClose` is only marginally helpful. It captures whether the user requested the workbook being closed, which is useful in some scenarios (preventing closure if some conditions are not met), but the user can still chose to cancel after the event has been fired. As a result, the Workbook could end up staying open even though that event fired. So we have no direct reliable way to know whether either a Workbook or Worksheet is gone from the workspace, and should be removed from the TreeView.

So we’ll do with what we have available. Typically, when a user closes a workbook or worksheet, that item is “active” – and upon deletion, the active element is changed. So rather than track whether items have been closed, we will look for changes in the active workbook and worksheet, and whenever this occurs, we will run a cleanup procedure. We will iterate over every item in the TreeView, and if it is no longer open at that point, we will remove it from the tree. 

As I explained in [my previous post]({{ site.url }}/2010/03/11/how-do-you-catch-that-an-Excel-Worksheet-has-been-deleted/), there is still a chance that the tree is out of sync with Excel, because it is technically feasible to delete an element without impacting active items, but this will capture the most standard use case, and re-sync over time, as soon as the user changes the active element in Excel.

Here is the code I ended up with. First, we subscribe to the events `WorkbookActivate` and `SheetActivate` in the `ExcelViewModel` constructor:

``` csharp
internal ExcelViewModel()
{
   this.workbookViewModels = new ObservableCollection<WorkbookViewModel>();
   Excel.Application excel = Globals.ThisAddIn.Application;
   ((Excel.AppEvents_Event)excel).NewWorkbook += this.AddWorkbook;
   excel.WorkbookOpen += this.AddWorkbook;
   excel.WorkbookActivate += ActiveWorkbookChanged;
   excel.SheetActivate += ActiveSheetChanged;
   // same as before
}
``` 

Then, in the handlers for these events, we call a common routine, which iterates over the tree elements and deletes “obsolete” ones:

``` csharp
private void ActiveSheetChanged(object activatedSheet)
{
   this.RemoveClosedWorkbooksAndWorksheets();
}

private void ActiveWorkbookChanged(Excel.Workbook activatedWorkbook)
{
   this.RemoveClosedWorkbooksAndWorksheets();
}

private void RemoveClosedWorkbooksAndWorksheets()
{
   var workbooks = Globals.ThisAddIn.Application.Workbooks;
   foreach (var workbookViewModel in this.workbookViewModels)
   {
      var workbookIsOpen = false;
      foreach (var workbook in workbooks)
      {
         if (workbookViewModel.Workbook == workbook)
         {
            workbookIsOpen = true;
            break;
         }
      }

      if (workbookIsOpen == false)
      {
         this.workbookViewModels.Remove(workbookViewModel);
      }
      else
      {
         var workbook = workbookViewModel.Workbook;
         var worksheets = workbook.Worksheets;
         foreach (var worksheetViewModel in workbookViewModel.Worksheets)
         {
            var worksheetIsOpen = false;
            foreach (var sheet in worksheets)
            {
               var worksheet = sheet as Excel.Worksheet;
               if (worksheet != null)
               {
                  if (worksheet == worksheetViewModel.Worksheet)
                  {
                     worksheetIsOpen = true;
                     break;
                  }
               }
            }

            if (worksheetIsOpen == false)
            {
               workbookViewModel.Worksheets.Remove(worksheetViewModel);
            }
         }
      }
   }
}
``` 

I have to confess that I am not overly proud of this code, for a few reasons. First, stylistically, the `RemoveClosedWorkbooksAndWorksheets` method is too long and could (should) be broken into two methods, one for Workbooks, one for Worksheets, but that’s easy enough to fix. Then, we are running a complete “refresh” pass over every element, every time the user activates a worksheet and workbook. It shouldn’t create performance problems, because the number of elements is fairly small, and we will need to track these changes anyways later for other reasons, but just thinking of how much nicer it would have looked had the right event hook been available makes me unhappy… Then, while the foreach loops are pretty clear, they are also clumsy, especially after you have had a taste of Linq – but I couldn’t manage to use Linq here (I haven’t tried very hard, though). Finally, this may be a misplaced concern, but because we observe deletions after they have taken place, we have no opportunity to remove the event subscription in `WorkbookViewModel`, or clean up the references to the now-gone Workbook and Worksheet objects inside the view models. I don’t think it really matters, and I can’t think of how to address the issue anyways, so I’ll have to let go I guess.

As an aside, I have left out another update of the TreeView which would be needed, too, but is complicated for the same reason, the lack of adequate events: we would also need to update the name of the Workbook when it gets saved, and of the Worksheet when it is renamed. This could be done in our “refresh” loop, by updating the property of elements that are not deleted – I won’t illustrate how to do it here, but will put it in the code when I post it sometime later this week, once I have completed cleanup.

If you have suggestions on improving this code, or simply questions about it, please let me know! 

In the next installments, now that we are reasonably done with the TreeView, we will focus on a totally different topic: how to generate comparisons between the current active sheet, and the sheet selected in the treeview, and how to navigate through these differences and reconcile them if needed. Stay tuned!
