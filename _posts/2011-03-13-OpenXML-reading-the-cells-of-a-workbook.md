---
layout: post
title: OpenXML&#58; reading the cells of a workbook
tags:
- OpenXml
- Excel
- Office
---

I had heard good things about [**OpenXML**](http://www.microsoft.com/downloads/en/details.aspx?FamilyId=C6E744E5-36E9-45F5-8D8C-331DF206E0D0&displaylang=en), but until now I didn’t have time to give it a try. After attending a rather intimate session on the topic at the MVP Summit, I realized I should look into it. For those of you like me who haven’t kept up with the news, the general idea is that, since the release of Office 2007, Office files are no longer saved as obscure proprietary files: they are essentially zipped xml files. If you rename an Excel file from MyFile.xlsx to MyFile.zip and open it, you will see that it is simply a collection of xml files, describing the various parts of your Workbook and their relationships. This has a few interesting implications, one of them being that you can create or edit an Excel file without using Excel, or even having Excel installed on your machine.  

The OpenXML SDK is a free library which provides strongly typed .NET classes to manipulate these files without having to deal with raw XML, and are LINQ-friendly, which is awesome.  

One scenario where this comes very handy is if you have some form of a .NET application which needs to read input data from an Excel file; another interesting case is a .NET application which needs to produce some Office outputs for the user. Rather than launch an instance of the Office application and use the COM Interop, you can perform all these tasks safely in .NET, without having to worry about cleanly closing the application.  

In line with the first scenario, my initial goal was to see if I could read the contents of an Excel Workbook with a console app. Rather than going into lengthy explanations, here is the code I ended up with, which borrows heavily from the samples provided with the SDK:  

``` csharp
namespace OpenXmlApp
{
   using System;
   using System.Collections.Generic;
   using System.Linq;
   using DocumentFormat.OpenXml;
   using DocumentFormat.OpenXml.Packaging;
   using DocumentFormat.OpenXml.Spreadsheet;

   public static class Program
   {
      private static void Main(string[] args)
      {
         var filePath = @"C:/Tests/protectedFile.xlsx";
         using (var document = SpreadsheetDocument.Open(filePath, false))
         {
            var workbookPart = document.WorkbookPart;
            var workbook = workbookPart.Workbook;

            var sheets = workbook.Descendants<Sheet>();
            foreach (var sheet in sheets)
            {
               var worksheetPart = (WorksheetPart)workbookPart.GetPartById(sheet.Id);
               var sharedStringPart = workbookPart.SharedStringTablePart;
               var values = sharedStringPart.SharedStringTable.Elements<SharedStringItem>().ToArray();
               
               var cells = worksheetPart.Worksheet.Descendants<Cell>();
               foreach (var cell in cells)
               {
                  Console.WriteLine(cell.CellReference);
                  // The cells contains a string input that is not a formula
                  if (cell.DataType != null && cell.DataType.Value == CellValues.SharedString)
                  {
                     var index = int.Parse(cell.CellValue.Text);
                     var value = values[index].InnerText;
                     Console.WriteLine(value);
                  }
                  else
                  {
                     Console.WriteLine(cell.CellValue.Text);
                  }

                  if (cell.CellFormula != null)
                  {
                     Console.WriteLine(cell.CellFormula.Text);                    
                  }
               }
            }
         }

         Console.ReadLine();
      }
   }
}
``` 

A few comments:

* I am opening the document as read-only, setting the second argument to false.

* `workbook.Descendants<Sheet>()` returns an `IEnumerable<Sheet>`, which means that you can now query it using Linq if you please.

* I am still wrapping my head around the organization of elements. Coming from “classic” Excel, I expect to be able to navigate down directly from a Workbook into its Worksheets; here, the Sheet contained in the Workbook is merely a key which indicates what sheets exist, and what Id to use when requesting them. Navigating between the parts of the file will take a bit of getting used to.

* I love the fact that you can directly iterate over the Cells of a Worksheet. The cells variable above retrieves only cells that have some content, and nothing more. No need to read cells into 2-d arrays and iterating over all of them. 

* On the other hand, I found the organization of the cells content a bit disorienting at first. Interestingly, cells that contain strings that are not formulas do not store the value in the cell element itself. They are stored in a SharedStringTable, and the cell contains an index, in Cell.CellValue.Text, which indicates which element of that table it contains. This seems to be true only for strings that are not formulas, however: if the cell contains a formula, or some non-string type, then the content is stored in CellValue.Text, and there is no record in SharedStringTable. I am sure this will make sense to me some day.

* I am interested to see how easy or painful it is to work with Cells addressed by their index (as in, Cells[3,2] ). This is fairly straightforward using the Interop, but from what I have seen so far, I expect it will be a bit more involved here, because that’s just not how the data is organized.

In short, I found the SDK pleasant to install and use so far (and well documented), and I can definitely see scenarios where I will be using it in the future. On the other hand, I suspect I will end up writing quite a few helper methods to make it more usable – probably trying to make it look closer to the classic Interop. I suspect also that it will turn out to be better suited for applications like Word and PowerPoint, because of the more hierarchical nature of their content.
