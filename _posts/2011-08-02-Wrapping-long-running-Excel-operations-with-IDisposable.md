---
layout: post
title: Wrapping long-running Excel operations with IDisposable
tags:
- IDisposable
- Tips-And-Tricks
- Excel
- C#
- Exceptions
---

When working with Excel, it is common to use small optimization tricks, like setting `Excel.ScreenUpdating` to false to avoid un-necessary screen refreshes, during lengthy operations – something along these lines:  

``` csharp
public void DoJob(Worksheet  worksheet)
{
   var excel = worksheet.Application;

   var initialScreenUpdating = excel.ScreenUpdating;
   var initialCursor = excel.Cursor;

   excel.ScreenUpdating = false;
   excel.Cursor = XlMousePointer.xlWait;

   // do stuff

   excel.ScreenUpdating = initialScreenUpdating;
   excel.Cursor = initialCursor;
}
``` 

This is a good outline of what we would like to happen, but as is, this code has limitations. We would like to be certain that whenever we capture the state, the final two lines, which reset the state to what it was originally, are executed.

<!--more-->

Alas, first, if anything goes wrong in the “do stuff” part, and an exception gets thrown, the resetting code never gets executed, and the cursor will spin until some other part of the code modifies it. This can be addressed by using a try / finally block, but the resulting code isn’t very satisfying.

Then, if this type of code appears in multiple places in your application, rather than copy/paste the code, you’ll probably want to extract two methods, `CaptureInitialState` and `ResetInitialState`. The problem here is that you now need to make sure that any time a Capture is called, the Reset also happens, but as the code gets more complex, you might miss one, especially if a “Captured” method calls another Captured method.

One solution to this issue, which was suggested to me by [Petar](http://petarvucetin.me/blog/) (*disclaimer: I am fully guilty of anything that could be wrong with the following code*), is to create a class implementing the [`IDisposable`](http://msdn.microsoft.com/en-us/library/system.idisposable.aspx) interface, where the state capture is happening in the constructor, and the state resetting takes place in the Dispose method: 

``` csharp
public class StateCapture : IDisposable
{
   private Application Excel { get; set; }
   private bool InitialScreenUpdating { get; set; }
   private XlMousePointer InitialCursor { get; set; }

   public StateCapture(Worksheet worksheet)
   {
      this.Excel = worksheet.Application;

      this.InitialScreenUpdating = Excel.ScreenUpdating;
      this.InitialCursor = Excel.Cursor;

      Excel.ScreenUpdating = false;
      Excel.Cursor = XlMousePointer.xlWait;
   }

   public void Dispose()
   {
      if (this.Excel != null)
      {
         Excel.ScreenUpdating = this.InitialScreenUpdating;
         Excel.Cursor = this.InitialCursor;
      }

      this.Excel = null;
   }
}
``` 

Why would this be a good idea? The beauty is that, per the documentation,

> you can use the using statement (Using in Visual Basic) instead of the try/finally pattern.

We can now rewrite our code the following way:

``` csharp
public void WorksheetJob(Worksheet worksheet)
{
   using (new StateCapture(worksheet))
   {
      // do stuff
   }
}
``` 

Besides being fairly concise, it addresses the two problems mentioned earlier. This behaves as a try/finally block, which means that no matter what exceptions take place in the “do stuff” part, the Dispose method will be called, guaranteeing that the state will be reset. Then, we don’t have to explicitly call the resetting code – if we “opened” a State Capture, we know there will be exactly one State Reset taking place.

Hack? Pattern? I am on the fence. In a [related discussion on StackOverflow](http://stackoverflow.com/questions/452281/using-idisposable-to-unsubscribe-events), Jared Par points, rightly, that “IDisposable is a pattern intended for deterministic release of unmanaged resources”. This usage of IDisposable is arguably a distortion of that idea, serving a different intention. On the other hand, it serves that intention very well, and makes for code which is, in my opinion, much more readable and maintainable.
