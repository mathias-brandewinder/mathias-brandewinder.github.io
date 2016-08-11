---
layout: post
title: Create an Excel 2007 VSTO add-in&#58; read worksheets
tags:
- VSTO
- Add-In
- Excel-2007
- Worksheet
- Func
- OBA
- MVVM
- Command
- Excel
- C#
---

{% include vsto-series.html %}

Today we will write code that reads the contents (values & formulas) of the two selected worksheets, generates a list of their differences, and feeds it to the view that displays the comparison. The code isn’t particularly complicated, and uses mostly ideas which have been seen in the previous posts, so rather than break this into multiple small posts, I chose to bite the bullet and get done with a large chunk, all at once. I hope you survive it and bear with me – promise, we are almost there!  

## Extracting the comparison from the comparison ViewModel  

In the previous installment, I created a stub to provide a “canned” list of differences to the `ComparisonViewModel`, so that we would have something to display. It’s time to replace that stub, and generate a real comparison between 2 worksheets. We could add the required code inside the existing classes; however, we will likely have a good amount of logic, so to avoid clutter, and to keep our design tight, we will extract that responsibility into its own class, the `WorksheetsComparer`.  

First, let’s create a stub for the class, in the Comparison folder; its key method will be `FindDifferences`, and we will temporarily move the “fake” comparison that was in the `ComparisonViewModel` into that method:  

``` csharp
public class WorksheetsComparer
{
   public static List<Difference> FindDifferences(Excel.Worksheet firstSheet, Excel.Worksheet secondSheet)
   {
      // Temporary code
      var difference1 = new Difference() { Row = 3, Column = 3 };
      var difference2 = new Difference() { Row = 3, Column = 5 };
      var difference3 = new Difference() { Row = 5, Column = 8 };
      
      var differences = new List<Difference>();
      differences.Add(difference1);
      differences.Add(difference2);
      differences.Add(difference3);

      return differences;
   }
}
``` 

Now we need to hook it up to the add-in. We will add a button to the AnakinView, which, when clicked, will call `WorksheetsComparer.FindDifferences`, and pass the result to the `ComparisonViewModel`. Let’s first plug a button in the AnakinView, and bind it to a `Command` on the ViewModel, `GenerateComparison`:

``` xml
<StackPanel Margin="5">
  <Comparison:ComparisonView x:Name="ComparisonView" />
  <Button Command="{Binding GenerateComparison}" 
          Content="Compare" Width="75" Height="25" Margin="5"/>
``` 

Following the same approach as in the previous post, we implement the command in the View Model (only added code is displayed): 

``` csharp
public class AnakinViewModel
{
   private ICommand generateComparison;

   public ICommand GenerateComparison
   {
      get
      {
         if (this.generateComparison == null)
         {
            this.generateComparison = new RelayCommand(GenerateComparisonExecute);
         }
         return this.generateComparison;
      }
   }

   private void GenerateComparisonExecute(object target)
   {
      var differences = WorksheetsComparer.FindDifferences(null, null);
      this.comparisonViewModel.SetDifferences(differences);
   }
}
``` 

<!--more-->

Because we have a stub in place for `FindDifferences`, we can pass null as arguments for the time being – later on, we’ll replace these by the Active Worksheet and the selected worksheet from the TreeView. The project won’t build, because the `ComparisonViewModel` doesn’t have a `SetDifferences` method – let’s fix that:

``` csharp
internal void SetDifferences(List<Difference> newDifferences)
{
   this.differences.Clear();
   if (newDifferences != null)
   {
      this.differences.AddRange(newDifferences);
   }

   if (this.differences.Count>0)
   {
      this.SelectedDifference = this.differences[0];
   }
   else
   {
      this.SelectedDifference = null;
   }
}
``` 

Now we can remove the temporary code from the `ComparisonViewModel` constructor:

``` csharp
public ComparisonViewModel(Excel.Application excel)
{
   this.excel = excel;
   this.differences = new List<Difference>();
}
``` 

Before fleshing out the `WorksheetsComparer` class, let’s clean up the code a bit.

First, a small refactoring. Both `GoToNextDifferenceExecute` and `GoToPreviousDifferenceExecute` select a difference, and navigate to it. Let’s move the `NavigateToDifference` call inside the setter for `SelectedDifference`, so that the code duplication is gone, and whenever the selection changes, we are guaranteed that the difference will be selected on the worksheet:

