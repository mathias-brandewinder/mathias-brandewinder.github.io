---
layout: post
title: Installing a VSTO add-in on a .NET 2.0 machine
tags:
- VSTO
- Deployment
- Add-In
- Excel
- Install
---

Last Friday, I had a meeting to present a VSTO Excel add-in to a client - and I got an unpleasant surprise: not only did the client not have .NET 3.5 installed on his laptop, but the IT department was not willing to install it, as they had not evaluated it. Rather than trying to convince them that 3.5 was innocuous, I thought, let's try to change the project target from .NET 3.5 to .NET 2.0. After removing all dependencies, I rebuild, do an install on a clean, 2.0-only virtual machine, and... it fails miserably, with the message "This setup requires the .NET Framework 3.5". Not good.

![]({{ site.url }}/assets/2008-10-26-message.png)

When I had nearly given up figuring out what reference I had forgotten (and was bracing myself for a lengthy discussion with IT), [XL-Dennis](http://xldennis.wordpress.com/) came to the rescue with this [post](http://xldennis.wordpress.com/2008/07/31/vs-2008-com-add-ins-and-launch-conditions/), via the [Excel User Group](http://excelusergroup.org/). Thank you a million. It turns out that when you change the Target Framework from 3.5 to 2.0, most things get updated, except... the launch condition that checks the presence of the .NET Framework on the target machine, which stays stuck on 3.5. Once you manually change it to 2.0, everything works fine.
