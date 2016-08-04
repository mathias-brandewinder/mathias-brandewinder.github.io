---
layout: post
title: VSTO Add-In installation woes
tags:
- VSTO
- Add-In
- Office-2003
- Excel
- Deployment
- Dll
- Reference
- Satellite
- TDD
- Code-Reuse
---

**Update, Oct 12, 2009: if you are looking for a way to install a VSTO add-in with multiple dll, I found out there was a [better solution here](http://www.brandewinder.com/2009-10-12-VSTO-add-in-with-multiple-assemblies)**.

I just completed my first real-life VSTO project, and I am officially a convert: I can do everything I did in VBA, using mature languages like C#, and the comfort of the Visual Studio development tools.   Everything has not been smooth, though. I struggled quite a bit initially with deployment, a problem which just does not exist with VBA. However, after some digging, I came across [http://msdn.microsoft.com/en-us/library/bb332052.aspx](this great post), which provides comprehensive step-by-step guidelines on setting up an add-in project for Office 2003.   At that point, I thought my issues were over, and I just cruised along, happily coding in C#. And then I decided that I would extract the logic of my calculation engine in a separate dll, which I would reference in my Excel add-in as a “satellite assembly” – and had a bad surprise. On my development machine, everything worked beautifully, and when I ran the installer on a clean machine, it installed my add-in without any complaint (The satellite dll was even added to the add-in folder), but somehow, the add-in did not run. No error message, no indication of a problem, but where I expected my dll to perform calculations, nothing happened.

<!--more-->

Before getting into how I resolved the problem, a quick word on why I thought this would be a good idea to separate the business logic in its own dll. I had two motivations to do that: reuse, and testability.   There is nothing wrong per se in keeping all your code in the add-in project. However, imagine you build a calculation engine which could be re-used in other projects. If all your code is in the add-in project, you would have to copy/paste the code file into the other project, and to painfully change namespace and references all over the place, to integrate it in the new project. This is very unpleasant – and you will have to do it every time you create a new project. On top of this, if you end up finding a bug in your code (this happens, even to the best of us), you will have to manually change the code in all projects. By contrast, if your business logic is nicely separated in a dll, the only thing you need to do is to reference that dll in any project that uses it, and you are done; and if you find a bug, you need to fix it in one place only, and re-reference the updated dll, and you are done. No code duplication, minimal manual work: much better.   The other issue is testability. I am a unit-test fanatic, and like to build tests as I go, adding tests hand in hand with code, and leveraging the refactoring tools of Visual Studio. I also like to separate the tests from the project itself, so that I don’t have to ship my tests with my product. To do that, I typically add a second project to the solution, which contains only unit tests, and references the main project. The problem here is that because of the technology behind VSTO projects, you cannot reference the VSTO project in your unit test project. You have to do one of two things: referencing the add-in dll, or building the tests in your main project, i.e. shipping them included with your product. And if you reference the dll, you lose all Visual Studio refactoring support, and your whole test-driven development cycle becomes very painful. That’s not good.   So what can you do about it? It took me some time to figure it out, but the solution is actually relatively easy. The post mentioned earlier has a small-print caveat:   

> This article makes the following assumptions about the project that you will deploy:   •&#160;&#160;&#160; There is only one customization assembly; there are no other referenced or satellite assemblies deployed with the solution.

The issue is that in order for your add-in to work with your “satellite assembly”, i.e. your dll, you need to explicitly grant security trust to that dll as well. How do you go about that?   The procedure is fairly simple, and follows the same general lines described to grant security to the add-in assembly. I assume that you already have set your project up so that you have the add-in project, the SetSecurity project, and your add-in deployment project in place.   

![]({{ site.url }}/assets/2008-08-29-addin-project-overview.jpg)

I assume also that you have referenced a dll in your add-in project – in my case, the AddInEngine dll.   

![]({{ site.url }}/assets/2008-08-29-dll-reference.jpg)  

Right-click on the deployment project (in my case, ExcelAddInDemoSetup), and select View > Custom Actions. If you followed the guidelines provided by the post I reference, you should see 4 “folders” Install, Commit, Rollback and Uninstall, each of them containing one item “Primary output from SetSecurity (Active)”.   Right-click “Custom Actions” > Add Custom Action, and select “Application Folder” in the combo box; Click “Add Output”, “SetSecurity” and “Primary Output”. At that point, you should see that each of the 4 folders now contains 2&#160; “Primary output from SetSecurity (Active)”. I recommend that you rename the ones that have just been added to something like “Primary output from SetSecurity for AddInEngine (Active)”, so that you know what's what.   

The procedure now is identical to the one you followed to grant security to the add-in dll itself. The CustomActionData field for the original Custom Action granting security to the add-in dll looked like this:

```
/assemblyName="ExcelAddInDemo.dll" /targetDir="[TARGETDIR]\" /solutionCodeGroupName="MyCompany.ExcelAddInDemo" /solutionCodeGroupDescription="Code group for ExcelAddInDemo" /assemblyCodeGroupName="ExcelAddInDemo" /assemblyCodeGroupDescription="Code group for ExcelAddInDemo" /allUsers=[ALLUSERS]
```  
   
In the Custom action you just added, simply replace “ExcelAddInDemo.dll” by the name of your satellite assembly, so that your CustomActionData field looks something like:   

```
/assemblyName="AddInEngine.dll" /targetDir="[TARGETDIR]\" /solutionCodeGroupName=" MyCompany.AddInEngine" /solutionCodeGroupDescription="Code group for AddInEngine" /assemblyCodeGroupName="AddInEngine" /assemblyCodeGroupDescription="Code group for AddInEngine" /allUsers=[ALLUSERS]
```

Do the same substitution in the Rollback and Uninstall; at that point, you should see something like this, and you are set to go!   

![]({{ site.url }}/assets/2008-08-29-CustomActions.jpg)

If you have multiple dlls referenced, you will have to grant security to each of them individually, which is a bit tedious. Hopefully, I can find a way to automate that process down the road…