``` csharp
public Difference SelectedDifference
{
   // same as before
   set
   {
      if (this.selectedDifference != value)
      {
         this.selectedDifference = value;
         this.NavigateToDifference(this.SelectedDifference);
         OnPropertyChanged("SelectedDifference");
      }
   }
}
``` 

Now that we plan on generating actual comparisons, we could have no difference at all, which means that the `SelectedDifference` could be null. A guard clause in `NavigateToDifference` and some minor modifications in the `CanGoToNextDifference` , `CanGoToPreviousDifference` methods will take care of that:

``` csharp
private bool CanGoToPreviousDifference(object arg)
{
   if (this.DifferencesAreNullOrEmpty())
   {
      return false;
   }

   return (this.differences.IndexOf(SelectedDifference) > 0);
}

private void NavigateToDifference(Difference difference)
{
   if (difference==null)
   {
      return;         
   }

   var row = difference.Row;
   var column = difference.Column;
   var activeSheet = (Excel.Worksheet)this.excel.ActiveSheet;
   var differenceLocation = activeSheet.Cells[row, column];
   this.excel.Goto(differenceLocation, Type.Missing);
}

private bool DifferencesAreNullOrEmpty()
{
   if (this.differences == null)
   {
      return true;
   }
   if (this.differences.Count == 0)
   {
      return true;
   }

   return false;
}
``` 

## Fixing a bug

![Door-Fail]({{ site.url }}/assets/2010-04-26-Door-Fail.jpg)

If you run the code at that point, you will notice that there is a problem: when you click the button, nothing happens. The Previous and Next buttons are initially disabled, as they should (because there is initially no difference), but once Compare is clicked, there should be differences to navigate through.

This comes from a problem with the code I presented last time: the `AnakinViewModel` and `ComparisonViewModel` are not properly connected, and now that we are passing a list of differences from one to the other, the issue shows up with no mercy.

Here is the problem, which took me a while to spot: when the add-in is initialized, a `ComparisonViewModel` is created, and hooked to the ComparisonView of the AnakinView: 

``` csharp
private void ThisAddIn_Startup(object sender, System.EventArgs e)
{
   //
   var anakinViewModel = new AnakinViewModel(excel);
   var anakinView = taskPaneView.AnakinView;
   anakinView.DataContext = anakinViewModel;

   var comparisonViewModel = new ComparisonViewModel(excel);
   var comparisonView = anakinView.ComparisonView;
   comparisonView.DataContext = comparisonViewModel;
}
``` 

But… the `AnakinViewModel` constructor instantiates its own `ComparisonViewModel`:

``` csharp
internal AnakinViewModel(Excel.Application excel)
{
   this.excel = excel;
   this.comparisonViewModel = new ComparisonViewModel(excel);
}
``` 

As a result, we have two `ComparisonViewModel` instances – one is connected to the View, and the other is not, but that’s the one we pass the list of differences to. No surprise the user interface doesn’t respond.

I fixed this the following way: I added a property to access the `ComparisonViewModel` from the `AnakinViewModel`:

``` csharp
public class AnakinViewModel
{
  private ComparisonViewModel comparisonViewModel;

  internal AnakinViewModel(Excel.Application excel)
  {
     this.excel = excel;
     this.comparisonViewModel = new ComparisonViewModel(excel);
  }

  internal ComparisonViewModel ComparisonViewModel
  {
     get
     {
        return this.comparisonViewModel;
     }
  }
``` 

and I modified the `ThisAddin` setup method:

``` csharp
private void ThisAddIn_Startup(object sender, System.EventArgs e)
{
   // same as before
   var excel = this.Application;
   var anakinViewModel = new AnakinViewModel(excel);
   var anakinView = taskPaneView.AnakinView;

   var comparisonViewModel = anakinViewModel.ComparisonViewModel;
   var comparisonView = anakinView.ComparisonView;

   comparisonView.DataContext = comparisonViewModel;
   anakinView.DataContext = anakinViewModel;
}
``` 

Not the most elegant way to resolve this, but it gets the job done.

## Reading the content of worksheets to generate a comparison

It’s time to replace the fake list of differences with something real. For this part, I will leverage a post I wrote some time back, explaining how to [read values and formulas from a spreadsheet]({{ site.url}}/2009/10/20/Read-the-contents-of-a-worksheet-with-C/); I’ll simply explain my code, rather than go step by step this time:

