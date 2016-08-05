---
layout: post
title: Adding a sub-menu in an Excel add-in
tags:
- VSTO
- Add-In
- Menu
- Excel
- Office
---

Someone commented to my [post]({{ site.url }}/2008/07/02/Excel-VSTO-add-in-menu-manager/) on add-in menus asking if it was possible to add sub-menus to menus - the answer is yes. The code is essentially the same, with one small difference. When you add a menu item to a menu, you will add a CommandBarControl (the menu item) to the controls of a CommandBarPopup, the menu container. If you want to add a "nested" menu to the menu, instead of adding a CommandBarControl, you will add a CommandBarPopup, which can then receive menu items (or more nested menus!).

In code, it would look something like this:

``` csharp
// Add the sub-menu to parentMenu, which is a CommandBarPopup 

CommandBarPopup parentCommandBarControl = (CommandBarPopup)parentMenu.Controls.Add(
MsoControlType.msoControlPopup, Type.Missing,
Type.Missing, Type.Missing, true);

parentCommandBarControl.Caption = "Sub-Menu";
parentCommandBarControl.Visible = true;

// Add the menu item to the sub-menu 

CommandBarControl commandBarControl = parentCommandBarControl.Controls.Add(
MsoControlType.msoControlButton, Type.Missing,
Type.Missing, Type.Missing, true);

commandBarControl.Caption = menuItemCaption;
commandBarControl.Visible = true;
```
