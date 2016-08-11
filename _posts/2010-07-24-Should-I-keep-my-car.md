---
layout: post
title: Should I keep my car?
tags:
- Finance
- Driving
- Cost
- Analysis
- Excel
- Car
- Car-Sharing
---

When I moved to California a few years back, I soon realized that to get anything done in the Silicon Valley, you pretty much have to have a car. So, I purchased my first car. Fast forward today: I live in San Francisco now, and noticed that I am driving less and less. Bicycle is very convenient in my neighborhood, and I don’t have to commute to work on a daily basis. Which got me thinking – do I really need a car? Public transportation only is not an option, because coverage is too spotty, but what about using a car sharing service?  

The 2 major services available in my area are [ZipCar](http://www.zipcar.com) and [CityCarShare](http://www.citycarshare.org/); their pricing system is largely similar: they both:     

* charge by the hour of usage,     
* charge a higher cost over the week-end,     
* offer a discount for full-day rental,     
* have a pay-as-you-go option, and better rates with minimum commitment plans.    

Both include gas, with one difference: ZipCar charges by the hour, whereas CityCarShare has a hybrid pricing, with a lower per-hour cost, and a per-mile cost.   

By contrast, when you own a car, you      

* pay a large upfront investment (buying the car),     
* recoup some of the upfront cost if you resell eventually.     
* pay regular fixed costs (insurance, registration taxes, garage),     
* pay by the mile (gas),     
* pay some additional costs, like maintenance, which are somewhat linked to mileage.   

In addition to that, you bear the risk that your car gets damaged or totaled in an accident.  

<!--more-->

Another financial benefit of car-sharing services is that you get the type of car you need, when you need it – and where you need it. If you need a pick-up truck, to move some heavy equipment, this is included, whereas if you own a car, you would need to rent that truck. If you fly to another city, you would have to rent a car or use a cab, whereas ZipCar covers multiple cities, so you may have a car ready for you there, too.  

So how could we compare the two alternatives, financially?  

The big issue here is that the units are not directly comparable. The cost of car-sharing depends on how much time you would use the car in a month; unless you drive more than 180 miles a day, the distance travelled doesn’t matter. If you have to drive one hour to visit someone, and stay over for two hours, you will be charged for 3 hours, regardless of the distance you travelled.  Conversely, if you own a car, the two biggest cost elements are gas, which is directly related to the distance travelled (and not how much time the trip takes), and the now “invisible” initial cost of your car, and its permanent loss of value.  

In order to compare the two alternatives, one approach is to determine their monthly cost. Let’s begin with the cost of owning a car.  

[Download Excel analysis file]({{ site.url }}/downloads/CarDecision.xlsx)

Let’s first determine a monthly payment that is equivalent to purchasing a car today, and selling it later on. In financial terms, we want to determine an [annuity](http://en.wikipedia.org/wiki/Time_value_of_money#Present_value_of_an_annuity_for_n_payment_periods) (or rather, whatever a monthly annuity is called) that has the same net present value as buying the car today and selling it later. A quick search around the web indicates that a [car depreciates at a rate of 15% a year](http://www.aaa.com/aaa/common/calculators/BuyvsLease.html), in a 10% to 20% range. We can convert that rate to the equivalent monthly rate:   

`MonthlyDepreciationRate = ( 1 + rate ) ^ ( 1 / 12 ) – 1`  

so if we own that car for MonthsOwned months, we expect to resell it for   

`ResellValue = InitialCost / ( ( 1 + MonthlyDepreciationRate ) ^ MonthsOwned )`  

The [present value](http://en.wikipedia.org/wiki/Time_value_of_money) of that sequence – the amount today that is equivalent to the whole transaction - with a monthly interest rate of i, is the initial purchase, minus the discounted resell value: 

`Present Value = – InitialCost + ResellValue / ( ( 1 + i ) ^ MonthsOwned )`  

Using the [classic formula for annuities](http://en.wikipedia.org/wiki/Time_value_of_money#Present_value_of_an_annuity_for_n_payment_periods), we can now convert this cash-flow sequence to a monthly payment, equivalent to the entire sequence of buying now and selling later:  

`MonthlyEquivalent = Present Value x i / ( 1 – ( 1 / (1 + i ) ^ MonthOwned ) )`  

In my case, I ran the numbers, and assuming I would still purchase a cheap, second-hand car for $7,500, and keep it for 6 years, with an interest rate of 7%, the equivalent monthly cost comes down to approximately $90.  

![CarMonthlyCost]({{ site.url }}/assets/2010-07-24-CarMonthlyCost_thumb.png)

The recurring costs are pretty straightforward. The biggest expense here is my parking spot, which costs me a steady $200 / month (that’s what you get for living in the heart of San Francisco), to which I need to add insurance, maintenance and registration fees:  

![RecurringCosts]({{ site.url }}/assets/2010-07-24-RecurringCosts_thumb.png)

Rather than simply add the number of miles I drive every month, I also need to think about how much time I would need for each individual car ride, so that I can compare the car share options with owning a car. Because the rate for a complete day is different, I also need to consider full-day trips. On average, this is how a month looks like for me:  

![MonthlyDriving]({{ site.url }}/assets/2010-07-24-MonthlyDriving_thumb.png)   

I can now compute my average gas cost each month:  

![GasCost]({{ site.url }}/assets/2010-07-24-GasCost_thumb.png)

I can now also compare how much I would spend, using ZipCar or CityCarShare. I rounded up their costs, to include taxes, and the fact that the prices their publish are for the cheapest cars available, which is not necessarily what you will get:  

![CarSharing]({{ site.url }}/assets/2010-07-24-CarSharing_thumb.png)

All in all, the comparison comes down as follows:  **ZipCar: $346 / month**  **CityCarShare: $366 / month**  **Own car: $389 / month**          

[Download Excel analysis file]({{ site.url }}/downloads/CarDecision.xlsx)
 
So what? First, both car-sharing services come out cheaper for me than owning a car. As a result, yesterday, I became a member of ZipCar, and had my first drive with it. I was pretty impressed by the convenience of the service. I haven’t ditched my good old car yet, and will first try it out for a month, to see how it really plays out, but I am pretty motivated to become car-less (car-free?) if I can.  

Second, there are some intangibles in the decision, too. Besides the financial aspect, there is a definite good feeling about doing my part for the environment, and reducing the numbers of cars on the streets; it’s also nice that a significant portion of the fleet are hybrids. Then, I like that the pricing is so transparent: it puts a clear price tag on the act of driving, and elicits the hidden cost of owning a car. As a result, I anticipate that it’s also going to change my behavior, and make me think twice about driving (Why am I not biking to the gym?) The flip-side, obviously, is that I won’t have a car ready for me, whenever I need it. Finally, it also completely eliminates hassles such as maintenance or paperwork – it is somebody’s job to provide me with a fully functional car, the only thing I have to do now is drive.  What do you think? Would you consider abandoning your car and using such a car-sharing service? Or are you lucky enough to live in an area where public transportation is good enough that you don’t even need a car?
