---
layout: post
title: Write data to an Excel worksheet with C#, fast
tags:
- C#
- Excel
- Performance
- Write
- Interop
---

The current project I am working on requires writing large amount of data to Excel worksheets. In this type of situation, I create an array with all the data I want to write, and set the value of the entire target range at once. I know from experience that this method is much faster than writing cells one by one, but I was curious about how much faster, so I wrote a little test, writing larger and larger chunks of data and measuring the speed of both methods:  

``` csharp
private static void WriteArray(int rows, int columns, Worksheet worksheet)
{
   var data = new object[rows, columns];
   for (var row = 1; row <= rows; row++)
   {
      for (var column = 1; column <= columns; column++)
      {
         data[row - 1, column - 1] = "Test";
      }
   }

   var startCell = (Range)worksheet.Cells[1, 1];
   var endCell = (Range)worksheet.Cells[rows, columns];
   var writeRange = worksheet.Range[startCell, endCell];

   writeRange.Value2 = data;
}
``` 

``` csharp
private static void WriteCellByCell(int rows, int columns, Worksheet worksheet)
{
   for (var row = 1; row <= rows; row++)
   {
      for (var column = 1; column <= columns; column++)
      {
         var cell = (Range)worksheet.Cells[row, column];
         cell.Value2 = "Test";
      }
   }
}
``` 

Clearly, the array approach is the way to go, performing close to 1000 times faster per cell. It also seems to improve as size increases, but that would require a bit more careful testing.

![WriteDataToExcel]({{ site.url }}/assets/2010-10-17-WriteDataToExcel_thumb.png)

<!--more-->

However, one additional thing I needed to do was to format the data, using `NumberFormat` as well as font, borders and color fills, and I thought I would use the same approach – and I observed a significant performance degradation.

``` csharp
private static void WriteNumberFormatArray(int rows, int columns, Worksheet worksheet)
{
   var data = new object[rows, columns];
   for (var row = 1; row <= rows; row++)
   {
      for (var column = 1; column <= columns; column++)
      {
         data[row - 1, column - 1] = "0.000%";
      }
   }

   var startCell = (Range)worksheet.Cells[1, 1];
   var endCell = (Range)worksheet.Cells[rows, columns];
   var writeRange = worksheet.Range[startCell, endCell];

   writeRange.NumberFormat = data;
}
``` 

``` csharp
private static void WriteNumberFormatCellByCell(int rows, int columns, Worksheet worksheet)
{
   for (var row = 1; row <= rows; row++)
   {
      for (var column = 1; column <= columns; column++)
      {
         var cell = (Range)worksheet.Cells[row, column];
         cell.NumberFormat = "0.000%";
      }
   }
}
``` 

Here is the benchmark I ran, comparing writing `NumberFormat` by array vs. cell by cell:

![WriteNumberFormat]({{ site.url }}/assets/2010-10-17-WriteNumberFormat_thumb.png)

The cell-by-cell version performs about the same writing values or number formats; however, the array version works about 100 times worse for `NumberFormat` compared to `Value2`. It still runs way faster than the cell-by-cell approach, but it’s not night-and-day any more.

Fortunately, when you are writing large amount of data like this, chances are, you are really writing records to a worksheet. And while every cell could potentially have a different value, the format is likely consistent, either by row or by column. That is, every cell in a column probably has the same number format. In that case, we have an alternative, which is to apply the format to an entire range at once, like this:

``` csharp
private static void WriteNumberFormatByColumn(int rows, int columns, Worksheet worksheet)
{
   for (var column = 1; column <= columns; column++)
   {
      var startCell = (Range)worksheet.Cells[1, column];
      var endCell = (Range)worksheet.Cells[rows, column];
      var writeRange = worksheet.Range[startCell, endCell];

      writeRange.NumberFormat = "0.000%";
   }
}
``` 

I ran my test again, and observed the following:

![FormatByColumn]({{ site.url }}/assets/2010-10-17-FormatByColumn_thumb.png)

The format by column runs initially as fast as the array-based approach, but its time remains roughly constant as we increase the number of rows, making it an increasingly attractive option as the number of rows increases.

How do you handle writing large amounts of data to Excel? Any Jedi tricks you care to share?

