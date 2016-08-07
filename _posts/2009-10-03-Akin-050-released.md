---
layout: post
title: Akin 0.5.0 released
tags:
- Akin
- Performance
- Excel
- User-Interface
---

The current version of Akin, my [free Excel worksheet comparison](http://www.clear-lines.com/akin.aspx) application, has been out for a bit now, and people have sent me some interested suggestions on how to make it better. However, my biggest personal issue so far has been speed. Opening large file hasn’t been an issue, but displaying comparisons of large worksheets (say, 200 x 200 cells) was taking a long time. The typical user for Akin is likely to be working with large files (tracking differences wouldn’t be an issue otherwise), so I had to do something about it.  

I have bitten the bullet – I [changed the design]({{ site.url }}/2009/09/29/Movement-is-relative/), and completely re-wrote the user interface where the comparison is displayed, and I hope that you will be pleased with the performance improvement. Where a 200 x 200 cells comparison took over 20 seconds to display, a 500 x 500 cells comparison is now virtually instantaneous. While I was at it, I did some cosmetic improvements on the looks as well.  

You can [download the new version here](http://clear-lines.com/Akin.aspx). Now that this performance problem is out of the way, I can get back to implementing the features that have been suggested so far. Stay tuned!
