---
layout: post
title: VSTO&#58; solution organization
tags:
- VSTO
- Add-In
- Excel
- VSTO-Stocks
- C#
---

*This post is part of a series providing commentary on the [VSTO Stocks](http://vstostocks.codeplex.com/). I initially developed it for the[Excel Developers Conference](http://xlconf.wordpress.com/2011/11/22/uk-excel-developer-conference-london-january-2012/) in London, to illustrate some of the benefits or interesting features of VSTO add-ins compared to traditional VBA automation. The add-in is a work in progress, and is by no means production ready, but it is functional; I will update the code and add comments over time. Feel free to ask questions in the comments!*  

Level: intermediate. Code version: [39134382823e](http://vstostocks.codeplex.com/SourceControl/changeset/changes/39134382823e)

The straightforward way to organize an Add-In solution is to just create a single project of type Excel 2007 Add-In (or whichever Office application / version you may target). So why would I go through the pain of structuring my Solution into four distinct Projects in the VSTO Stocks add-in?  Having a single project is a perfectly valid way to proceed, with things kept simple and tight. However, a drawback of going that route is that it makes it easy to write untestable code, with poor separation of concerns.  

<!--more-->

*Note: in the past, I also ran into testing issues with one single project, because I couldn’t reference the Add-In project itself in my automated tests suite, which was problematic. This problem seems to be gone now.*  

Specifically, one source of such problems is to directly reference either ThisAddIn or Globals classes to access the Excel object model. They behave more or less as static classes would, which is a testing nightmare. For instance, in order to access the Active worksheet in a method, I could write code like this:  

``` csharp
public void DoSomeStuff()
{
   var addIn = Globals.ThisAddIn;
   var excel = addIn.Application;         
   var workbook = excel.ActiveWorkbook;
   var activeSheet = workbook.ActiveSheet;
   // do stuff with the sheet
}
``` 

As is, this method is virtually untestable: we do not control the instantiation of Globals, and cannot replace it with fakes to emulate various situations that could arise in the application. What if, for instance, we wanted to test the behavior of that function when no worksheet is active?

That problem would be avoided altogether if instead of accessing Excel through the Add-In, we injected a reference to Excel in the method:

``` csharp
public void DoSomeStuff(Application excel)
{       
   var workbook = excel.ActiveWorkbook;
   var activeSheet = workbook.ActiveSheet;
   // do stuff with the sheet
}
``` 

Now we are free to substitute Application with our own version, set it up to emulate whatever scenario we see fit, and test what the behavior of the method should be in that case. I’ll revisit that question later when discussing automated tests, and leave it at that for now. For that matter, note also that we could perfectly well re-use that method anywhere, as there is no dependency on the add-in.

By separating into multiple projects, we can enforce that rule. In our Solution, the add-in acts purely as a bootstrapper: its only role is to kick things off when Excel starts, and initialize the UserInterface project, where the core of the application logic resides.

*Note: I may rename the UserInterface project to ExcelApplication later on, the name would be more fitting.* 

The UserInterface project has a reference to Microsoft.Office.Interop.Excel, but not the Add-In, and therefore cannot use Globals or ThisAddin. In the ThisAddIn_Startup method, the running instance of Excel is retrieved and passed to the TaskPaneBuilder in the UserInterface project. From that point on, the Add-In itself doesn’t do anything: the ExcelController in the UserInterface project holds a reference to Excel, and handles all the interactions with Excel going forward.

So what is the Domain project about, then?

This one may or may not be a luxury item, depending on your project. The intent of the Domain project is to represent the business model you are dealing with; it should have no knowledge of Excel (hence the lack of reference to the Excel interop). For instance, StockHistory or MovingAverage are concepts which exist and can be modeled independently of Excel. Our add-in is currently using Excel as a client, but nothing would preclude developing a web-based version later, for instance. In that case, having a separate library which contains the Domain would prove very valuable, because it could be used as-is: the “only” effort required would be to write a different client / user interface to interact with that Domain model.

The name of the fourth project, UnitTests, should give away its purpose: it hosts the automated tests that verify certain behavior of the application. We’ll revisit it later on.

Of course, you don’t have to follow that organization - I also write add-ins which live in one single project! The right organization for your solution depends on each individual project, their complexity, and how they may grow over time. The structure/ideas I describe here are on the heavy side, but have served me well over the years - I hope they will help you think about your projects as well!