And for completeness, here is the code I used to run my tests; I used an Action delegate in my test loop, which allowed me to easily swap the functions I wanted to compare – feel free to comment and criticize!

``` csharp
namespace ExcelSpeedTest
{
   using System;
   using System.Diagnostics;
   using Microsoft.Office.Interop.Excel;

   class Program
   {
      static void Main(string[] args)
      {
         var excel = new Application();
         excel.DisplayAlerts = false;

         var workbooks = excel.Workbooks;
         var stopwatch = new Stopwatch();
         var blockSize = 10;

         Console.WriteLine("Write by array.");
         MeasureOverIncreasingSize(workbooks, blockSize, stopwatch, WriteNumberFormatArray);

         Console.WriteLine("Write by column.");
         MeasureOverIncreasingSize(workbooks, blockSize, stopwatch, WriteNumberFormatByColumn);

         Console.WriteLine("Write cell by cell.");
         MeasureOverIncreasingSize(workbooks, blockSize, stopwatch, WriteNumberFormatCellByCell);

         Console.ReadLine();
         excel.Quit();
      }

      private static void MeasureOverIncreasingSize(Workbooks workbooks, int blockSize, Stopwatch stopwatch, Action<int, int, Worksheet> method)
      {
         for (int size = 1; size <= 10; size++)
         {
            var workbook = workbooks.Add(Type.Missing);
            var worksheets = workbook.Sheets;
            var worksheet = (Worksheet)worksheets[1];

            var rows = blockSize * size;
            var columns = blockSize;

            stopwatch.Reset();
            stopwatch.Start();

            method(rows, columns, worksheet);

            stopwatch.Stop();

            WriteEvaluation(stopwatch, rows, columns);
            workbook.Close(false, Type.Missing, Type.Missing);
         }
      }

      private static void WriteArray(int rows, int columns, Worksheet worksheet)
      {
         var data = new object[rows, columns];
         for (var row = 1; row <= rows; row++)
         {
            for (var column = 1; column <= columns; column++)
            {
               data[row - 1, column - 1] = "Test";
            }
         }

         var startCell = (Range)worksheet.Cells[1, 1];
         var endCell = (Range)worksheet.Cells[rows, columns];
         var writeRange = worksheet.Range[startCell, endCell];

         writeRange.Value2 = data;
      }

      private static void WriteCellByCell(int rows, int columns, Worksheet worksheet)
      {
         for (var row = 1; row <= rows; row++)
         {
            for (var column = 1; column <= columns; column++)
            {
               var cell = (Range)worksheet.Cells[row, column];
               cell.Value2 = "Test";
            }
         }
      }

      private static void WriteNumberFormatArray(int rows, int columns, Worksheet worksheet)
      {
         var data = new object[rows, columns];
         for (var row = 1; row <= rows; row++)
         {
            for (var column = 1; column <= columns; column++)
            {
               data[row - 1, column - 1] = "0.000%";
            }
         }

         var startCell = (Range)worksheet.Cells[1, 1];
         var endCell = (Range)worksheet.Cells[rows, columns];
         var writeRange = worksheet.Range[startCell, endCell];

         writeRange.NumberFormat = data;
      }

      private static void WriteNumberFormatByColumn(int rows, int columns, Worksheet worksheet)
      {
         for (var column = 1; column <= columns; column++)
         {
            var startCell = (Range)worksheet.Cells[1, column];
            var endCell = (Range)worksheet.Cells[rows, column];
            var writeRange = worksheet.Range[startCell, endCell];

            writeRange.NumberFormat = "0.000%";
         }
      }

      private static void WriteNumberFormatCellByCell(int rows, int columns, Worksheet worksheet)
      {
         for (var row = 1; row <= rows; row++)
         {
            for (var column = 1; column <= columns; column++)
            {
               var cell = (Range)worksheet.Cells[row, column];
               cell.NumberFormat = "0.000%";
            }
         }
      }

      private static void WriteEvaluation(Stopwatch stopwatch, int rows, int columns)
      {
         var cells = rows * columns;
         var time = stopwatch.ElapsedMilliseconds;
         var timePerCell = Math.Round((double)time / (double)cells, 5);

         Console.WriteLine(string.Format("Writing {0} values took {1} ms or {2} ms/cell.", cells, time, timePerCell));
      }
   }
}
``` 
