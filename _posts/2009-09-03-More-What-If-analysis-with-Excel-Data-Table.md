---
layout: post
title: More What-If analysis with Excel Data Table
tags:
- Excel
- Optimization
- Math
- Analysis
- Puzzle
---

In my [last post]({{ site.url }}/2009/08/28/Find-an-optimal-solution-with-Excel-Data-Table/), I illustrated how to quickly to pick the best value from a selection to get the optimal result, by using Excel Data Tables. This time, we will see how to pick the best possible pair of values.  

We are trying to figure out which 2 bridges we should build, in order to minimize the overall travel time for the inhabitants of the island.  

[Island]({{ site.url }}/assets/2009-09-03-Island_thumb.png)

I worked out the math for one bridge last time. We will start we a similar setup, but adjust our spreadsheet so that for each islander, we compute the travelling distance for 2 bridges, and select the shortest route.  

![image]({{ site.url }}/assets/2009-09-03-bridges.png)

The ranges B1 and B2 are named Bridge1 and Bridge2. Column I now contains the formula computing the shortest route for each islander. For row 5 for instance, the formula is   

`=MIN(D5+E5-H5,F5+G5-H5)`  

Cell I10 is the total of the vertical distances travelled by each individual.     

We can select from 4 bridge locations: 2, 4, 7 and 12. What we need is to find out which 2 numbers give us the lowest total travel. Let’s build our data table, this time using 2 bridge positions.   

<!--more-->

Our first bridge can be located at either 2,4,7 and 12:  

![image]({{ site.url }}/assets/2009-09-03-bridge-1.png)

Our second bridge can have the same positions:  

![image]({{ site.url }}/assets/2009-09-03-bridge-2.png)

In the upper-left corner, we specify what value we are interested in. What we want is the total travel distance, so we simply set cell A13 to =I10, the total travel distance:  

![image]({{ site.url }}/assets/2009-09-03-distance.png)

Almost done. Now we select the entire table A13:E17, go to What-If Analysis, and select Data Table. In the pop-up window, we select B2 as the Row input cell, so that the row of values in B13:E13 corresponds to the second bridge location, and B1 as the Column input cell, so that Bridge1 positions will be selected from the values in A14:A17.       
![image]({{ site.url }}/assets/2009-09-03-setup.png)

Once we select OK, the table fills in with the corresponding distances:  

![image]({{ site.url }}/assets/2009-09-03-distances-computed.png)

Looking into the table, we see that the lowest value is achieved for one bridge in position 4, the other one in position 12 – the bridges labeled “One” and “Third”.  

We could even check if we could do any better, by trying out every possible bridge, including the ones which were not proposed. We would build a table like the following:  

![image]({{ site.url }}/assets/2009-09-03-full.png)

I highlighted the original 4 options. Looking into the table, we can see that there is no better solution – but three other solutions are just as good. The 4 optimal solutions are (4, 11), (4, 12), (5,11) and (5,12).  

The data table approach is a bit of an overkill for the specific problem at hand. After all, there are only 4 x 3 x 2 x 1 = 24 options, and it would be feasible to just try them all by hand. However, if you started from scratch and wanted to figure out the best option, that would be 12 x 11 x 10 x 11 possibilities, and checking all 11,880 by hand would turn out to be a serious headache…   

It’s interesting to see how the 2-bridges solution differs from the 1-bridge solution. The best single bridge is bridge “Two”, which is more or less in the middle – an average solution which is great for no one, but a decent compromise. The 2-bridge solution picks more extreme locations, serving better specific sub-groups. In a sense, this is similar to picking up a team. If you have a team of one, you would probably pick someone average, with no glaring weakness. If you can pick two, you’ll probably try to mix it up, and select team mates complementing each other, and compensating each other’s weaknesses.  

One thing I like about data tables is that it is a good option for small discrete choices problems. The solver (or [goal seek]({{ site.url }}/2009/07/29/Excel-Goal-Seek-Caution!/) are well suited to optimize for continuous values, but have issues dealing with problems were the solutions are a set of pre-determined values – and data tables handle these well. On the other hand, data tables won’t go beyond 2 values, which is a clear limitation. What if you had to pick the 3 best bridges?

This question actually got me thinking, so here it is a bonus problem. If you could build as many bridges as you wanted, in any location, where should you build them? To be more specific, what is the minimum number of bridges you should build so that everybody’s travel distance is minimal? I started playing with the question, and couldn’t find a satisfactory answer yet, but if I do, I’ll share. Hints and ideas appreciated!
