---
layout: post
title: Data Science in F# 2023&#58; an Ode to Linear Programming
tags:
- F#
- Optimization
- Conference
---

In September, I had the great pleasure of attending the 
[Data Science in F#][1] conference in Berlin. I gave a talk and a workshop on 
[Linear Programming][3], and figured I would make the corresponding material 
available, in case anybody is interested:  

- [Presentation: An Ode to Linear Programming]({{ site.url }}/assets/2023-10-29/ode-to-linear-programming.pdf)
- [Workshop: 4 levels of Linear Programming][2]

<!--more-->

Linear Programming is perhaps an unusual topic for a data science conference. 
It is certainly a departure from my usual focus on Machine Learning with F#! 
I wanted to talk about Linear Programming, and its extension, Mixed Integer 
Linear Programming, because in my view, that technique is criminally 
under-appreciated. In particular, I have seen many projects start with the 
premise that "we need to use Machine Learning (or AI) to solve this", when in 
fact Linear Programming would have offered a better, faster and cheaper 
solution. This talk and workshop are my attempt at re-habilitating LP, and 
hopefully helping you not overlook this old but very powerful technique!  

As a side note, in case you could not make it to the conference, I encourage 
you to check out the [FsLab blog][4], where information about the other talks 
should be published soon!  

[1]: https://datascienceinfsharp.com/
[2]: https://github.com/mathias-brandewinder/4-levels-of-linear-programming
[3]: https://en.wikipedia.org/wiki/Linear_programming
[4]: https://fslab.org/blog/
