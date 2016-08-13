---
layout: post
title: VSTO&#58; code traceability with Source Control
tags:
- VSTO
- Add-In
- Version-Control
- VSTO-Stocks
---

*This post is part of a series providing commentary on the [VSTO Stocks](http://vstostocks.codeplex.com/) project. I initially developed it for the [Excel Developers Conference](http://xlconf.wordpress.com/2011/11/22/uk-excel-developer-conference-london-january-2012/) in London, to illustrate some of the benefits or interesting features of VSTO add-ins compared to traditional VBA automation. The add-in is a work in progress, and is by no means production ready, but it is functional; I will update the code and add comments over time. Feel free to ask questions in the comments!*  

Level: beginner. Code version: [346c1bd9394e](http://vstostocks.codeplex.com/SourceControl/changeset/changes/346c1bd9394e)

One of the key benefits I find in using VSTO for Office automation instead of VBA is that it enables using [Source Control](http://en.wikipedia.org/wiki/Revision_control) tools.  

During a development effort, regardless of the technology used, lots of things can go wrong. A code change which initially looked like a great idea progressively degenerates into chaos, something goes awry with a file which becomes irrecoverably corrupt, a hard drive suddenly decides it is time to call it quits – all these happen. When they do, it’s nice to have a safety net, and know that somewhere, safe and warm, a snapshot of the code taken in happier times is waiting and can be restored, giving you a safe point to restart from, with only a few hours of work lost.  

What I have often seen done with Excel development goes along these lines: on a regular basis, the developer saves the workbook somewhere “safe” with a time-stamp convention, like “MyWorkbook-2010-12-24.xlsx”.  

On the plus side, this is a very lightweight process, which addresses some of the issues. At the same time, it is cumbersome: the developer needs to be diligent, the process is manual and error-prone (messing up the timestamp, or accidentally over-writing archives is very possible), and recovering the right version from a folder that contains multiple versions only identified by a timestamp is impractical.  

Developers working in other ecosystems have been facing the same issue, and address it with specialized tools: **source control** systems. In a nutshell, the idea of source control is to operate like a library: the source code is stored in a “vault” (known as the **Repository**), developers check out a local copy of the current version on their machine, edit it, and check in/**commit** the modified code back into the vault if they are happy with the result.  

Put differently, whatever code is currently being modified on the developer’s machine is “scratch paper”; it become “real” only once it is committed.  

There are a few obvious benefits. The entire history of the project is saved for posterity, and its state at any point in time can be instantly restored. The system generates timestamps automatically, and each commit has comments attached to it, which helps navigation between versions. This encourages experimenting with code ideas: check out the code, spike something – if it works, great, if not, discard it and revert to the previous repository version.  

![pic of repo on CodePlex]({{ site.url }}/assets/2012-02-06-image_thumb_10.png)

*Overview of the project history with Mercurial + Tortoise on Windows*  

More interestingly, version control systems typically store the difference between the current version and the previous one, and not the file itself. Besides keeping the size of the repository minimal, it also allows to produce “**diffs**”, i.e. code differences: the source control system can easily produce a view that highlights all the differences between two versions of the code, which is invaluable.  

![project history]({{ site.url }}/assets/2012-02-06-image_thumb_11.png)

*The “Diff” highlights what has been added or removed between versions.*

![file change diff]({{ site.url }}/assets/2012-02-06-image_thumb_12.png)
*Diff view of the changes to a specific file on CodePlex*  

## Why hasn’t the traditional Excel developer community embraced source control?  

The main reason, in my opinion, is that Source Control systems are at their best when dealing with text files. While this is the case for most development platforms, Excel is peculiar in that aspect: the code is embedded in the Workbook, in multiple forms (Excel formulas, code-behind worksheets, macro modules…), and the overall project isn’t a collection of text files containing code. Up to version 2003, workbooks were saved as a proprietary binary file, which couldn’t be used to produce meaningful "differences” – and the Open XML format adopted since version 2007 still isn’t very practical for differentiation purposes.  

By contrast, a VSTO add-in like VSTO Stocks consists entirely of .NET code, which is ultimately a collection of text files – there is nothing attached to a specific Workbook. As a result, it is a perfect fit for Source Control, with automatic archival of successive versions, and highly detailed “audit” of changes between versions.  

Note that nothing prevents using Source Control tools for “classic” Excel development – I do it all the time, even when working with Excel 2003 workbooks. You won’t get the full benefits of source control (no diffs), but you will still get a history of all the code changes in the project. Also, if you tend to re-use VBA utilities like UDFs, .bas files are perfect candidates for source control: store the utilities .bas files in a repository, and import them in workbooks when you need them.  

## How to get started with Souce Control?  

A nice thing about Source Control tools is that some of the best and most widely used systems are open source and totally free. The two systems I use are [Subversion](http://subversion.apache.org/) (for the past 7 years or so) and [Mercurial](http://mercurial.selenic.com/) since a few months – they are both great. The other name that comes up a lot is Git, which as far as I know is very similar to Mercurial.   

The main difference is that Subversion has a centralized model (there is a central “source of truth” where the official code resides, and where all changes get committed), whereas Mercurial is a distributed system (developers can work with the full&#160; benefits of version control even disconnected from the “central”, and can merge their work with any other clone of the repository). Both are worth looking into, and offer different advantages. There are plenty of discussions comparing the two approaches, so I won’t go further into it.  

On the other hand, regardless of what system you pick, I recommend installing Tortoise ([TortoiseHg](http://tortoisehg.bitbucket.org/) for Mercurial, [TortoiseSVN](http://tortoisesvn.net/) for Subversion); it’s an extension which integrates source control with Windows, so that you can manage your repositories directly via the graphical user interface. It’s a great way to start without having to struggle with arcane command-line tools.  

![TortoiseHg in action]({{ site.url }}/assets/2012-02-06-image_thumb_13.png)

*Tortoise integrates your Version Control system right into Windows.*
