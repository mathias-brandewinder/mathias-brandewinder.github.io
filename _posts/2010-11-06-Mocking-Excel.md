---
layout: post
title: Mocking Excel
tags:
- VSTO
- Unit-Tests
- TDD
- Mocks
---

The question of [how to unit test VSTO projects]({{ site.url }}/2010/04/05/Unit-testing-VSTO-projects/) has been bugging me (terrible pun, I know) for a while. I am a big fan of automated tests, if only because they remind you when new features you added wrecked havoc in existing functionality. But whenever I work on Excel VSTO add-ins, I end up writing very little tests, because, quite frankly, these projects are a massive pain to test. Excel behaves in many respects both like a user interface and a database, two notoriously hard-to-test areas – and on top of that, you cannot directly instantiate and tear down the add-in, because that happens through Office.  

I am still very far from a satisfactory solution, but recently I began organizing my projects differently, and this is showing some potential. I limit as much as possible the role of the add-in project itself, and move the application logic, including interactions with Excel, into a separate project, using the add-in only for "quick-starting” things. The benefit is that unlike the add-in itself, the other project is perfectly suitable for unit testing.  

As an illustration, imagine that your add-in, among other things, kept track of the current worksheet you are in, as well as the previous worksheet that was active. You could implement that along these lines:  

``` csharp
public partial class ThisAddIn
{
   public Worksheet PreviousSheet
   {
      get; set;
   }

   public Worksheet CurrentSheet
   {
      get; set;
   }

   private void ThisAddIn_Startup(object sender, System.EventArgs e)
   {
      var excel = this.Application;
      excel.SheetActivate += SheetActivated;
      excel.SheetDeactivate += SheetDeactivated;
   }

   private void SheetDeactivated(object sheet)
   {
      var worksheet = sheet as Worksheet;
      this.PreviousSheet = worksheet;
   }

   private void SheetActivated(object sheet)
   {
      var worksheet = sheet as Worksheet;
      this.CurrentSheet = worksheet;
   }
``` 

You could easily debug that project and check that it works; however, you won’t be able to write an automated test for that.

<!--more-->

One way around this is to add a class library project to the same solution – let’s say, `AddInApplication`, with a main class called `AddInManager`, like this:

``` csharp
using Microsoft.Office.Interop.Excel;

public class AddInManager
{
   public AddInManager(Application excel)
   {
      excel.SheetActivate += SheetActivated;
      excel.SheetDeactivate += SheetDeactivated;
   }

   public Worksheet PreviousSheet
   {
      get;
      set;
   }

   public Worksheet CurrentSheet
   {
      get;
      set;
   }

   private void SheetDeactivated(object sheet)
   {
      var worksheet = sheet as Worksheet;
      this.PreviousSheet = worksheet;
   }

   private void SheetActivated(object sheet)
   {
      var worksheet = sheet as Worksheet;
      this.CurrentSheet = worksheet;
   }
}
``` 

Instead of performing the work in the add-in itself, we pass an instance of Excel to the Manager, and move all the functionality there. We can now remove most of the code from the add-in, by adding a reference to the AddInApplication project, and passing the hand to the Manager when the add-in starts up:


``` csharp
private void ThisAddIn_Startup(object sender, System.EventArgs e)
{
   var excel = this.Application;
   this.Manager = new AddInManager(excel);
}
``` 

The benefit is that we can now unit test that piece of functionality. The entire Excel interop is exposed through interfaces, which makes it perfectly suitable for Mocking. We can write a test class along these lines:

``` csharp
using Microsoft.Office.Interop.Excel;
using Moq;
using NUnit.Framework;

[TestFixture]
public class TestsAddInApplication
{
   [Test]
   public void WhenSheetIsActivatedItShouldBecomeCurrentSheet()
   {
      var excel = new Mock<Application>();
      var worksheet = new Mock<Worksheet>();
      var application = new AddInManager(excel.Object);
      excel.Raise(xl => xl.SheetActivate += null, worksheet.Object);

      Assert.AreEqual(worksheet.Object, application.CurrentSheet);
   }

   [Test]
   public void WhenSheetIsDeActivatedItShouldBecomePreviousSheet()
   {
      var excel = new Mock<Application>();
      var worksheet = new Mock<Worksheet>();
      var application = new AddInManager(excel.Object);
      excel.Raise(xl => xl.SheetDeactivate += null, worksheet.Object);

      Assert.AreEqual(worksheet.Object, application.PreviousSheet);
   }
}
``` 

In essence, what we are doing here is creating a “fake” version of Excel, which has all the appearances of the real one, via a Mocking framework ([Moq](http://code.google.com/p/moq/) in this case). We pass it to the Manager, fire the event from Fake Excel, and verifying that the AddInManager is reacting properly.

The beauty here is that to do this we didn’t even have to launch Excel – you could even run the tests from a machine where Excel isn’t installed – and yet this is validating exactly what we want, namely that if the Manager is given an instance of Microsoft.Office.Interop.Excel.Application, and SheetActivate or SheetDeactivate is fired, the Manager will do the right thing.

I am pretty excited about this approach, because at least, it is now possible to write automated tests. That being said, it is still not a perfect solution. Mocks work well to listen to Excel events, but they will be of limited help to test what the add-in does to Excel. I am still thinking about how to do that, in a way which is economical, but I can’t quite imagine how to write a simple automated test to verify, say, that the add-in has created a chart with a certain title in a workbook.

The other challenge I ran into was the ribbon. Just like I passed Excel to the project that contains the logic, I managed to move the entire TaskPane logic into the testable dll as well, creating an empty task pane in the add-in, dynamically adding and managing controls from the other project afterwards. However, I had no such luck with the Ribbon, because so far I couldn’t dynamically modify the contents of a Ribbon from outside the add-in itself. I would love to hear any suggestions for that one - maybe with the xml ribbon?.

In any case, I haven’t given up, and will keep trying to get some automated tests into VSTO. Any tips or thoughts on the topic are highly welcome!
