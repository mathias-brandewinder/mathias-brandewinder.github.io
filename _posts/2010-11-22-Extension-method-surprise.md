---
layout: post
title: Extension method surprise
tags:
- Excel
- Extension-Methods
---

One of the reasons I like .NET [extension methods](http://msdn.microsoft.com/en-us/library/bb383977.aspx) is that they provide a nice way to work with existing libraries, and tweak the public API to create custom methods and extend existing objects without modifying them. For instance, I regularly end up creating a few when working with the Office interop. Imagine for instance that you had an Excel project where you wanted to apply a consistent format to some ranges; you could write an extension method like this one:  

``` csharp
public static void ApplyStandardFormat(this Range range)
{
   range.Font.Bold = true;
   range.Font.Color = ColorTranslator.ToOle(System.Drawing.Color.White);

   range.Interior.Pattern = XlPattern.xlPatternSolid;
   range.Interior.Color = ColorTranslator.ToOle(System.Drawing.Color.DarkBlue);
}
``` 

The nice thing here is that because of the addition of the this keyword in the signature “this Range range”, you can now use this method as if it was naturally exposed by the Range object, like this:

``` csharp
myRange.ApplyStandardFormat();
``` 

Arguable, this isn’t the greatest example, and doesn’t necessarily warrant an extension, but you get the idea.

<!--more-->

An interesting aspect of extension methods is that it is perfectly valid to use a method name that already exists on the object, as long as the signature is different. For instance, I could extend the string class with the following `StartsWith()` method:

``` csharp
public static class MyExtensions
{
   public static bool StartsWith(this string myString, string start, int i)
   {
      return false;
   }
}
``` 

It’s a very dumb method, but it helps us prove the point, if we run the following code in a console app:

``` csharp
static void Main(string[] args)
{
   var myString = "Hello";    
   Console.WriteLine(myString.StartsWith("He"));
   Console.WriteLine(myString.StartsWith("He", 1));
   Console.ReadLine();
}
``` 

The first call, using the standard method, will return True, whereas the second one returns False, because it’s calling my absolutely useless extension.

So where am I going with this?

Recently, I needed to write a method to re-set the password protection on a worksheet. I initially had a very specific name (“ProtectRowsAndColumns”), but as I was generalizing the method, I thought I would make it an extension method of Worksheet, and simply call it Protect(), with the following signature:

``` csharp
public static void Protect(
   this Worksheet worksheet,
   IEnumerable<int> protectedRows,
   IEnumerable<int> protectedColumns,         
   bool canInsertOrDeleteRows,
   bool canInsertOrDeleteColumns)
``` 

You may be aware that Worksheet already has a [Protect method](http://msdn.microsoft.com/en-us/library/microsoft.office.tools.excel.worksheet.protect(v=VS.100).aspx), with a fairly lengthy signature, counting no less than 16 arguments, all object (welcome to Office). So I thought that with my measly 4 arguments, all very specific, I was on safe ground. After experiencing an unpleasant sequence of COM exceptions, I realized that my method was never being called, and that instead the arguments were passed to the standard protect method, which, not surprisingly, wasn’t too happy to get an `IEnumerable<int>` to use as a password.

I am still not quite clear as to why this failed so miserably. I expected that because the standard method has all its arguments as object, mine, being more type-specific, would be called, but apparently this isn’t the case (as far as I can tell from other experiments, this is how it normally works). I suspect this has to do with optional arguments, but the honest truth is that I don’t know what went wrong.

So my conclusion for today is that extension methods are awesome, but… be careful, and make sure that what you think is happening is what is actually happening. And if anyone can help me see what I am missing, I would be very grateful!
