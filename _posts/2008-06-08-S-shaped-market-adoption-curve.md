---
layout: post
title: S-shaped market adoption curve
tags:
- Excel
- Market-Share
- Market-Adoption
- Market-Introduction
- S-Curve
- Logistic-Curve
- Marketing
- Modeling
- S-Shape
---

One of my clients recently asked me to modify an Excel model, so that the adoption of products entering the market would follow a S-curve. After some digging and googling, I came across [this excellent post by Juan C. Mendez](http://jcandkimmita.info/jc/2007/04/business/modeling-market-adoption-in-excel-with-a-simplified-s-curve/), where he proposes a clean and very practical way to use the [logistic function](http://en.wikipedia.org/wiki/Sigmoid_function), and calibrate it through 3 input parameters: the peak value, and the time at which the curve reaches 10% and 90% of its peak value.

The beauty of his approach is that his function is compact so it can be typed in easily in a worksheet cell, and the input very understandable. However, I found it a bit restrictive: transforming it for values other than 10% and 90% requires some recalibration, and more importantly, it cannot accomodate values that are not "symmetrical" around 50%.

So I set to work through a generalized solution to the following problem: find a S-Curve that fits any arbitrary value, rather than just 10% and 90%.

<!--more-->

## The solution

The formula I ended up with is, not surprisingly, quite a bit longer (and unpleasant) than Mendez's solution: 

```	
=Peak/(1+EXP(-((LN(1/Value1-1)-LN(1/Value2-1))		
/(Time2-Time1))*(Time-(LN(1/Value1-1)		
/((LN(1/Value1-1)-LN(1/Value2-1))		
/(Time2-Time1))+Time1))))
```	

(I broke the formula into 4 pieces to make sure it fit on screen. The formula should be in one piece in a single cell.) 

**Peak** represents the peak market share, i.e. the long-term value of the share of the product (called "Saturation" in Mendez's post). **Value1** and **Time1** represent the percentage of the Peak share that the product has already reached at time 1, and **Value2** and **Time2** the percentage of peak share the product has reached at time 2. **Time**is the time at which the function is to be evaluated.
	
> Illustration: suppose that your product has a long-term market share of 80%, and that it will reach 50% of its peak share (i.e. 50% of 80%, that is, a 40% market share) in April 1st, 2008, and 90% of its peak share (i.e. 90% of 80%, that is, a 72% market share) in July 1st, 2012. In that case, the parameters would be
> Peak: 80%
> Time1: 2008.25
> Value1: 50%
> Time2: 2012.5
> Value2: 90%

The [Excel sheet attached]({{ site.url }}/assets/S-Curve.xls) illustrates the curve in action. Given how lengthy the formula for the curve is, I would recommend to consider first whether the formula proposed by Juan Mendez is sufficient for your needs, and, if you really want to go ahead with mine, to write it as a user-defined function, so that you won't have to keep such a large formula in your cells.

[S-Curve.xls (26.00 kb)]({{ site.url }}/assets/S-Curve.xls)

## The math

The equation for the S-curve is given by:

![]({{ site.url }}/assets/2008-06-08-S-Curve+Simple.JPG)

We need to be able to transform this curve so that we control when the growth happens, and its speed. To that effect, we will transform the original curve by adding two parameters Alpha and T0:

![]({{ site.url }}/assets/2008-06-08-S-Curve+Transformed.JPG)

In essence, T0 shifts the timeline of the curve, and alpha stretches or compresses time. The chart below illustrates the impact of these parameters on the curve. The Blue curve corresponds to the original S-Curve, with Alpha = 1 and T0 = 0. The Red curve has a value of T0 of 2, which "moves" the curve by 2 units to the right: it reaches 50% at t=T0, instead of t=0. The Green curve has a value of Alpha = 2; it still crosses 50% at t=0, but its growth happens "twice as fast" as the original curve. Where the original curve takes (roughtly) 4 periods to grow from 10% to 90%, the Green curve achieves the same growth in just 2 periods. 

![]({{ site.url }}/assets/2008-06-08-Curves+Comparison.JPG)

Our goal is the following: given two values f1 and f2, and two dates t1 and t2, we want to find the two values Alpha and T0 such that f(t1) = f1 and f(t2) = f2. Playing a bit with the equation f(t1) = f1 yields the following:

![]({{ site.url }}/assets/2008-06-08-Log+Transformation.JPG)

Doing the same exercise on f(t2) = f2, we end up with a system of 2 linear equations in two unknowns Alpha and T0:

![]({{ site.url }}/assets/2008-06-08-System+of+equations.JPG)

That system is easily solved and gives us the following values for Alpha and T0:

![]({{ site.url }}/assets/2008-06-08-S-Curve+Solution.JPG)