``` csharp
public class WorksheetsComparer
{
   public static List<Difference> FindDifferences(Excel.Worksheet firstSheet, Excel.Worksheet secondSheet)
   {
      var differences = new List<Difference>();

      try
      {
         var lastCellFirst = GetLastCell(firstSheet);
         var lastCellSecond = GetLastCell(secondSheet);

         var rows = Math.Max(lastCellFirst.Row, lastCellSecond.Row);
         var columns = Math.Max(lastCellFirst.Column, lastCellSecond.Column);

         var firstValues = ReadValues(firstSheet, rows, columns);
         var firstFormulas = ReadFormulas(firstSheet, rows, columns);
         var secondValues = ReadValues(secondSheet, rows, columns);
         var secondFormulas = ReadFormulas(secondSheet, rows, columns);

         for (int row = 1; row <= rows; row++)
         {
            for (int column = 1; column <= columns; column++)
            {
               var firstValue = ConvertToString(firstValues[row, column]);
               var secondValue = ConvertToString(secondValues[row, column]);
               var firstFormula = ConvertToString(firstFormulas[row, column]);
               var secondFormula = ConvertToString(secondFormulas[row, column]);

               if (firstValue != secondValue || firstFormula != secondFormula)
               {
                  var difference = new Difference();
                  difference.Row = row;
                  difference.Column = column;
                  differences.Add(difference);
               }
            }
         }
      }
      catch
      {
         var message = string.Format("Failed to read and compare {0} and {1}", firstSheet.Name, secondSheet.Name);
         MessageBox.Show(message);
         differences = new List<Difference>();
      }

      return differences;
   }

   private static Excel.Range GetLastCell(Excel.Worksheet worksheet)
   {
      var lastCell = worksheet.Cells.SpecialCells(Excel.XlCellType.xlCellTypeLastCell, Type.Missing);
      return lastCell;
   }

   private static string ConvertToString(object content)
   {
      if (content == null)
      {
         return string.Empty;
      }

      return Convert.ToString(content);
   }

   private static object[,] ReadValues(Excel.Worksheet sheet, int lastRow, int lastColumn)
   {
      object[,] cellValues;
      var firstCell = sheet.get_Range("A1", Type.Missing);
      var lastCell = (Excel.Range)sheet.Cells[lastRow, lastColumn];

      if (lastRow == 1 && lastColumn == 1)
      {
         cellValues = new object[2, 2];
         cellValues[1, 1] = firstCell.Value2;
      }
      else
      {
         Excel.Range worksheetCells = sheet.get_Range(firstCell, lastCell);
         cellValues = worksheetCells.Value2 as object[,];
      }

      return cellValues;
   }

   private static object[,] ReadFormulas(Excel.Worksheet sheet, int lastRow, int lastColumn)
   {
      object[,] cellFormulas;
      var firstCell = sheet.get_Range("A1", Type.Missing);
      var lastCell = (Excel.Range)sheet.Cells[lastRow, lastColumn];

      if (lastRow == 1 && lastColumn == 1)
      {
         cellFormulas = new object[2, 2];
         cellFormulas[1, 1] = firstCell.Formula;
      }
      else
      {
         Excel.Range worksheetCells = sheet.get_Range(firstCell, lastCell);
         cellFormulas = worksheetCells.Formula as object[,];
      }

      return cellFormulas;
   }
}
``` 

The code is rather straightforward. It finds the last cell of each worksheet, so that the smallest block of cells that contains all values from both worksheets can be read. I chose to go this route, because it simplifies the code: we read data into arrays of the same dimension, so we can simply traverse all rows and columns, without having to verify whether we passed the upper bound of one of the arrays.

The contents of every cell is read, transforming null contents into an empty string; if either the value or formula are different, a difference is added to the list.

I wrapped the read procedure in a try/catch block, to avoid issues such as password-protected cells, returning an empty list in case of failure – and showing a warning message box.

Now we just need to pass the active worksheet and the worksheet selected in the tree view to the procedure, and we are done. We modify the AnakinViewModel to do just that, adding also a method CanGenerateComparison, which verifies that there is a worksheet selected, and disables the button if not:

