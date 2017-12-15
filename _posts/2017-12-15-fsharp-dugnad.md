---
layout: post
title: Notes from the San Francisco F# Dugnad
tags:
- F#
- Open-Source
- Community
- Dugnad
- Meetup
---

We had our first ever [F# Dugnad at the San Francisco F# meetup](https://www.meetup.com/sfsharp/events/245454941/) last week! The event worked pretty well, and I figured I could share some quick notes on what we did, what worked, and what could be improved.

The origin story for this event is two-fold. First, the question of how to encourage people to start actively contributing to open source projects has been on my mind for a while. My personal experience with open source has been roughly this. I have always wanted to contribute back to projects, especially the ones that help me daily, but many small things get in the way. I clone a project, struggle with a couple small things ("how do I build this thing?"), and after some time, I give up. I also remember being literally terrified sending my first pull request - this is a very public process, with a risk of looking foolish in a very public way.

The second element was me coming across the wonderful Dugnad tradition in Norway.

<!--more-->

A [Dugnad](https://en.wikipedia.org/wiki/Communal_work#Norway) is an event that traditionally takes place twice a year. Everybody from the neighborhood gathers and fixes the communal space together for an afternoon - clean up a park, repaint, fix whatever needs fixing ... - and enjoy drinks and hot-dog afterwards. I loved the idea: besides the obvious improvement to the environment, it creates a sense of common ownership and responsibility, and it's a wonderful way for people from the same community to connect with each other. 

This got me wondering whether transposing the idea to open source software could work. After all, open source *is* our community space, and getting together for a few hours to "fix the neighborhood" seemed like a reasonable idea.

## Setup

The setup was pretty simple. We organized a meetup a Saturday afternoon, 13:00 to 17:00, so we would have enough time to actually get things done. The good people at [@RealtyShares](https://twitter.com/realtyshares) were kind enough to accept to host us, with a comfortable meeting room with tables and power outlets, and even some tacos (writing code takes some fuel!).

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">Open source contributions as a group activity at the F# Dugnad yesterday with <a href="https://twitter.com/dplattsf?ref_src=twsrc%5Etfw">@dplattsf</a> <a href="https://twitter.com/foxyjackfox?ref_src=twsrc%5Etfw">@foxyjackfox</a> <a href="https://twitter.com/sergeyz?ref_src=twsrc%5Etfw">@sergeyz</a> <a href="https://twitter.com/Thuris?ref_src=twsrc%5Etfw">@Thuris</a> <a href="https://twitter.com/yankeefinn?ref_src=twsrc%5Etfw">@yankeefinn</a> &amp; Tracy, was a lot of fun :) Big thanks to <a href="https://twitter.com/realtyshares?ref_src=twsrc%5Etfw">@realtyshares</a> for hosting! <a href="https://twitter.com/hashtag/fsharp?src=hash&amp;ref_src=twsrc%5Etfw">#fsharp</a> <a href="https://t.co/7hIZpA5Hl5">pic.twitter.com/7hIZpA5Hl5</a></p>&mdash; Mathias Brandewinder (@brandewinder) <a href="https://twitter.com/brandewinder/status/939915781315354624?ref_src=twsrc%5Etfw">December 10, 2017</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

We wanted to be able to jump right in, without getting lost trying to figure out what to work on during the Dugnad itself. To do that, we started discussions a couple of weeks early on, over our meetup Slack, asking people to propose projects, or, even better, specific issues they wanted to take on, submitting them in the comments section of the Meetup page.

Starting that discussion early on helped zoom in on realistic tasks to take on. It also resulted in people coming in better prepared, having already cloned projects and done some of the basics beforehand, or even discussed with project maintainers to get some input on what they had in mind, and what might be useful to work on. 

The meeting itself was fairly straightforward. We had 8 attendees, we started with a quick round of introductions - who are you, and if you want to work on something specifically, tell us about it so others can help out. And then... we got to work, some of us individually, some of us in groups. We periodically asked around, to see where everybody was at, and if anyone could help.

And then we went for drinks :)

## Results

My informal hope was that each of us would have one pull request by the end of the day. I can't swear everyone got one in, but I know a few were made. 

I ended up teaming up with [@Thuris](https://twitter.com/Thuris) and [@sergeyz](https://twitter.com/sergeyz), and we worked on [XPlot](https://fslab.org/XPlot/). It's a library I use quite a bit; it allows you to create charts on-the-fly directly from the F# scripting environment, and pop them in the browser.

What we worked on was the documentation, which I suspected was unfriendly to beginners. As a first step, I challenged my 2 team-mates to create a basic histogram as quickly as possible, following the documentation, while I was sadistically watching them struggle and taking notes on the stumbling blocks. I'll put it that way - this was painful to watch.

Based on that experience, we wrote a small tutorial. The goal is to have a fail-safe example, going from zero to seeing an actual chart in the browser, under 5 minutes flat. Our [pull request is nothing earth shattering](https://github.com/fslaborg/XPlot/pull/64), but I hope it will help people coming to the library quickly get a sense for how to use it, and what to expect from it. Also, it was a lot of fun working with that team :)

## Parting thoughts

* Having a Slack channel up was quite helpful to exchange links or code snippets. One suggestion was to create a channel in the fsharp.org Slack.
* Some groups forked the repositories into [our Meetup github organization](https://github.com/sfsharp/), and used that as a shared space to work together. The practical benefits are limited, but symbolically it was a nice way to signal that this was the collective work of a group.
* Having multiple people in the same room ended up being super helpful in unblocking others. In a group of 8, chances are someone knows how to solve the problem you are struggling with.
* Working in teams was very effective in getting newcomers over the stress of the first contribution, and demystifying it.
* The simple fact that each of us had blocked 4 hours dedicated to that particular task helped; It makes it much less likely to just give up and do something else.
* Saturday is a bit of a constraint. On the other hand, it takes time to get up to speed, and getting a group to code for a few hours during a weekday evening seems difficult.
* "When do we do it again" came up immediately after we finished. That session ended up being a great warm-up, and people are now comfortable with the projects and ready to make more "serious" contributions.

Long story short: this was a lot of fun, and we will do it again! The current idea is to have these on a quarterly basis, with possibly smaller ones in between during a weekday evening. I encourage other user groups to try it out, and, perhaps one day, we can organize a worldwide F# Dugnad... In the meanwhile, if you have comments or questions, ping me!
