---
layout: default
title: Calendar
---

## Want to meet me in person?

I travel around quite a bit, for conferences and workshops. 
And when I do, I try my best to also present at local user groups or meetups. 
If you are interested in having me speak somewhere near you, 
or perhaps in organizing a course or training session, please contact me!

{% include contact.html %}

## Upcoming events

{% assign events = site.data.foo.events | sort:"date" %}
{% assign now = site.time | date: "%s" %}

<!---
Conferences
-->

### Conferences

{% for event in events %}

  {% assign eventdate = event.date | date: "%s" %}

  {% if eventdate >= now %}
    {% if event.category = "Conference" %}  

[{{ event.date | date: "%b %d" }}{% if event.until <> nil %}-{{ event.until | date: "%d" }}{% endif %}: {{ event.host }}, {{ event.city}} ({{ event.country }})]({{ event.url }})

    {% endif %}
  {% endif %}

{% endfor %}

<!---
Training/Workshop
-->

## Workshops, Classes, Trainings

{% for event in events %}

  {% assign eventdate = event.date | date: "%s" %}

  {% if eventdate >= now %}

    {% for activity in event.activities %}

      {% if event.category = "Training" or activity.type = "Workshop" %}  

[{{ event.date | date: "%b %d" }}{% if event.until <> nil %}-{{ event.until | date: "%d" }}{% endif %}: {{ activity.description }}, {{ event.city}} ({{ event.country }})]({{ activity.registration }})

      {% endif %}

    {% endfor %}

  {% endif %}

{% endfor %}

<!---
Meetups, User Groups
-->

{% include disqus.html %}
