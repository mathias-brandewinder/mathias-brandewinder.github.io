---
layout: post
title: Read Excel VBA macros and functions through C#
tags:
- VBA
- Excel
- Macro
- C#
---

A few days back, I stumbled upon [this page](http://msdn.microsoft.com/en-us/library/dd890502(office.11).aspx), where Frank Rice describes how to use VBA to list all VBA macros and functions a Workbook contains. I thought that was interesting: it’s not the type of VBA code most commonly seen, and the idea of VBA code interacting with VBA code is fun. So I tweeted it, and [Charts GrandMaster Jon Peltier](http://peltiertech.com/WordPress/list-vba-procedures-by-vba-module-and-vb-procedure/), in his own words,&#160; could not “leave anything alone, and made some changes to how the procedure worked”. Nice changes, if I might add.  I am not one to leave anything alone, either, and wanted to check how well that would work using C#. 

*Disclaimer: I have done enough checking to know that the code works in non-twisted cases, but this is far from polished. This would need some handling for exceptions before making it to anything shipped to a client you care about, for instance. My goal was to provide a solid code outline, feel free to modify to fit your needs.*  

The class/method below takes in a fully-qualified file name (i.e. with the full path, just what you would get from an OpenFileDialog), and searches for all the procedures (sub or function) defined in VBA.  As a bonus, I added some extra code to extract the signature of the procedure, and the header comments. The signature - what arguments it takes as input, and what it returns - is a much better summary than simply its name, and I figured that if the author bothered to add comments, it was probably extracting that, too. It also illustrates nicely some of the functionalities of the API.  

<!--more-->

Without further due, here is the code, followed by some comments:  

``` csharp
using System;
using Excel = Microsoft.Office.Interop.Excel;
using VBA = Microsoft.Vbe.Interop;

namespace ClearLines.MacroForensics.Reader
{
   public class OpenWorkbook
   {
      public void Open(string fileName)
      {
         var excel = new Excel.Application();
         var workbook = excel.Workbooks.Open(fileName, false, true, Type.Missing, Type.Missing, Type.Missing, true, Type.Missing, Type.Missing, false, false, Type.Missing, false, true, Type.Missing);

         var project = workbook.VBProject;
         var projectName = project.Name;
         var procedureType = Microsoft.Vbe.Interop.vbext_ProcKind.vbext_pk_Proc;

         foreach (var component in project.VBComponents)
         {
            VBA.VBComponent vbComponent = component as VBA.VBComponent;
            if (vbComponent != null)
            {
               string componentName = vbComponent.Name;
               var componentCode = vbComponent.CodeModule;
               int componentCodeLines = componentCode.CountOfLines;

               int line = 1;
               while (line < componentCodeLines)
               {
                  string procedureName = componentCode.get_ProcOfLine(line, out procedureType);
                  if (procedureName != string.Empty)
                  {
                     int procedureLines = componentCode.get_ProcCountLines(procedureName, procedureType);
                     int procedureStartLine = componentCode.get_ProcStartLine(procedureName, procedureType);
                     int codeStartLine = componentCode.get_ProcBodyLine(procedureName, procedureType);
                     string comments = "[No comments]";
                     if (codeStartLine != procedureStartLine)
                     {
                        comments = componentCode.get_Lines(line, codeStartLine - procedureStartLine);
                     }

                     int signatureLines = 1;
                     while (componentCode.get_Lines(codeStartLine, signatureLines).EndsWith("_"))
                     {
                        signatureLines++;
                     }

                     string signature = componentCode.get_Lines(codeStartLine, signatureLines);
                     signature = signature.Replace("\n", string.Empty);
                     signature = signature.Replace("\r", string.Empty);
                     signature = signature.Replace("_", string.Empty);
                     line += procedureLines - 1;
                  }
                  line++;
               }
            }
         }
         excel.Quit();
      }
   }
}
``` 

A few comments:

* Besides `Microsoft.Office.Interop.Excel`, you need to include a reference to `Microsoft.Vbe.Interop`. You need to “tell” Excel to grant outsiders access Visual Basic Project for this to work. I could not figure out a way to have the code itself check whether access was granted (but I think it’s possible); a try/catch block around the line var project = workbook.VBProject should allow you to isolate that issue.
* The `CodeModule` class is the container for the VBA code, either a module, or the code behind a worksheet or workbook. It behaves as a list of lines of code, and has a few interesting methods accessible.
* `get_ProcOfLine(line, out procedureType)` will return the name of the procedure that “owns” the selected line. procedureType is an enum, `Microsoft.Vbe.Interop.vbext_ProcKind.vbext_pk_Proc`, which filters procedures. Note that this includes any comments above the code itself. `get_ProcStartLine(procedureName, procedureType)` gives you the starting line of a procedure, and `get_ProcBodyLine(procedureName, procedureType)` returns the line where actual code begins. `get_Lines(firstLine, numberOfLines)` will return in one string, including escape characters (new line, etc…), the lines of code you specify, starting at firstLine.
* To extract the signature, I had to take into account that a “unit of code” in VBA can be spread across multiple physical lines of code; in such situations, a “false” line break is marked by the character `_`. To my great relief, I realized that the editor did not allow for whitespace after the `_` character, which simplified work.
* The other piece of information I wish I could extract is global variables and constants. This is a very important piece of information when analyzing code, because it’s a potentially insidious source of side effects.

I had begun to write a small UI around this, but I figured it wasn’t really worth it: if you are interested in that chunk of code, you would most likely use it inside your own project, and not use that UI anyways.

One potential use of this would be to write a procedure or application to automatically inject “standard” modules into a workbook. The API allows not only reading from VBA, but also writing VBA into a Workbook. If you happen to have a bunch of Excel VBA utilities that you typically add to your workbooks, you should be able to write a small application (or add-in) to automate that process.

More modestly, I think I’ll use this API to add a new feature to Akin – wouldn’t it be nice to be able to compare the differences between the contents of two workbooks, and also what changed in their code?
