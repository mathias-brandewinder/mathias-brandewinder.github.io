---
layout: post
title: When more data won't help
tags:
- F#
- Modeling
- Probability
- Forecasting
---

The following situation happened to me a few days ago. I was working for a client on a model to predict how many customers would cancel their order the next day, using whatever data was available about the order. The model wasn't too bad, but not quite good enough, so naturally I figured I would just get more data. The more data, the better, right?

Well, maybe. The situation brought back memories from way back, from a class in decision analysis, which considered a similar question: given a decision you have to make, what is the value of acquiring more information? 

As it turns out, I ended up doing something different from my initial plan: I told my client that, while the model could be improved with more data, it wasn't worth the effort.

<!--more-->

## Context

First, let's make the situation less abstract. Imagine that you run a regular service, say, a daily bus, where people can pre-order their ticket in advance. You have 100 seats available on that bus each day.

People being people, some customers will change their mind at the last minute, and cancel their order. From a business standpoint, this is a problem. If we are already fully booked, and someone calls to make an order, we'll have to turn them down. As a result, when a cancellation happens, we end up having empty seats, losing money we could have made. 

Being able to predict who might cancel their order would allow us to overbook and avoid that problem. We could take slighly more order than we can handle in theory, and, once cancellation materialize, we would end up with a fully occupied bus.

Obviously, there is an issue here. If we don't correctly predict cancellations, we might end up selling more tickets than we have available. This is taking a risk: customers would rightfully be upset if, when they arrive, you have to turn them down because there are no seats left, and this will do no good to your business reputation in the long term.

In other words, we have a trade-off. By not overbooking, we take the risk of running our service under capacity, and losing a profit we could have made. By overbooking, we take the risk of selling more than we really have, and damaging our reputation, losing business over the long run.

## Running the numbers




[1]: http://brandewinder.com/2017/12/23/baby-steps-with-cntk-and-fsharp/
