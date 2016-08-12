---
layout: post
title: Friday the 13th FizzBuzz
tags:
- Math
- DateTime
- Fun
---

Today is Friday the 13th, the day when [more accidents happen](http://urbanlegends.about.com/cs/historical/a/friday_the_13th.htm) because Paraskevidekatriaphobics are concerned about accidents. Or is it the day when [less accidents](http://en.wikipedia.org/wiki/Friday_the_13th#Rate_of_accidents) take place, because people stay home to avoid accidents? Not altogether clear, it seems.  

Whether safe or dangerous, how often do these Friday the 13th take place, exactly? Are there years without it, or with more than one? That’s a question which should have a clearer answer. Let’s try to figure out the probability to observe `N` such days in a year picked at random.  

First, note that if you knew what the first day of that year was, you could easily verify if the 13th day for each month was indeed a Friday. Would that be sufficient? Not quite – you would also need to know whether the year was a leap year, these years which happen every 4 years and have an extra day, February the 29th.  

![Ouroboros]({{ site.url }}/assets/2010-08-13-Ouroboros.jpg)

Imagine that this year started a Monday. What would next year start with? If we are in a regular year, 365 days = 52 x 7 + 1; in other words, 52 weeks will elapse, the last day of the year will also be a Monday, and next year will start a Tuesday. If this is a leap year, next year will start on a Wednesday.  

Why do I care? Because now we can show that every 28 years, the same cycle of Friday the 13th will take place again. Every four consecutive years, the start day shifts by 5 positions (3 “regular” years and one leap year), and because 5 and 7 have no common denominator, after 7 4-year periods, we will be back to starting an identical 28-years cycle, where each day of the week will appear 4 times as first day of the year. 

<!--more-->

Now we now that any 28 years cycle is a complete cycle. We just need to pick any year to start with, and enumerate through sheer brute-force over 28 years days that fall on the 13th day of the month, and are a Friday. Let’s do that with a quick-and-dirty C# console app:  

``` csharp
var startYear = 2000;
var cycle = 28;

for (int year = startYear; year < startYear + cycle; year++)
{
    Console.WriteLine(year);
    for (int month = 1; month <= 12; month++)
    {
        var candidate = new DateTime(year, month, 13);
        if (candidate.DayOfWeek == DayOfWeek.Friday)
        {
          Console.WriteLine(candidate.ToShortDateString());
        }
    }
}

Console.ReadLine();
``` 

Running this yields the following result:


  * There is always a Friday the 13th. **ALWAYS**. 
  * There can be as many as 3 occurrences in a single year. 

Here is the full distribution:


**# of Friday the 13th** | **# of Years** | **%**
--- | --- | ---
1 | 12 | 43%
2 | 12 | 43%
3 | 4 | 14%

I must say I was a bit surprised to see so many occurrences; because of the mystique around that date, I expected it to be a bit of a rare event.

In any case, whether you stayed home today or ventured out, I wish you all a safe and lucky Friday the 13th!
