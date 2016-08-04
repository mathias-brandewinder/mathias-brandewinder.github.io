---
layout: post
title: VSTO add-in with multiple assemblies
tags:
- Excel
- Add-In
- VSTO
- Deployment
- Install
- Dll
---

I just found a solution to an issue which has been bothering me for a while. The reference article by Microsoft which describes how to deploy a [Visual Studio 2005 Tools for Office](http://msdn.microsoft.com/en-us/library/aa537179(office.11).aspx) solution using Windows Installer (a life-saver) doesn’t say anything about how to grant trust to multiple assemblies. This is a problem if you want to use satellite dlls in your add-in.  

I figured out a [workaround](http://brandewinder.com/2008/08/29/VSTO-Add-In-installation-woes) a while back, but I wasn’t convinced this was a good solution. Today, I came across [this thread](http://social.msdn.microsoft.com/forums/en-US/vsto/thread/cec6abb6-4716-4bde-91f2-25fb68abd54e/), where the second post (by Lex007) describes a simple way to do that, by modifying the SetSecurity project. Instead of passing only one dll, the tweak allows to pass a comma-separated list of dlls. I just tried it out, and it works like a charm.
