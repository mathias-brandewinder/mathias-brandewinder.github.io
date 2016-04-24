---
layout: post
title: Try MBrace hassle-free with MBrace Minimal
tags:
- F#
- MBrace
- Azure
---

I have been spending quite a bit of time lately with [MBrace](http://mbrace.io/), a wonderful library that allows you to scale data processing or run heavy work-loads on a cloud cluster, using simple F# scripts. The library is very nicely documented, and comes with a [Starter Kit project](https://github.com/mbraceproject/MBrace.StarterKit) that contains all you need to provision a cluster, together with many scripts illustrating various use cases.

This is great, but... if you just want to play with the library and get a sense for what it does, it might be a bit initimidating. Furthermore, not everyone has an Azure subscription ready, which creates a bit of friction. So I figured, let's try to create the smallest possible project that would allow someone to try out MBrace, without any Azure subscription needed.

<!--more-->

Below is a quick demo (under 2 minutes) of the result, demonstrating how to get setup, start a local cluster and send computations to it. This is definitely not an Oscar-worthy video, but it should give you a sense for what to expect :) 

<iframe width="420" height="315" src="https://www.youtube.com/embed/r_lyh-yBZqo" frameborder="0" allowfullscreen></iframe>

You can find the corresponding project, [mbrace-minimal, here on GitHub](https://github.com/mathias-brandewinder/mbrace-minimal). Basically, I just took the Starter Kit, removed everything I could, keeping only the dependencies required to run MBrace, and relying on [Thespian](http://mbrace.io/thespian-tutorial.html) to run a locally simulated cluster. Download it, go first to the `.paket ` folder and run `paket-bootstrapper.exe` and `paket install` to download the dependencies, and head to the `QuickStart.fsx` script, which starts the local cluster, and illustrates some of MBrace functionality on a couple of very simple examples. 

That's it - I hope you find it useful, and that it motivates you to head to the [Starter Kit project](https://github.com/mbraceproject/MBrace.StarterKit) for more in-depth examples! And if you have suggestions on how to make this better... please let me know :)
