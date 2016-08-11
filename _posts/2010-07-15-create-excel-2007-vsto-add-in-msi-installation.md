---
layout: post
title: Create an Excel 2007 VSTO add-in&#58; basic msi setup
tags:
- Excel-2007
- OBA
- Add-In
- VSTO
- Setup
- Install
- Msi
- Deployment
- Prerequisites
- Excel
- C#
---

{% include vsto-series.html %}

Time to wrap this series on VSTO add-ins for Excel 2007. Now that we have a working application-level add-in, we want to deploy it on the user machine. There are two ways to do that: ClickOnce and Windows Installer. In this post, I will go over creating a basic installer using Windows installer with Visual Studio 2008. Very soon, we&rsquo;ll have a VIP guest blogger who will tell you all you need to know about ClickOnce deployment and VSTO.

> This post borrows heavily from the Microsoft white paper linked below, which is absolutely excellent. I mostly paraphrased it, focusing on the how and not the why. **I strongly encourage you to go to the source and read it** for more details:[Deploying a VSTO 3.0 Solution for Office 2007 System Using Windows Installer](http://msdn.microsoft.com/en-us/library/cc563937.aspx). 
> The white paper comes with sample code, covering a few scenarios: [VSTO installer sample code](http://code.msdn.microsoft.com/VSTO3MSI)
 
*Note: the following applies to Office 2007 projects. If your add-in needs to run on Excel 2003, you should follow this guidance instead: [**Deploying VSTO Solutions Using Windows Installer (Part 2 of 2)**](http://msdn.microsoft.com/en-us/library/bb332052.aspx)*

**Surgeon General Warning**: prolonged reading of material pertaining to msi deployment can cause drowsiness or confusion; absolutely no risk whatsoever of euphoria is to be expected.

This post is not going to be sexy. My goal is to have a check-list of what to do to get your add-in to install correctly. The steps require no thinking, and are frankly rather boring. I find some steps pretty obscure, and recommend patience and soothing music; you may consider also having  some sacrificial offering ready to appease the Great Installer Voodoo deity (a [nice chicken](http://www.mypetchicken.com/about-chickens/chicken-pictures/) will usually do). 

## Prepare the add-in

We will start from [where we left off]({{ site.url }}/2010/05/26/excel-2007-vsto-add-in-tutorial-code-sample-2/), with a working add-in ([download the add-in here](http://clear-lines.com/wiki/Anakin.ashx)). Let&rsquo;s first fill in the fields describing our assembly, by right-clicking on the project:

ClearLines.Anakin > Properties > Application > Assembly information:

![AssemblyInfo]({{ site.url }}/assets/2010-07-15-AssemblyInfo_thumb.png)

Next, let&rsquo;s set the configuration to **Release**, so that we feed the optimized release version to the installer. Right-click on the **Solution** (not the add-in project), select **Configuration Manager**, and set ClearLines.Anakin to **Release** instead of Debug.

![ReleaseMode]({{ site.url }}/assets/2010-07-15-ReleaseMode_thumb.png)

<!--more-->

## Add a Setup project

Now we need to add a setup project to the solution. Right-click on the **Solution** again, select Add Project, pick Setup Project in the Other Project Types > Setup and Deployment section, and name it &ldquo;AnakinSetup&rdquo;:

![CreateSetupProject]({{ site.url }}/assets/2010-07-15-CreateSetupProject_thumb.png)

Next we need to tell the setup that we want to deploy the Add-In. First, we build the add-in by right-clicking the project ClearLines.Anakin, and selecting build. Then, we right-click AnakinSetup, and select Add > Project Output, and picking ClearLines.Anakin / Primary Output:

![AddProjectOutput]({{ site.url }}/assets/2010-07-15-AddProjectOutput_thumb.png)

Once this is done, you should see the following: the installer contains the output of the add-in project, as well as all the dependencies it relies on:

![ProjectAndDependencies]({{ site.url }}/assets/2010-07-15-ProjectAndDependencies_thumb.png)

Two other files are required with the deployment, the **VSTO deployment manifest** and **application manifest**. Let&rsquo;s add these files, by right-clicking AnakinSetup > Add > Files, and browsing to ClearLines.Anakin > Bin > Release:

![AddManifestFiles]({{ site.url }}/assets/2010-07-15-AddManifestFiles_thumb.png)

Before we forget, let&rsquo;s also set the Properties of the installer project: click on AnakinSetup, and in the **Properties** window, edit Author and Manufacturer to ClearLines, and ProductName and Title to Anakin.

## Installing the prerequisites on the user machine

At that point, in our setup project, we have the Primary output of our project (the add-in dll), together with the manifest files. If you expand the Detected Dependencies folder, you will see a long list of all the dlls that the add-in requires to run. We need to make sure that these components are present on the user machine before we install the add-in; in order to do that, we will exclude these dependencies from the setup project, and have the installer check whether they are already installed on the user machine, and install them if not.

We need first to exclude these dependencies from the setup. In **AnakinSetup / Detected Dependencies**, select all the dependencies except for Microsoft.Net Framework, right-click, and select **exclude**. At that point, your project should look like this:

![ExcludeDependencies]({{ site.url }}/assets/2010-07-15-ExcludeDependencies_thumb.png)

Next, we need to add these components as Prerequisites to the installer, so that it knows what to look for on the user machine. Right-click **AnakinSetup > Properties**, and click the **Prerequisites** button.

You should see a list like this one appear, with Windows Installer 3.1 and .NET Framework 3.5 already selected.

![InitialPrerequisites]({{ site.url }}/assets/2010-07-15-InitialPrerequisites_thumb.png)

The complete list of prerequisites we need to add is the following:

* Windows Installer 3.1 
* .NET Framework 3.5 
* 2007 Microsoft Office Primary Interop Assemblies 
* Visual Studio Tools for the Office system 3.0 Runtime 

*Usually the 3rd prerequisite, 2007 Microsoft Office Primary Interop Assemblies, is not available by default. Don&rsquo;t panic if that&rsquo;s the case, the next section explains how to handle that situation.*

Keep the top box &ldquo;Create setup program to install prerequisites components&rdquo; selected, and change the install location for prerequisites to the second option, &ldquo;Download prerequisites from the same location as my application&rdquo;.

## What if 2007 Office Primary Interop Assemblies is missing from Prerequisites?

Unfortunately, unless you are lucky, by default, this list should contain only 3 of the 4 required prerequisites, so we will have to take an extra step to make the 2007 Microsoft Office Primary Interop Assemblies (PIA in short) available in the prerequisites list. Note that this needs to be performed only once; after we are done with the next step, the PIA will be available as a prerequisite for other VSTO projects you need to deploy.

The prerequisites that populate the box come from the following location:

**C:\Program Files (x86)\Microsoft SDKs\Windows\v6.0A\Bootstrapper\Packages**

If you open it, you will find a few folders, each corresponding to one of the items in the Prerequisites list. We need to create a similar folder for the Office PIA with the relevant contents, and drop it in that folder, so that it gets detected by Visual Studio, and added to the list.

![BootstrapperPackages]({{ site.url }}/assets/2010-07-15-BootstrapperPackages_thumb.png)

First, download the sample code which accompanies the white paper mentioned earlier, from the link below, and unzip the files; the whole project should be contained in a folder named VSTO_v3_Deployment_Whitepaper_downloads:

[**VSTO installer sample code download**](http://code.msdn.microsoft.com/VSTO3MSI)

For convenience, I&rsquo;ll rename that folder, and the one inside it, Sample.

Then, download the Redistributable Primary Interop Assemblies for the 2007 Microsoft Office System from [here](http://www.microsoft.com/downloads/details.aspx?familyid=59daebaa-bed4-4282-a28c-b864d8bfa513). Running it extracts a file called **o2007pia**  -  copy that file in Sample/Sample/Packages/Office2007PIA:

![Office2007PiaInPackage]({{ site.url }}/assets/2010-07-15-Office2007PiaInPackage_thumb.png)

In the sample project we downloaded, there is a folder named projects/ComponentCheck, which contains a file **ComponentCheck.cpp**. We need to build that C++ file and add the output to the Office2007PIA folder where we just added the o2007pia file. To do this, launch the **Visual Studio 2008 Command Prompt** from the start menu:

![VisualStudioCommandPrompt]({{ site.url }}/assets/2010-07-15-VisualStudioCommandPrompt_thumb.png)

Navigate through the folders (using cd myfolder to navigate in a folder, cd .. to navigate up a level, and dir to display the contents of a folder) until you are located in the folder that contains ComponentCheck.cpp; at that point, your console should look similar to this:

![Console]({{ site.url }}/assets/2010-07-15-Console_thumb.png)

Type in the following instructions after the prompt:

`>cl.exe /Oxs /MT /GS ComponentCheck.cpp advapi32.lib`

![ConsoleAfterBuild]({{ site.url }}/assets/2010-07-15-ConsoleAfterBuild_thumb.png)

This will build **ComponentCheck.exe** in the same folder where ComponentCheck.cpp was located. Close the console, copy that file to **Sample/Sample/Packages/Office2007PIA**, and copy the folder Office2007PIA and its contents (ComponentCheck.exe, o2007pia.msi, product.xml, and the /en folder) to **C:\Program Files (x86)\Microsoft SDKs\Windows\v6.0A\Bootstrapper\Packages**, with the other prerequisites packages.

*Note: when I first tried this step, it failed miserably; it took me a bit to realize that I had installed Visual Studio 2008 with C# and VB.NET only, because I never work with C++, and there was no compiler to do the job&hellip;*

We are now done  -  when you click the Prerequisites button, the Office 2007 primary interop assemblies will show up in our list, and you can go back to the previous section and complete adding the correct 4 prerequisites to the setup project.

## Configuring the registry keys

Right-click AnakinSetup, select **View> Registry**; you should see an editor looking like this:
![InitialRegistry]({{ site.url }}/assets/2010-07-15-InitialRegistry_thumb.png)

In **HKEY_LOCAL_MACHINE > Software**, right-click on the [Manufacturer] key and select delete.

In **HKEY_CURRENT_USER > Software**, right-click on the [Manufacturer] key and select delete.

In **HKEY_CURRENT_USER > Software**, right-click and select Add; rename the item named New Key #1 to Microsoft. Repeat the same process, until you have a chain looking like this: 

HKEY_CURRENT_USER\Software\Microsoft\Office\Excel\Addins\ClearLines.AnakinAddIn

![IntermediateRegistry]({{ site.url }}/assets/2010-07-15-IntermediateRegistry_thumb.png)

The final element of the chain, **ClearLines.AnakinAddIn**, is the key for the add-in. That name should be unique, and a convention like ManufacturingCompany.AddinName is a good approach to avoid collisions.
Note that I named the key for the add-in ClearLines.AnakinAddIn, and not ClearLines.Anakin. I found out the hard way that if the name of the key was the same as the name of the assembly, when running the build, the value for the Manifest (see next paragraphs) was getting corrupted, and mysteriously replaced by ClearLines.Anakin.dll.Manifest - which then prevented the correct installation.

Right-click ClearLines.AnakinAddIn, select **New** > **String Value**, and name the new value **Description.** Right click Description, select **Properties Window,** and set the **Value** to Anakin AddIn.

Similarly, create 3 more entries, to end up with the following list:

**Type ** | **Name** | **Value**
---|---|---
String | Description | Anakin AddIn
String |FriendlyName | Anakin AddIn
DWORD | LoadBehavior | 3
String | Manifest | [TARGETDIR]ClearLines.Anakin.vsto&#124;vstolocal (where **ClearLines.Anakin.vsto** is the VSTO deployment manifest file, one of the 2 files we added to the setup project earlier on)

At that point, you should see something like this:

![FinalRegistry]({{ site.url }}/assets/2010-07-15-FinalRegistry_thumb.png)

Finally, right-click the key ClearLines.AnakinAddIn > Properties Window, and change **DeleteAtUninstall** to **true**, so that the key gets removed if the add-in is uninstalled.

## Adding Installer launch conditions

When we build our installer, we will get two files: a msi file, which installs the add-in itself, and a Setup file, which when executed will check for the prerequisites, install them if need be, and then run the msi to install the add-in. One potential pitfall is that the user could inadvertently run the msi before running the setup, which would install the add-in without the necessary prerequisites, and result in a potentially non-working add-in. In order to avoid that issue, we will add launch conditions to the msi, preventing it to run if the proper prerequisites are not here.

Let&rsquo;s add first a check for the VSTO 3.0 runtime. Right-click AnakinSetup, and select View > Launch Conditions.
Right-click **Requirements on Target Machine**, click **Add Registry Launch Condition.** This will add an entry **Search for RegistryEntry1 search condition;** right-click it and select** Properties Window**. In the properties window, modify the fields to:

(Name) | Search for VSTO 3.0 Runtime
--- | ---
Property | VSTORUNTIME
RegKey | Software\Microsoft\vsto runtime Setup\v9.0.21022
Root | vsdrrHKLM
Value | Install

At that point, you should see something like this:

![InitialLaunchCondition]({{ site.url }}/assets/2010-07-15-InitialLaunchCondition_thumb.png)
  
Right-click the Condition1 entry, select Properties Window, and edit the fields to

(Name) | Verify VSTO 3.0 Runtime availability
--- | ---
Condition | VSTORUNTIME = "#1"
InstallUrl | 
Message | The Visual Studio Tools for Office 3.0 Runtime is not installed. Please run Setup.exe.

Now let&rsquo;s add a check for the Office Excel 2007 PIA. In a similar fashion, right click **Requirements on Target Machine**, and select **Add Windows Installer Launch Condition**. Right-click **Search for Component1** > Properties Windows, and edit the fields to


(Name) | Search for Office Excel 2007 PIA
--- | ---
ComponentId | {1ABEAF09-435F-47D6-9FEB-0AD05D4EF3EA}
Property | HASEXCELPIA

Edit then the corresponding Condition1 in the Property Window to

(Name) | Verify Excel 2007 PIA availability
--- | ---
Condition | HASEXCELPIA
InstallUrl | 
Message | A required component for interacting with Excel 2007 is not available. Please run setup.exe.

Finally, let&rsquo;s add a check for Office 2007 Shared PIAs. Right click **Requirements on Target Machine**, and select **Add Windows Installer Launch Condition**. Right-click **Search for Component1** > Properties Windows, and edit the fields to

(Name) | Search for Office 2007 Shared PIA
--- | ---
ComponentId | {FAB10E66-B22C-4274-8647-7CA1BA5EF30F}
Property | HASSHAREDPIA

Edit then the corresponding Condition1 in the Property Window to

(Name) | Verify Office 2007 Shared PIA availability
--- | ---
Condition | HASSHAREDPIA
InstallUrl | 
Message | A required component for interacting with Excel 2007 is not available. Please run setup.exe.

At that point, you should see something like this:
![FinalLaunchConditions]({{ site.url }}/assets/2010-07-15-FinalLaunchConditions_thumb.png)

These are the 3 checks that will be performed by the msi when run; if one of the 3 components is missing, the installation will fail, and display the corresponding Message we defined in the Launch Condition.

## Set the add-in installation folder

By default, VSTO add-ins for Office 2007 are intended to be installed for a single user. If you need to install for all users, [this post describes how to do it](http://blogs.msdn.com/b/vsto/archive/2010/03/08/deploying-your-vsto-add-ins-to-all-users-saurabh-bhatia.aspx); I&rsquo;ll stay on the path of least resistance, and go for the single-user scenario.

The installation wizard, by default, displays a checkbox asking if the installation is for all users. We should disable that. Right-click **AnakinSetup > View > User Interface**; you should now see a series of nodes, representing the screens of the installation wizard (which you could edit to have a customized installation wizard). For now, select the** Installation Folder** screen, and in the property window, set **InstallAllUsersVisible** to False.

Finally, let&rsquo;s specify that the add-in should be installed in a target folder where the user doesn&rsquo;t require administrative privileges. Right-click **AnakinSetup > View > File System**, right-click the **Application Folder **and in the Properties Window, edit **DefaultLocation** to **[AppDataFolder][Manufacturer]\[ProductName]**. This will install the add-in in the folder C:/User/Mathias/AppData/Roaming/ClearLines/Anakin (note that this folder is hidden by default).

## Build and install the add-in

We are now ready to build and install the add-in! Right-click on AnakinSetup, and Build, which will hopefully end up with **Build Succeeded**. Go to the folder where your solution is located, and in ClearLines.Anaking/AnakingSetup/, you should see a Debug folder, with the following contents:

![DebugFolder]({{ site.url }}/assets/2010-07-15-DebugFolder_thumb.png)

This is your installation package, which you can now distribute to a user. The user should run Setup.exe, which will check for the prerequisites, use the installers in the 4 folders to install missing prerequisites if any, and then run AnakinSetup.msi to install the add-in itself.

I purposefully removed the VSTO redistributable (VSTOR 3.0) from my machine to illustrate what happens when prerequisites are missing. First, let&rsquo;s try to run the msi without using the setup:

![MissingRuntime]({{ site.url }}/assets/2010-07-15-MissingRuntime_thumb.png)

As expected, the installation is blocked. Now let&rsquo;s run the Setup; this time, we get prompted to install the missing prerequisites:

![VstoPrerequisitesInstallation]({{ site.url }}/assets/2010-07-15-VstoPrerequisitesInstallation_thumb.png)
 
Once all the prerequisites are installed, the msi installation wizard begins, and walks us through the steps that we saw earlier in the setup user interface:

![SetupWizard]({{ site.url }}/assets/2010-07-15-SetupWizard_thumb.png)

Once the installation completes, if we navigate to the AddData folder, we can see that a folder has been created for the add-in, which contains the add-in dll and the 2 manifest files:

![InstallationFolder]({{ site.url }}/assets/2010-07-15-InstallationFolder_thumb.png)
 
The first time we fire up Excel, the following message box will show up; the add-in is already installed, but Excel needs to know whether it is safe to execute it:

![TrustingTheAddIn]({{ site.url }}/assets/2010-07-15-TrustingTheAddIn_thumb.png)

Once this last step is completed, our add-in is now present in the Review tab:

![RunningAddIn]({{ site.url }}/assets/2010-07-15-RunningAddIn_thumb.png)
 
We can also check that the add-in is up and running by clicking the upper-left corner of Excel (the Office logo) > Excel Options > Add-Ins:

![InstalledAddIn]({{ site.url }}/assets/2010-07-15-InstalledAddIn_thumb.png)

That's it - we have now created a full Excel 2007 VSTO add-in, with a basic installer which we can redistribute to the users. The code at that stage can be [**downloaded here**](http://clear-lines.com/wiki/Anakin.ashx). Again, I recommend that you check the [**VSTO deployment white paper**](http://msdn.microsoft.com/en-us/library/cc563937.aspx), which is absolutely excellent, and covers more advanced scenarios in part 2 - as well as this [**collection of deployment related links on the VSTO forum**](http://social.msdn.microsoft.com/Forums/en/vsto/thread/1666d2b0-a4d0-41e8-ad86-5eab3542de1e). Please do let me know if you have comments, questions or remarks, and stay tuned for a post explaining how to use ClickOnce instead of Microsoft Installer - with a very special mystery guest!
