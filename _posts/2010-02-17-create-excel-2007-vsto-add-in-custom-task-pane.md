---
layout: post
title: Create an Excel 2007 VSTO add-in&#58; Custom Task Pane
tags:
- Add-In
- Excel
- VSTO
- OBA
- Excel-2007
- C#
- Task-Pane
- User-Interface
---

Now that we have created the [VSTO add-in project]({{ site.url }}/2010/02/12/create-excel-2007-vsto-add-in-getting-started), it’s time to add some functionality to it. We want to provide a user interface to select what sheets we want to compare, and navigate between the differences that the add-in has found. In order to do this, we will create a custom task pane.  

You can think of a custom task pane as a placeholder for controls. The best way to illustrate the concept is to simply do it. In our project, we will add a folder “TaskPane”, and add a new User Control by right-clicking on the TaskPane folder, which we will name “TaskPaneView”.  

![SolutionWithTaskPaneFolder]({{ site.url }}/assets/2010-02-17-SolutionWithTaskPaneFolder_thumb.png)

If you double-click on TaskPaneView, visual studio will display a gray empty area. This is the “canvas” on which we will add controls later, to allow the user to call the operations our add-in will expose. For now, we’ll leave it at that, and just focus on displaying the task pane.  

Now go to the `ThisAddIn` class, and add the following code in the startup method:  

``` csharp
private void ThisAddIn_Startup(object sender, System.EventArgs e)
{
    var taskPaneView = new TaskPaneView();
    var myTaskPane = this.CustomTaskPanes.Add(taskPaneView, "Anakin");
    myTaskPane.Visible = true;
}
``` 

Hit F5 to debug, and you should see the following:

![DockedTaskPane]({{ site.url }}/assets/2010-02-17-DockedTaskPane_thumb.png)

<!--more-->

Docked on the right-hand side of Excel, there is now an area title “Anakin” – that’s our task pane. The beauty of it is that it integrates smoothly with Excel, and gives you lots of flexibility. You can drag it to make it wider or narrower, depending on your real estate. More interestingly, you can move it around, and dock it to the left, top or bottom of the Excel window – or even undock it, and drag it anywhere you please, like this:

![UndockedTaskPane]({{ site.url }}/assets/2010-02-17-UndockedTaskPane_thumb.png)

A quick comment on the code. The AddIn class exposes a `CustomTaskPanesCollection`, which is a collection of the task panes owned by the add-in (Captain Obvious strikes again). `CustomTaskPanesCollection` has an `Add` method, which requires a `UserControl` (the control displayed in the panel), and a title. Calling `Add` creates a new `CustomTaskPane`, and returns it. Like typical collections, the `CustomTaskPanesCollection` also allows removing of contents, by index or by passing it the pane that needs to be removed.

Note that adding a task pane is not sufficient. By default, a task pane is invisible, and needs to be made visible to appear.

Now we will want to access that task pane throughout the life of the add-in, so we need to provide a way to get to it. The most logical owner for the custom task pane is the add-in itself, so we will create a backing field for it, which will hold the reference, and a property to access it:

``` csharp
private CustomTaskPane taskPane;

private CustomTaskPane TaskPane
{
    get
    {
        return this.taskPane;
    }
}

private void ThisAddIn_Startup(object sender, System.EventArgs e)
{
    var taskPaneView = new TaskPaneView();
    this.taskPane = this.CustomTaskPanes.Add(taskPaneView, "Anakin");
    this.taskPane.Visible = true;
}
``` 

Just to illustrate how one could add controls to the task pane, let’s build a quick-and-dirty example. Open the `TaskPaneView` user control again, and drag a button and a label on the surface, like this:

![SimpleControl]({{ site.url }}/assets/2010-02-17-SimpleControl_thumb.png)

Right-click on the button and select Properties, go to the Text property in the Properties window, and change `Text` from `Button1` to Click Me.

![Properties]({{ site.url }}/assets/2010-02-17-Properties_thumb.png)

Similarly, change the label `Text` to an empty string. If you hit F5 right now, you’ll see that the Anakin Custom Task Pane now contains a button, which does nothing when you click it, in spite of requesting you to do so. Go back to the `TaskPaneView`, and double click the button. This will automatically create an event handler for the Button click event in `TaskPaneView.cs`, the code-behind file for the control. Let’s add the following code:

``` csharp
private void button1_Click(object sender, System.EventArgs e)
{
    var time = DateTime.Now.ToLongTimeString();
    this.label1.Text = time;
}
``` 

Now when you click the button, the label will display the time at which it was clicked. Not the most impressive peace of functionality, but hey, it proves the point.

That’s it for today! Next time, we will address a problem. Our Custom Task Pane shows up when we fire Excel, but if you close it, it’s gone, and right now there is no way to make it come back. We’ll use the Ribbon to resolve that issue.

*Questions, comments? Please let me know, I’d love to make this series as useful as possible!*
