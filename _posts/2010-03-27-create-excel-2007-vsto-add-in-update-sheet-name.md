---
layout: post
title: Create an Excel 2007 VSTO add-in&#58; wrapping up part 1
tags:
- Excel-2007
- Add-In
- TreeView
- Events
- OBA
- VSTO
- Workbook
- Worksheet
- Excel
- C#
---

{% include vsto-series.html %}

Today is the day, we will finally close “chapter one” of these series, with some minor improvements of the tree view display of open workbooks and worksheets. The final result of our work looks like this, with a TreeView displaying all open workbooks and worksheets, refreshing its contents (quasi) automatically, and with some home-made icons just for kicks.  

![FullTreeView]({{ site.url }}/assets/2010-03-27-FullTreeView_thumb.png)

Rather than a systematic walk-through, I will just explain the changes I implemented to the code base, which I have now posted on a [dedicated Wiki page](http://clear-lines.com/wiki/Anakin.ashx).  

[Download Anakin project code](http://clear-lines.com/wiki/GetFile.aspx?File=/CodeSamples/AnakinPart1.zip)
  
<!--more-->

## Updating the workbook and worksheet name  

In the previous installment, we demonstrated how to listen to Excel events to add and remove Workbooks and Worksheets from the TreeView contents. However, we left out one issue: when the user renames a Worksheet or saves a Workbook with a new name, the TreeView isn’t updated, and displays an incorrect name. We have the same problem here as before: Excel doesn’t expose an event for these changes, which complicates communication between the various parties involved.   

![DifficultCommunication]({{ site.url }}/assets/2010-03-27-DifficultCommunication.jpg)

In a comment to a [previous post]({{ site.url }}/2010/03/11/how-do-you-catch-that-an-Excel-Worksheet-has-been-deleted/), [Dennis Wallentin](http://xldennis.wordpress.com/) suggested to use a timer, which would check and re-synchronize the contents at regular intervals. I am sure this approach would work, but I chose to stick to the route I have followed so far, namely, update the contents whenever the user changes the active workbook or worksheet. It doesn’t prevent the TreeView from being out-of-synch temporarily, but it guarantees that it will refresh eventually – and it is much easier to implement.  

The issue with updating the name & author of the Workbook is that the `WorkbookViewModel` properties directly return the properties of the underlying Workbook – but when these change, the `WorkbookViewModel` is not being notified, and doesn’t notify the TreeView either.   

To achieve the desired result, we will first implement the [INotifyPropertyChanged](http://msdn.microsoft.com/en-us/library/system.componentmodel.inotifypropertychanged.aspx) interface on the `WorkbookViewModel`. The purpose of this interface is to “notify clients, typically binding clients, that a property value has changed”. We add the following elements to our code:  

``` csharp
using System.ComponentModel;

public class WorkbookViewModel : INotifyPropertyChanged
{
   public event PropertyChangedEventHandler PropertyChanged;

   protected void OnPropertyChanged(string propertyName)
   {
      var handler = this.PropertyChanged;
      if (handler != null)
      {
         handler(this, new PropertyChangedEventArgs(propertyName));
      }
   }
}
``` 

This will allow us to make the TreeView aware of changes in the view model properties it binds to, and refresh the display accordingly. 

The next step is to propagate change from the Workbook to the view model properties. We will implement this by refactoring the Name and Author properties, adding a backing field, and firing `OnPropertyChanged` when the property is updated – and by adding a method `UpdateDisplayProperties`, which when called will push values from the Workbook to the properties that need refreshing: 

``` csharp
public class WorkbookViewModel : INotifyPropertyChanged
{
   private string name;
   private string author;

   internal WorkbookViewModel(Excel.Workbook workbook)
   {
      this.name = workbook.Name;
      this.author = workbook.Author;
      // same as before
   }

   public string Name
   {
      get
      {
         return this.name;
      }

      set
      {
         if (value != this.name)
         {
            this.name = value;
            this.OnPropertyChanged("Name");
         }
      }
   }

   public string Author
   {
      get
      {
         return this.author;
      }

      set
      {
         if (value != this.author)
         {
            this.author = value;
            this.OnPropertyChanged("Author");
         }
      }
   }

   internal void UpdateDisplayProperties()
   {
      this.Name = this.workbook.Name;
      this.Author = this.workbook.Author;
   }
}
``` 

The only remaining task is to call `UpdateDisplayProperties()` when we believe the display should be updated. If we had an event capturing that a workbook has been saved, this is where we would hook it up; in the absence of that event, we will simply add this to the `ExcelViewModel` method responsible for updating the contents of the tree:

``` csharp
if (workbookIsOpen == false)
{
   this.workbookViewModels.Remove(workbookViewModel);
}
else
{
   workbookViewModel.UpdateDisplayProperties();
   // same old same old
}
``` 

We apply the same approach to the `WorksheetViewModel`, so that when the user changes the Sheet name, the TreeView will update once the Active worksheet/workbook is changed.

## Identifying the selected Worksheet

We have focused on displaying the open elements in the TreeView so far, but ultimately our goal is to be able to obtain a reference to the selected Worksheet, which we want to compare to the worksheet that is currently active.

I was somewhat surprised to discover that we can’t directly bind a “SelectedItem” from the TreeView to the view model. I assume this has to do with the fact that the TreeView can contain items of different nature. To address this, the best approach I found (*I would love to hear if someone has a better suggestion – especially if it involves binding through xaml without any code-behind*) is to listen to the `SelectedItemChanged` event on the TreeView, and pass the corresponding selected item to the `ViewModel`, if that item is a `WorksheetViewModel`. To achieve this, we add the following to the AnakinView:

``` xml
<TreeView ItemsSource="{Binding Path=ExcelViewModel.Workbooks}"
SelectedItemChanged="SelectedItemChanged"
Height="200">
``` 

… and add the following to the code-behind the control:

``` csharp 
private void SelectedItemChanged(object sender, RoutedPropertyChangedEventArgs<object> e)
{
   var worksheetViewModel = e.NewValue as WorksheetViewModel;
   if (worksheetViewModel != null)
   {
      var worksheet = worksheetViewModel.Worksheet;
      var model = this.DataContext as AnakinViewModel;
      if (model != null)
      {
         model.SelectedWorksheet = worksheet;
      }
   }
}
``` 

As a result, the `SelectedWorksheet` property of the `AnakinViewModel` will get set to the selected worksheet, whenever the user selects a `WorksheetViewModel` in the TreeView.

## Miscellaneous clean-up

The remaining changes are mostly cosmetic. 

* Rather than obtain the reference to the Excel Application in the `ExcelViewModel` through the Globals, I injected it explicitly in the constructor. I haven’t written unit tests for this add-in yet (shame on me), but when I do, this will help testability.
* I removed the button on top of the tree view, because it is completely useless now that the TreeView “auto-updates”.
* I refactored the method responsible for updating the workbooks and worksheets into 2 different methods, one responsible for updating the workbooks, the other one for updating the worksheets of a workbook.
* I added some images to the TreeView, following another [comment]({{ site.url }}/2010/03/08/create-excel-2007-vsto-add-in-using-treeview/) by [Dennis Wallentin](http://xldennis.wordpress.com/) (thanks so much for the feedback!). The images are added to the project, and the view models have a property that points to the image location, which allows us to bind the DataTemplates for the Workbook and Worksheet to an image. I would also welcome suggestions if people know of a better way to do this – the issue I have there is that while I located the images with the corresponding view model (e.g. the TreeView folder contains the WorksheetViewModel and Worksheet.bmp), the path required to bind is actually relative to AnakinViewModel. I would have much preferred to avoid this, because it means that if I decide to move the location of the view model & corresponding image, the path needs to be updated.

![Environmentally friendly fridge]({{ site.url }}/assets/2010-03-27-Beer_1.jpg) 

I am pretty sure this code could be improved upon, but I figured that it was good enough for now – so we will, at least temporarily, stop working on the TreeView, enjoy a well-deserved beer from our fridge (which is not quite as environment-friendly as this one, a definite [Epic Win](http://epicwinftw.com/)), and move on to the second part of this project: identifying the differences between the active worksheet and the worksheet that has been selected in the tree view, and navigating between these differences.

You can download the code as it stands right now from here – and I welcome your comments and suggestions!

[Download Anakin project code](http://clear-lines.com/wiki/GetFile.aspx?File=/CodeSamples/AnakinPart1.zip)
