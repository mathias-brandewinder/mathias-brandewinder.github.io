---
layout: post
title: Unit testing VSTO projects
tags:
- Excel
- TDD
- Mocks
- Testing
- Unit-Tests
- NUnit
- Rhino.Mocks
- VSTO
---

A few weeks back, Michael asked an interesting question in a comment: how do you go about [unit testing a VSTO project]({{ site.url }}/2008/08/29/VSTO-Add-In-installation-woes/)? One of the reasons I prefer working with VSTO over VBA, is that it makes it possible to write automated tests. What I realized with this question, though, is that I unit test heavily the .Net functionality of my add-ins, but not much (if at all) the interaction with Excel.  

Note: I am aware of the existence of a [VBA unit testing</em></a><em> solution](http://www.blog.methodsinexcel.co.uk/2010/03/30/unit-testing-excel-vba-xlunit-demo/), [xlUnit](http://xlvbadevtools.codeplex.com/); I found the project conceptually pretty cool, but from a practical standpoint, it doesn’t seem nearly as convenient as NUnit or the other established frameworks, which isn’t much of a surprise, given the maturity of unit testing in the .Net world.

The reason for this is double. First, most of my VSTO projects focus on generating heavy computation outside of Excel, and writing results to Excel; as a result, the meat of the logic has little to do with Excel, and there isn’t all that much to test there.  

Then, testing against VSTO is a bit of a pain. By definition, a VSTO project comes attached with a giant external dependency to Excel, which we have limited control over, and which is also rather unpleasant to deal with from .Net. To illustrate one aspect of the issue, let’s consider this code snippet:  

``` csharp
[TestFixture]
public class TestsThisAddIn
{
   [Test]
   public void WeCannotInstantiateTheAddInProperly()
   {
      var addIn = new ThisAddIn();
      var excel = addIn.Application;
      Assert.IsNotNull(excel);
   }
}
``` 

This test will fail: if we instantiate the add-in directly, it does not automatically hook up to Excel. The VSTO add-in is started up by Excel itself, and we cannot replicate that simply in our test code, and access the Excel object to verify that things behave as expected. 

So how could we approach the problem? Unit testing our code means that we want to validate that pieces under our control (classes we wrote) work properly; the challenge is that some of them interact with Excel. We are not concerned with testing the system in its entirety (add-in code + Excel) here, which is an important issue, but not a unit-testing one.

The words “unit test” and “external dependency” together suggest one technique – Mocking. In a nutshell, Mocking consists of replacing the external dependency with a fake, an object which behaves the same way as the “real thing”, but is easier to work with.

There are three ways our classes can interact with Excel that I can think of:

* react to Excel events 
* read/query from Excel
* write/command to Excel

<!--more-->

Let’s consider the first case, through a contrived/simplified example. Suppose that our add-in keeps track of the names of workbooks the user recently interacted with, through the following class:

``` csharp
using System.Collections.Generic;
using Excel = Microsoft.Office.Interop.Excel;

public class RecentWorkbooks
{
   private List<string> recentWorkbooks;

   public RecentWorkbooks(Excel.AppEvents_Event excelEvent)
   {
      this.recentWorkbooks=new List<string>();
      excelEvent.NewWorkbook += NewWorkbook;
      excelEvent.WorkbookOpen += NewWorkbook;
   }

   public List<string> RecentWorkbookNames
   {
      get
      {
         return new List<string>(this.recentWorkbooks);
      }
   }

   private void NewWorkbook(Excel.Workbook workbook)
   {
      this.recentWorkbooks.Add(workbook.Name);
   }
}
``` 

The class maintains a list of strings, the workbook names. In the constructor, it subscribes to the `NewWorkbook` and `WorkbookOpen` Excel events, which are directed to the `NewWorkbook` method, where the name of the workbook newly created or just opened is appended to the list.

The class is plugged in the add-in through the `ThisAddIn_Startup` method:

``` csharp
public partial class ThisAddIn
{
  public RecentWorkbooks RecentWorkbooks
  {
     get;
     set;
  }

  private void ThisAddIn_Startup(object sender, System.EventArgs e)
  {
     var recentWorkbooks = new RecentWorkbooks(this.Application);
     this.RecentWorkbooks = recentWorkbooks;
  }
}
``` 

How can we unit test this? There isn’t much to test on the `ThisAddIn` itself; the part which we would like to test is that when Excel fires `NewWorkbook` or `WorkbookOpen`, the name of the new workbook gets appended to the `RecentWorkbooks` list.

Opening an instance of Excel programmatically and passing it to the `RecentWorkbooks` class would be a total nightmare. Fortunately, the Excel object model as seen through the Office.Interop / VSTO consists almost entirely of Interfaces: as a result, we can substitute the “real” `Excel.AppEvents_Event` in the `RecentWorkbooks` constructor with anything that implements that interface, and the class should accept the impostor just fine.

![wtf-pics-imposter-cow]({{ site.url }}/assets/2010-04-05-wtf-pics-imposter-cow_thumb.jpg)

*Source: [Picture Is Unrelated](http://pictureisunrelated.com)*

Rather than roll an implementation of the Mocks manually, I leveraged [Rhino.Mocks](http://www.ayende.com/projects/rhino-mocks/downloads.aspx) to generate our fakes. The test I ended up writing is below:

``` csharp
[Test]
public void WhenWorkbookIsOpenedItsNameShouldBeAppendedToNameList()
{
   var excel = MockRepository.GenerateStub<Excel.Application>();
   var recentWorkbooks = new RecentWorkbooks(excel);

   var workbook = MockRepository.GenerateStub<Excel.Workbook>();
   var name = "Shazam!";
   workbook.Stub(w => w.Name).Return(name);
   var args = new object[1];
   args[0] = workbook;

   excel.Raise(e => e.WorkbookOpen += null, args);

   var lastWorkbookName = recentWorkbooks.RecentWorkbookNames.Last();
   Assert.AreEqual(name, lastWorkbookName);
}
``` 

In plain English, this translates into “give me something that looks like Excel, and hook it up to the `RecentWorkbooks` class; then have the fake Excel fire `WorkbookOpen`, and pass a fake Workbook named “Shazam!” as the event argument. The last name in the list should be “Shazam!”.

This approach allows us to test virtually any interaction with the Excel model, for all 3 kinds of scenarios mentioned above. In particular, this is a very convenient way to simulate error/exception scenarios, which can be fairly complicated to generate using the “real thing”.

The only requirement is that the classes make the dependency to Excel explicit, injected through the constructor or properties, so that they can be mocked - which practically means 

* avoiding using the Globals class and the access it provides to the AddIn through the static property ThisAddIn,
* using the ThisAddIn class as a bootstrapper, to initialize classes that contain the add-in logic and wire them to the Excel instance and the events.

Is this a good use of development time? As much as I like unit tests and TDD, I am on the fence. I can see the value in checking that our code handles events properly. On the other hand, the reads or writes to Excel are usually very simple calls, but in C# they have very intricate signatures, and mocking these calls seems tedious with limited added value, except maybe to simulate failure scenarios - for instance, if I can’t find the expected worksheet, does my class handle the situation gracefully, and perhaps log an error?

I guess I could be convinced, if I knew how to address the following issue. VSTO projects behave differently from typical class libraries. With a class library, you create your library project, another library with your tests, and you add a reference to the library under test project – and you are done. Whenever you rebuild, the unit tests library picks up the most recent version of the dll, and the code/build/test workflow just runs smoothly. For some reason, I could not get this to work with VSTO: the best approach I found was to directly point to the add-in dll in the bin folder, because the VSTO project doesn’t show up in the available projects to reference, and as a result, I have ran into glitches where the test project didn’t automatically refresh after a rebuild, or other similar problems, which is very annoying, and stressful. When I run my tests, I like to know that they fail or succeed because of my code; with this setup, I also have to worry about whether the results I observe are due to my current code, or to something not being properly refreshed.

Finally, unit tests are only one aspect of testing; essentially, the test I presented operates on the following premise: “if Excel behaves the way I believe it does, then my class is working properly”. In no way does it guarantee that when everything is wired together, Excel and the Add-In will work happily together – and I don’t know how to approach this, for the reason I mentioned earlier: the add-in is started by Excel, and I am not clear how to go about replicating this in an automated test.

If you work on VSTO projects, and have had some success with automated testing, I would love to hear how you approached it!
