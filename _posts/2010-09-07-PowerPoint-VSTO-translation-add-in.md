---
layout: post
title: PowerPoint VSTO translation add-in
tags:
- Powerpoint
- Translation
- Google
- Add-In
- Office
- OBA
- VSTO
---

In my previous posts, I explored how to [identify text in a PowerPoint slide]({{ site.url}}/2010/08/21/Exploring-the-PowerPoint-TextRange-object/) and use the [Google .NET API to translate]({{ site.url }}/2010/09/02/Translating-a-PowerPoint-slide-with-Google-translate/) it; let’s put it all together in a simple VSTO add-in for PowerPoint 2007.  

The translation functionality is displayed in a Custom Task Pane, where you can pick the language of origin, and the language to translate to. I used the same general design I presented in my Excel add-in tutorial, using [WPF controls in the task pane]({{ site.url }}/2010/03/02/create-excel-2007-vsto-add-in-wpf-control/) with the [MVVM pattern]({{ site.url }}/2010/03/08/create-excel-2007-vsto-add-in-using-treeview/), leveraging the small yet very useful [MVVM foundation](http://mvvmfoundation.codeplex.com/) framework. When running, this is how the add-in looks like:  

![TranslatorStart]({{ site.url }}/assets/2010-09-07-TranslatorStart_thumb.png)

![TranslatorEnd]({{ site.url }}/assets/2010-09-07-TranslatorEnd_thumb.png)   

I added only 3 languages in there, but it is fairly easy to modify the code and get it to work with any language pair supported by Google translate.  

[Download code sample]({{ site.url }}/downloads/PowerPointTranslationAddIn.zip)
