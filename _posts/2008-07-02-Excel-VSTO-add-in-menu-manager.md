---
layout: post
title: Excel VSTO add-in menu manager
tags:
- Excel
- VSTO
- Add-In
- Sample
- Office
- C#
---

If you have been looking at my [recent bookmarks](http://del.icio.us/mathias.brandewinder), you may have
noticed a pattern: they all revolve around Excel and VSTO. The reason is that I
am starting multiple Excel development projects in the next few weeks. I am
very experienced in VBA and Office development, but after 4 years of writing C# code in Visual Studio, I have been spoiled, and VBA
suddenly feels **very** painful to work with, as if I were traveling back in time to the
middle-ages of development.

Fortunately, there is now an alternative: with VSTO, you can add custom features to
classic Office applications, using .NET languages and the comfort of Visual
Studio 2008. So I thought it was time to give VSTO a shot.

My first project was to establish a simple way to expose the
add-in functionality to the user through menus. I started from [this article](http://msdn.microsoft.com/en-us/library/aa168343.aspx), and
adapted the code to encapsulate the menu-related behavior in one easy-to-use
class, the `MenuManager`.

The sample add-in works
with Office 2003 and 2007, and Windows XP and Vista. It installs an add-in which creates its own menu in Excel, &ldquo;My Add-In&rdquo;, containing two choices, &ldquo;Do This&rdquo; and &ldquo;Do That&rdquo;. When
these are clicked, message boxes pop up, displaying if the user has selected to "Do This" or "Do That",
and the name of the currently active sheet.

![]({{ site.url }}/assets/2008-07-02-AddInScreenShot.JPG)

<!--more-->

The code for the sample illustrates how to achieve this. The
ThisAddIn class contains a member MenuManager. In the add-in start-up section, the
add-in menu and menu items are added through the menu manager. This automatically
creates these elements, and hooks up the menu click events. The add-in shutdown
section unsubscribes the events. That&rsquo;s it.


``` csharp
public partial class ThisAddIn
{
    private MenuManager m_MenuManager;
    private void ThisAddIn_Startup(object sender, System.EventArgs e)
    {
        // VSTO generated code

        m_MenuManager = new MenuManager(this);

        m_MenuManager.CreateAddInMenu("My Add-In");
        m_MenuManager.AddMenuItem("Do This");
        m_MenuManager.AddMenuItem("Do That");
    }
    private void ThisAddIn_Shutdown(object sender, System.EventArgs e)
    {
        m_MenuManager.UnsubscribeAll();
    }
   // VSTO generated code
} 
```

The design of the MenuManager class is pretty straightforward:

``` csharp
using System;
using System.Collections.Generic;
using System.Windows.Forms;
using Office = Microsoft.Office.Core;

namespace ExcelAddIn
{
    internal class MenuManager
    {
        #region Members

        private ThisAddIn m_AddIn;
        private Office.CommandBar m_ExcelMenuBar;
        private Office.CommandBarControl m_AddInMenu;
        private List<Office.CommandBarButton> m_MenuItems;

        #endregion

        #region Constructor

        internal MenuManager(ThisAddIn addIn)
        {
            m_AddIn = addIn;
            m_MenuItems = new List<Microsoft.Office.Core.CommandBarButton>();
            InitializeExcelMenuBar();
        }

        #endregion

        internal void CreateAddInMenu(string menuCaption)
        {
            try
            {
                Office.CommandBarControl menu = m_ExcelMenuBar.Controls.Add(
                    Office.MsoControlType.msoControlPopup,
                    Type.Missing, Type.Missing, Type.Missing, true);
                menu.Caption = menuCaption;
                m_AddInMenu = menu;
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, ex.Source, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        internal void AddMenuItem(string menuItemCaption)
        {
            Office.CommandBarButton menuItem = CreateMenuItem((Office.CommandBarPopup)m_AddInMenu, menuItemCaption);
            m_MenuItems.Add(menuItem);
            SubscribeMenuItemClick(menuItem);
        }

        #region helper methods

        private void InitializeExcelMenuBar()
        {
            try
            {
                m_ExcelMenuBar = m_AddIn.Application.CommandBars["Worksheet Menu Bar"];
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, ex.Source, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private Office.CommandBarButton CreateMenuItem(Office.CommandBarPopup parentMenu, string menuItemCaption)
        {
            Office.CommandBarControl cbc = null;
            try
            {
                cbc = parentMenu.Controls.Add(
                    Office.MsoControlType.msoControlButton, Type.Missing,
                    Type.Missing, Type.Missing, true);
                cbc.Caption = menuItemCaption;
                cbc.Visible = true;

            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message,
                    ex.Source, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            return (Office.CommandBarButton)cbc;
        }
        
        #endregion

        #region handling of events

        private void MenuItem_Click(Office.CommandBarButton menuItem, ref Boolean CancelDefault)
        {
            ExecuteMenuItemAction(menuItem);
        }

        private void ExecuteMenuItemAction(Office.CommandBarButton menuItem)
        {
            string selectedMenu = string.Format("You just selected '{0}' from the menu.", menuItem.Caption);
            string workBookSelected = "No workbook selected";
            if (m_AddIn.Application.Workbooks.Count > 0)
            {
                workBookSelected = String.Format("The name of your workbook is '{0}'.", m_AddIn.Application.ActiveWorkbook.Name);
            }
            string message = selectedMenu + "\n" + workBookSelected;
            MessageBox.Show(message, "Add-In Menu Demo", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private void SubscribeMenuItemClick(Office.CommandBarButton menuItem)
        {
            menuItem.Click += new Microsoft.Office.Core._CommandBarButtonEvents_ClickEventHandler(MenuItem_Click);
        }

        private void UnsubscribeMenuItemClick(Office.CommandBarButton menuItem)
        {
            menuItem.Click -= new Microsoft.Office.Core._CommandBarButtonEvents_ClickEventHandler(MenuItem_Click);
        }

        internal void UnsubscribeAll()
        {
            foreach (Office.CommandBarButton menuItem in m_MenuItems)
            {
                UnsubscribeMenuItemClick(menuItem);
            }
        }

        #endregion
    }
} 
``` 

The design has at least two limits I can see. First, only
one menu can be added so far, and all menu items are added to that menu.
Extending the class to create multiple menus for the add-in would be fairly
trivial, but I also question the need for this: if your add-in needs more than
a few menu items, you should probably create a form with a dedicated menu bar.

The real limit, in my opinion, is in the way the menu click events
are processed in MenuManager.ExecuteMenuItemAction() method. There is no reason
why the MenuManager should be responsible for executing the add-in business
logic: its only role should be to receive notifications from the menu, and
convey that information to another class responsible for taking action. The
current implementation is completely temporary, and intended as a
proof-of-concept; my next step will be to actually design that other class.

This is still work-in-progress, and I would welcome
feedback, comments, or criticism (questions, too); nothing like a review to
improve your code!

[Source code for the Excel add-in sample.]({{ site.url }}/downloads/SampleAddInSetup.zip)

[Setup for the sample Excel add-in]({{ site.url }}/downloads/SampleExcelAddIn.zip)

I apologize for the large and somewhat cumbersome installer; the size is due to the inclusion of Office 2003 and 2007 PIA. Once downloaded, extract the entire folder and run ExcelAddInSetup.msi. You may have to run Setup.exe as well, depending on how your machine is setup.
