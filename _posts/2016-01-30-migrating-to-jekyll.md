---
layout: post
title: Migrating my blog to Jekyll
tags:
- Jekyll
---

January is the month of new year resolutions, and one things I want to do this year is go back to more regular blogging. One obvious reason my cadence fell by the wayside is that, well, [writing a book][1] took time, and sucked some of the fun out of writing. Another, less obvious reason, was that I didn't keep up with updates to [BlogEngine.NET][2], and as a result, the blog itself was getting more and more broken over time. This is not the type of problem I want to spend my time on, so I figured it was time to look for something else. Long story short, I decided to take the plunge and migrate to Jekyll.

<!--more-->

Why Jekyll, and not something else? I quickly discarded WordPress, because I like the idea of markdown-based 'blog aware static site'. No database, less moving parts, just markdown files with a few conventions, the simplicity is appealing. The other big plus is GitHub integration. As GitHub uses Jekyll for GitHub pages, basically, all you have to do is create a repository **[your-name.github.io][3]**, clone and edit an existing Jekyll site there (in my case, [Hyde][4]) - and you are good to go: pages are automatically deployed every time you commit to the repository.

One alternative I considered was [fsBlog][5], which follows the [same philosophy as Jekyll][6], but is using F#. There is some appeal to that: I am obviously more comfortable with F# (and its toolchain) than with Ruby, and fsBlog uses [F# Formatting][7], which produces beautifully formatted code. In the end, I went with Jekyll, not because I think it is fundamentally better, but because of my priorities. One of the reasons I picked BlogEngine.NET about 8 years ago was that I thought it would be fun to tinker with the code itself. As it turns out, I realized since then that I have no interest in dealing with plumbing issues. I suck at web stuff, and I have a ton of other coding projects I want to focus on - I just want to blog, Jekyll is good enough for my needs, and because it is the GitHub standard, I can reasonably expect that things will just work.

So what's next? Besides writing new posts, now I also have 8 years of content to port over. For that I clearly intend to use F#. The general plan at that point is to script an ETL from Hell, pulling the history out of the database with the [SQL Provider][8], and parsing/converting it into markdown, re-writing the 'internal' links and extracting pictures in the process. This promises to be... interesting. And, unless I lose my sanity underway, this will certainly generate some blog-worthy material, so stay tuned!

[1]: http://www.machine-learning-projects-for-dot-net-developers.com/
[2]: http://www.dotnetblogengine.net/
[3]: https://github.com/mathias-brandewinder/mathias-brandewinder.github.io/
[4]: http://hyde.getpoole.com/
[5]: https://github.com/fsprojects/FsBlog
[6]: http://jaskula.fr//blog/2015/01-21-beginners-quick-guide-to-setup-fsblog-and-start-to-blog-in-5-minutes/
[7]: http://tpetricek.github.io/FSharp.Formatting/
[8]: https://github.com/fsprojects/SQLProvider