``` csharp
public ICommand GenerateComparison
{
   get
   {
      if (this.generateComparison == null)
      {
         this.generateComparison = new RelayCommand(GenerateComparisonExecute, CanGenerateComparison);
      }

      return this.generateComparison;
   }
}

private void GenerateComparisonExecute(object target)
{
   var currentSheet = this.excel.ActiveSheet as Excel.Worksheet;
   var selectedSheet = this.SelectedWorksheet;

   var differences = WorksheetsComparer.FindDifferences(currentSheet, selectedSheet);
   this.comparisonViewModel.SetDifferences(differences);
}

private bool CanGenerateComparison(object target)
{
   return this.SelectedWorksheet != null;
}
``` 

*I also made a slight modification in the `SelectedItemChanged` method behind the AnakinView, to make sure that when the user selects a Workbook, the `SelectedWorksheet` is set to null.*

And we are done. Let’s run the code, and check that it works: create a workbook, with a few values – straight strings, no formulas:

![FirstSheet]({{ site.url }}/assets/2010-04-26-FirstSheet_thumb.png)

Then, copy the contents into sheet2, with 2 modifications: in cell B3, enter “Jumps”, so that the value is different from Sheet1, and in cell C3, enter “=B3”, so that the value is equal in both sheets, but not the formula.

![SecondSheet]({{ site.url }}/assets/2010-04-26-SecondSheet_thumb.png)

Select Sheet1 in the tree, the Compare button lights up because it’s ready to compare – and run it. If you navigate back and forth, it will select cells B3 and C3, as we hoped.

## Using Func<> to refactor the comparison

After this valiant effort, it’s time for some gratuitous fun. A reliable sign of poor design is code duplication, and the two methods `ReadValues` and `ReadFormulas` reek of duplication; essentially, they do exactly the same thing, except that inside the loop, where one reads `Value2` from the range, the other gets `Formula`.

Just for kicks, let’s resolve that problem, by using [a Func<T, TResult> delegate]({{ site.url }}/2010/04/09/Funky-strategy-pattern/). Instead of hard-coding what property should be called on the range, we will keep one common loop, and pass it the function to execute as an “open” argument. 

Both `Value2` and `Formula` apply to a `Range`, and return an `object`, so the signature of our `Func<T, TResult>` (which represents a function that takes a `T` as an argument, and returns a `TResult`) must be `Func<Excel.Range, object>`. The resulting code is much more elegant:

``` csharp
private static object[,] ReadContents(Excel.Worksheet sheet, Func<Excel.Range, object> reader, int lastRow, int lastColumn)
{
   object[,] cellContents;
   var firstCell = sheet.get_Range("A1", Type.Missing);
   var lastCell = (Excel.Range)sheet.Cells[lastRow, lastColumn];

   if (lastRow == 1 && lastColumn == 1)
   {
      cellContents = new object[2, 2];
      cellContents[1, 1] = reader(firstCell);
   }
   else
   {
      Excel.Range worksheetCells = sheet.get_Range(firstCell, lastCell);
      cellContents = reader(worksheetCells) as object[,];
   }

   return cellContents;
}

private static object[,] ReadValues(Excel.Worksheet sheet, int lastRow, int lastColumn)
{
   var reader = new Func<Excel.Range, object>(r => r.Value2);
   object[,] cellValues = ReadContents(sheet, reader, lastRow, lastColumn);
   return cellValues;
}

private static object[,] ReadFormulas(Excel.Worksheet sheet, int lastRow, int lastColumn)
{
   var reader = new Func<Excel.Range, object>(r => r.Formula);
   object[,] cellFormulas = ReadContents(sheet, reader, lastRow, lastColumn);
   return cellFormulas;
}
``` 

We now have a “generic” `ReadContents` method, which could take any method as an argument. Reading the `Name` of the cells, or the `NumberFormat`, would be trivial, and require only a few extra lines. Furthermore, in the original case, if we discovered an issue in `ReadValue`s, we would also need to fix `ReadFormulas` – now we have only one source of bugs.

## What’s next?

Our add-in is taking good shape, and we are almost done with the core functionality. Next time we’ll update the user interface,to provides the user with some details about the selected difference – and I will close this chapter, post the code, and move on to deployment, an important topic, and not the most fun part of VSTO. I initially intended to add more features first (like merging differences), but I think now it’s probably better to complete an end-to-end project example - and we can get back to adding features later, if popular demand materializes!
