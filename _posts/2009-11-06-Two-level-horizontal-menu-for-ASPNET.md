---
layout: post
title: Two level horizontal menu for ASP.NET
tags:
- Asp.Net
- Menu
- User-Interface
- Tips-And-Tricks
---

When I decided to have a 2-level horizontal menu for my professional webpage in ASP.NET, it came as a surprise to me that this wasn’t completely straightforward. I expected the standard&#160; ASP menu control to support this, but found out that this wasn’t the case.  

Fortunately, I came across a post by [Peter Kellner](http://peterkellner.net/2009/03/27/codecampwebsiteseries6-cssfriendly-adapters-aspnet-menu/), describing how he implemented that for the [Silicon Valley Code Camp website](http://www.siliconvalley-codecamp.com/Default.aspx), which was pretty much what I envisioned.  

The one issue I had with his implementation, however, was that the second level menu uses multiple data sources. The Master Page handles the top-level menu, but each page contains a reference to the specific datasource used to populate the sub-menu. As a result, if you decide to add a page, you need to manually add to that page some code to define what sub-menu should show up, which is cumbersome.  

The ideal solution for a lazy developer like me would be to have all the menus handled in the Master Page, so that when you add a new page to your website, you just need to add it to the Sitemap, and the right menu and sub-menu shows up.  

<!--more-->

After some tinkering about, I figured out how to get this done. The trick is to use the Attribute StartingNodeOffset of the SiteMapDataSource.  

I used the CSSFriendlyModified.dll Peter presents in his code sample, but modified the MasterPage, which looks like this:  

``` html
<div id="Navigation">
    <asp:SiteMapDataSource ID="SiteMapMain" runat="server" 
    showStartingNode="False"/>
    <div class="MainMenuSection">
        <asp:Menu ID="MainMenu" runat="server" DataSourceID="SiteMapMain"
        MaximumDynamicDisplayLevels="0" Orientation="Horizontal">
        </asp:Menu>
    </div>
               
    <asp:SiteMapDataSource ID="SiteMapSecondLevel" runat="server" 
    showStartingNode="False" 
    StartingNodeOffset="1"/>
    <div class="SecondaryMenuSection">
        <asp:Menu ID="SecondaryMenu" runat="server" 
        DataSourceID="SiteMapSecondLevel" 
        Orientation="Horizontal" />
    </div>
</div>
``` 

The first block (SiteMapMain and MainMenu) declare what DataSource to use for the top-level menu (the SiteMap), and is pretty much identical to Peter’s code.

The second block declares a second DataSource (SiteMapSecondLevel), which hooks up to the SiteMap. Note the difference with the first DataSource: StartingNodeOffset is set to 1, which essentially tells the DataSource to look one level down in the nodes hierarchy of the SiteMap. The sub-menu “SecondaryMenu” simply uses that DataSource, regardless of the page.

As a result, now there is no need to add any code for pages to handle the second level menu. As long as a page is listed in the SiteMap, and hooked to the MasterPage, it will automatically populate the second level menu with the nodes that are listed under the top-level node. You can see that in action on [this page](http://www.clear-lines.com/akin.aspx), for instance. Enjoy!

And, give credit where credit is due - thanks a million for Peter Kellner – his code was a total life-saver.
