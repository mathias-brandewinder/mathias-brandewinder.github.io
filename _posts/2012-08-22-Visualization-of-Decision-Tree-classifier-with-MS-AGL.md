---
layout: post
title: Visualization of Decision Tree classifier with MS AGL
tags:
- Machine-Learning
- Visualization
- Classification
- Decision-Tree
- F#
- Github
- MS-AGL
- Microsoft-Research
---

In my recent post on [Decision Tree Classifiers]({{ site.url }}/2012/08/05/Decision-Tree-classification/), I mentioned that I was too lazy to figure out how to visualize the Decision Tree "supporting" the classifier. Well, at times, the Internet can be an awesome place. [**Cesar Mendoza**](https://twitter.com/paks) has forked the [Machine Learning in Action GitHub project](https://github.com/mathias-brandewinder/Machine-Learning-In-Action), and done a very fine job resolving that problem using the [Microsoft Automatic Graph Layout library](http://research.microsoft.com/en-us/projects/msagl/), and running it on the [Lenses Dataset](http://archive.ics.uci.edu/ml/datasets/Lenses) from the [University of California, Irvine Machine Learning dataset repository](http://archive.ics.uci.edu/ml/).

Here is the result of the visualization, you can find [his code here](https://github.com/paks/Machine-Learning-In-Action):
 
![Lenses Dataset Decision Tree]({{ site.url }}/assets/2012-08-22-Decision-Tree.PNG)

Unfortunately, as far as I can tell, the library is not open source, and requires a MSDN license. The amount of great stuff produced at Microsoft Research is amazing, it's just too bad that at times licensing seems to get in the way of getting the word out...
