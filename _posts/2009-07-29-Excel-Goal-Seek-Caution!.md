---
layout: post
title: Excel Goal Seek&#58; Caution
tags:
- Excel
- Solver
- Goal-Seek
- Optimization
- Algorithms
---

Today I came across a post which demonstrates [how to use Goal Seek](http://chandoo.org/wp/2009/07/29/excel-goal-seek-tutorial/) to determine how to save for your retirement. Goal Seek is essentially a simplified [solver]( {{ site.url }}/2008/12/04/Shortest-path-with-the-Excel-solver/): point Goal Seek at a cell, tell it how much you want it to be and what cells it can tinker with, and Goal Seek will try to find values that reach that goal. The post is an excellent illustration of what’s great about it: it’s super easy to use, and very practical.  

However, there is no such thing as a perfect tool, and Goal Seek can fail miserably at finding the optimal answer to very simple problems. After reading this, I thought it would be a good public service to illustrate what its shortcomings are, especially if you are going to trust it for questions as important as your retirement!  

For our illustration, we will use the following setup.  

![Setup]({{ site.url }}/assets/2009-07-29-Setup_thumb.png)

Now let’s say we want to find a value such that B2 = 250. Following [Pointy Haired Dilbert](http://chandoo.org/wp/), let’s use Goal Seek:  

![GoalSeek]({{ site.url }}/assets/2009-07-29-GoalSeek_thumb.png)

Put in a value of 1 in cell B1, and run Goal Seek - here is what happens:  

![GoalSeekFail]({{ site.url }}/assets/2009-07-29-GoalSeekFail_thumb.png)

Goal Seek fails to find a value in B1 such that B2 = 250. Complete failure.

<!--more-->

Is this because no such value exists? Most definitely not, try 8.846. I was actually too lazy to explicitly solve it, but here is the plot of the function, which shows very clearly that there is a solution to the problem.  

![Curve]({{ site.url }}/assets/2009-07-29-Curve_thumb.png)

So what happened? I deliberately chose the function f(x) = x^3 – 50 * x, because of its shape. The function has what is called a “local maximum”: around –4, the function peaks at around 130. Goal Seek starts at 1 (the value we provided), and looks for what to do. If it increases the input value, the output goes down, and vice-versa, so it keeps reducing the value, and getting closer and closer to 250 - until it hits the local maximum, and can’t do any better.  

![NaiveSearch]({{ site.url }}/assets/2009-07-29-NaiveSearch_thumb.png)

The issue is that Goal Seek follows a greedy algorithm, which is a very naive optimization approach. Wherever it starts, it looks for the best improvement it can find, from that point, which will result in a local optimum, but not necessarily the best solution.  So what is the morale of the story here? The take-away is that you should always take the results of Goal Seek (and the solver) with a grain of salt. Granted, I built this example explicitly to fool it, but it is actually not that rare to have Excel models which can display this kind of behavior. The results depend **a lot** on the initial values you provide, so before trusting the answers of Goal Seeks to do anything of importance, try to give it different starting values, and see if the answers are consistent.
