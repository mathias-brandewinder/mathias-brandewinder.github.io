---
layout: post
title: Longest Common Subsequence in F#
tags:
- F#
- Diff
- Algorithms
- LCS
- Dynamic-Programming
---

One of my recent posts looked into [reading the VBA code]({{ site.url }}/2009/10/20/Read-the-contents-of-a-worksheet-with-C/) attached to a workbook, and lead to a discussion on analyzing the differences between the macros of two workbooks – what is commonly called a “diff”.  

This got me curious as to how diffs are generated. A quick search lead to the [Longest Common Subsequence](https://en.wikipedia.org/wiki/Longest_common_subsequence_problem) problem: once (one of) the longest common sub-sequence (abbreviated LCS from now on) of characters between two texts has been identified, it is straightforward to determine what has been added and removed from the original text to get the second text.  

> **Example**    
> Original: this is my great code        
> Modified: that is my awesome code
> LCS: th is my&#160; code
> Changes to original: th<strike>is</strike> is my <strike>great</strike> code

The idea behind the algorithm used to identify such a longest common subsequence (LCS) is a nice example of dynamic programming, and goes along these lines. If I have two sequences,  

* if they start with the same character (the head), then their LCS is the head + the LCS of the right-hand remainder of each string (the tail), 
* if they don’t start with the same character, then their LCS could start either with the head of the first sequence, or of the second one. Their LCS is the longest of the LCS of the first sequence and the tail of the second, and of the LCS of the second sequence and the tail of the first one.  

<!--more-->

This sounded like a good problem to try out my new F# “skills” – here is my first take on it:  

``` fsharp
let rec LCS list1 list2 =
  if List.length list1 = 0 || List.length list2 = 0 then
    List.Empty
  else
    let tail1 = List.tail list1
    let tail2 = List.tail list2
    if List.head list1 = List.head list2 then      
      List.head list1 :: LCS tail1 tail2
    else
      let candidate1 = LCS list1 tail2
      let candidate2 = LCS tail1 list2
      if List.length candidate1 > List.length candidate2 then
        candidate1
      else
        candidate2;;
``` 

A few comments. First, it took me under 15 minutes to write this. I am sure this is far from optimal; in particular I suspect that memory usage will be rather awful for larger sequences. Still, I usually struggle with recursions, and this one just flew – and the code is, in my opinion, very understandable, and very close to the human description of the algorithm.

Then, straight off the bat, I got a generic function – and I didn’t even try to. Give it a list of characters, it will work. Feed it a list of integers, it will work, too. OK, I’ll give you that one: feed it a string, and it will fail, because it expects a list, but that should be easy enough to address. (The one thing I need to figure out is how to validate that the two lists are of the same type, but I can live with that for now). I am starting to really dig F# type inference.
