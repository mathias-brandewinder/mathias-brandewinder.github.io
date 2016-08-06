---
layout: post
title: Illustrative Programming
tags:
- Excel
- Languages
- Modelling
- Design
---

Very interesting piece by Martin Fowler; he discusses spreadsheets as a programming language, and coins the term “[Illustrative Programming](http://martinfowler.com/bliki/IllustrativeProgramming.html)” to describe the corresponding development style. I quote liberally here:  

> One property of spreadsheets, that I think is important, is its ability to fuse the execution of the program together with its definition. When you look at a spreadsheet, the formulae of the spreadsheet are not immediately apparent, instead what you see is the calculated numbers - an illustration of what the program does.    Using examples as a first class element of a programming environment crops up in other places - UI designers also have this. Providing a concrete illustration of the program output helps people understand what the program definition does, so they can more easily reason about behavior.
   
> I don't think that illustrative programming is all goodness. One problem I've seen with spreadsheets and with GUI designers is that they do a good job of revealing what a program does, but de-emphasizes program structure. As a result complicated spreadsheets and UI panels are often difficult to understand and modify. They are often riven with uncontrolled copy-and-paste programming.    This strikes me as a consequence of the fact that the program is de-emphasized in favor of the illustrations. As a result the programmers don't think to take care of it. We suffer enough from a lack of care of programs even in regular programming, so it's hardly shocking that this occurs with illustrative programs written by lay programmers. But this problem leads us to create programs that quickly become unmaintainable as they grow.

This piece is worth reading, if only to see such a highly respected developer as Fowler defend Excel as a programming language. Given how Excel is usually dissed by “serious programmers”, it’s refreshing.  

His analysis rings true, too – spreadsheets and UI tools are very similar in their benefits (immediate focus on the end result desired by the user) and drawbacks (possible lack of structure, lack of testability…). I am not sure how to describe the “other” style, maybe “Axiomatic Programming” - first establish the principles, then useful consequences can be derived? In a way, the term “Illustrative Programming” marks one extreme on the scale of development styles: don’t program if you can’t see it – whereas the other extreme would be developing a framework– creating programs which can’t be seen until someone decides to illustrate its use.  

Another way to view the trade-off is to see Illustrative Programming as focused on a specific instance, whereas Axiomatic Programming emphasized the Class. An Excel speadsheet, or a User Interface, is typically one isolated instance, focused on one unique particular illustration of a problem, and as a result, doesn’t promote thinking about generalization and abstraction, whereas the risk in framework design is to embrace generality to the point where abstractions lose connection to specific usage… 
