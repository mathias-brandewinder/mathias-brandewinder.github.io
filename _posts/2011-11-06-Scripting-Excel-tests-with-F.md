---
layout: post
title: Scripting Excel tests with F#
tags:
- F#
- Excel
- Scripting
- Testing
---

I am somewhat tests-obsessed, and as a result, often find Excel frustrating to work with, because writing automated tests against it isn’t trivial. So recently, while perusing the chapter on Scripting in [Programming F#](http://shop.oreilly.com/product/9780596153656.do), I came across an Office automation example, and started wondering whether this would be a practical way to write automated tests against Excel.  

The use case I have in mind is an existing Excel Workbook, which contains a model (say, your typical Financial model), with a fixed structure, and maybe a sprinkle of VBA, and no .NET.   

For illustration purposes, let’s work with the following: our workbook, Model.xlsx, contains one worksheet, “Finances”, with a Profit cell in B3, computed as the difference between the revenue and cost named cells. Pretty impressive stuff.  

![image]({{ site.url }}/assets/2011-11-06-image_thumb_3.png)

What I want is a way to automatically set the Revenue and Cost to some arbitrary value, and check that the result in Profit is what it should be – so that I don’t have to do it myself by hand, and don’t have to remember how this Workbook was supposed to work later on.  

Here is how this could look like in a F# script – create a Script file, say WorkbookTest.fsx, with the following code inside:  

``` fsharp
#r "Microsoft.Office.Interop.Excel"

open System
open Microsoft.Office.Interop.Excel
      
Console.WriteLine("Press [Enter] to start")
Console.ReadLine()

let excel = new ApplicationClass(Visible=false)
let workbooks = excel.Workbooks

let workbookPath = @"C:\Users\Mathias\Desktop\Model.xlsx"

let workbook = workbooks.Open(workbookPath)
let worksheets = workbook.Worksheets
let sheet = worksheets.["Finances"]
let worksheet = sheet :?> Worksheet

let revenueCell = worksheet.Range "Revenue"
revenueCell.Value2 <- 100

let costCell = worksheet.Range "Cost"
costCell.Value2 <- 10

let profitCell = worksheet.Range "Profit"
let profit = profitCell.Value2

Console.WriteLine("Check profit calculations")
Console.WriteLine("Expected: {0}, Actual {1}", 90, profit)

workbook.Close(false, false, Type.Missing)
excel.Quit()

Console.WriteLine("Done, press [Enter] to close")
Console.ReadLine()
``` 

The script launches Excel in Invisible mode, opens the workbook, sets the Revenue and Cost to 100 and 10, retrieves the value from Profit, printouts the value it found as well as the expected value – and closes back the Workbook without saving any of the changes.

The nice thing here is that I can now drop that file on my desktop, and simply right-click and select “Run with F# Interactive” to execute it, without building anything, and I’ll see something like this happen:

![image]({{ site.url }}/assets/2011-11-06-image_thumb_4.png)

Nothing earth shattering, but still pretty nice: now I got a script which I can run anytime I want, to check whether the Workbook is behaving properly. Furthermore, what’s nice is that I don’t need to open Visual Studio to work with it: I can simply open WorkbookTest.fsx with Notepad, edit my code, and run it again.

There are some clear issues with the code in its current form. For instance, if anything goes wrong in the code (say, for instance, that I mis-typed a name which doesn’t exist with the workbook), the script will crash miserably, and let the hidden Excel instance hang in the background, waiting for someone to kill it manually. This would require some work to make sure that if exceptions are raised, everything is properly disposed, and no matter what, the file gets closed without saving any modification.

In any case, I thought it was worth sharing, even in its rough state – if only because it was fun, and also because the F# code looks surprisingly more appealing than the usual C# Interop code. Now the fun part would be to turn this into a decent testing framework for Excel…
