---
layout: page
title: Events
---

## Want to meet me in person?

I travel around quite a bit for conferences and workshops. 
When I do, I try my best to also present at local user groups or meetups. 
If you are interested in having me speak somewhere near you, 
or perhaps in organizing a course or training session, please contact me!

## Past presentations

[<i class="fa-brands fa-youtube"></i> Recordings on YouTube](https://www.youtube.com/playlist?list=PLpN8e7gfTS9zlAGvFx4QO1dkIjiZC3OMv)  

## Upcoming events

{% assign events = site.data.events.events | sort:"date" %}
{% assign now = site.time | date: "%s" %}

{% for event in events %}

{% assign eventdate = event.date | date: "%s" %}
{% if eventdate >= now %}

[{{ event.date | date: "%b %d" }}{% if event.until <> nil %}-{{ event.until | date: "%d" }}{% endif %}: {{ event.host }}, {{ event.city}} ({{ event.country }})]({{ event.url }})

{% for activity in event.activities %}
* {{ activity.description }}
{% endfor %}

{% endif %}

{% endfor %}

{% include contact.html %}