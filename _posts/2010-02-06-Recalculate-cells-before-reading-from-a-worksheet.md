---
layout: post
title: Recalculate cells before reading from a worksheet
tags:
- Excel
- Add-In
- VSTO
- Calculation
---

I am currently working on a project which extends an Excel VSTO add-in model I had developed a few months back. This is a joint project, and my add-in has to interact with a classic Excel worksheet model, which got me worried. The original model read data from Excel into a C# object, which handles the heavy-duty computation, and writes back results to a spreadsheet once it is done. The modified model has to proceed in 2 steps: perform a partial read of the inputs, compute some outputs, feed them into the worksheet model, read some results from that worksheet, resume computations and write out the final outputs.  

The reason I was worried is that the spreadsheet I have to interact with is a bit slow, and I was concerned about a [race condition](http://en.wikipedia.org/wiki/Race_condition) type of problem. What if the add-in attempted to read data from the worksheet, before Excel had time to update the values in the worksheet?  

In order to check whether there was a problem, I created a small test case. I first wrote a VBA function which was on purpose very slow:  

``` vb
Public Function SlowFunction(arg As String) As String

    WaitFor 10
    SlowFunction = arg

End Function

Public Function WaitFor(seconds As Integer)

    Dim startTime As Double
    startTime = timer
    
    Do While timer < startTime + seconds
    Loop

End Function
``` 

The `SlowFunction` simply takes a string as input, calls the WaitFor function, which stays busy for a few seconds, and returns the input string after 10 seconds have elapsed.&#160; This allowed me to artificially create an extremely inefficient worksheet: when the input cell A1 is modified, the output cell A2 is updated only 10 seconds later.

![SlowWorkbook]({{ site.url }}/assets/2010-02-06-SlowWorkbook_thumb.png)

<!--more-->

The next step was to create a tiny VSTO project, which changed the value in cell A1, and read the value in cell A2 right after – the question being, what would happen? Would it read the value before it has changed, or wait for the update to occur before reading it? Or would it crash?

``` csharp
public bool Run()
{
   var excel = this.AddIn.Application;
   var workbook = excel.ActiveWorkbook;
   var worksheet = (Worksheet)workbook.ActiveSheet;

   var inputRange = worksheet.get_Range("Input", Type.Missing);
   var initial = inputRange.Value2.ToString();
   var modified = initial + " (Changed)";
   inputRange.Value2 = modified;

   var outputRange = worksheet.get_Range("Output", Type.Missing);
   var read = outputRange.Value2.ToString();
}
``` 

I was honestly not sure what to expect when I ran this, but the result was what I hoped it would be: the `Run()` method reads the updated value. As a result, though, it has to wait for Excel to get its job done, and is held up for 10 seconds.

Now when a workbook becomes heavy and slow, it is quite common to modify its behavior and set `Calculation` to `Manual` instead of `Automatic`. In that case, when the user modifies an input value, cells which depend on that value are not immediately recalculated, and the workbook remains in a “stale” state, until the user requests an recalculation, by hitting the F9 key. So I proceeded to set my clumsy workbook to `Manual Calculation`:

![ManualCalculation]({{ site.url }}/assets/2010-02-06-ManualCalculation_thumb.png)

In this case, running the same code results in reading stale, non-updated values.

To address that issue, one possible solution is to check whether Excel is done with its calculations, and trigger a recalculation if required, by inserting the following code before the read:

``` csharp
inputRange.Value2 = modified;

if (excel.CalculationState != XlCalculationState.xlDone)
{
   worksheet.Calculate();
}

var outputRange = worksheet.get_Range("Output", Type.Missing);
var read = outputRange.Value2.ToString();
``` 

This takes care of the issue: Excel properly recognizes that some cells are “dirty”, and takes 10 seconds to update the worksheet – and the read gives us the appropriate, up-to-date value again.

One thing I am somewhat curious about at that point is what happens if multiple add-ins – or Office Automation executables – hit the same workbook concurrently. When multiple users access concurrently a workbook on a shared drive, some of them only get read-only access; I assume something similar must be happening in that case. This scenario is more complex to replicate, however, so until I have more time on my hands, this will remain a mystery!
