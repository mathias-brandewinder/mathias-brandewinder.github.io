---
layout: post
title: Exploring the PowerPoint TextRange object
tags:
- VSTO
- C#
- Powerpoint
- Text
- Textrange
- Office
---

In a previous post, we saw how to programmatically [search for text in a PowerPoint slide]({{ site.url }}/2010/08/08/Finding-Text-in-a-PowerPoint-slide-with-C/), by iterating over the Shapes contained in a slide, finding the ones that have a TextFrame, and accessing their TextRange property. [TextRange](http://msdn.microsoft.com/en-us/library/bb251500(office.12).aspx) exposes a Text property, which “represents the text contained in the specified object”.   

Our goal is to translate a slide from a language to another, which means translating every chunk of text we find. However, the Text property contains a bit more than just text. Suppose you were working with a slide like the one below, which contains multiple bullet points, with various indentations:  

![DaftPunkSlide]({{ site.url }}/assets/2010-08-21-DaftPunkSlide_thumb.png)

If you inspect the Text for the content area, you’ll see that it looks like this:  

`Work It\rMake It\rDo It\rMakes Us\rHarder\rBetter\rFaster\rStronger`

At the end of each bullet point, we have a `\r`, which indicates a line break. If we want to maintain the formatting of our slide when we translate it, we’ll have to deal with it.

We’ll worry about the actual&#160; translation later – for the moment we will use a fake method, which will show us what chunk of text has been translated:

```  csharp
public static string Translate(string text)
{
   return "Translated [" + text + "]";
}
``` 

## A crude approach

A first approach would be to simply take the entire `Text` we find in the `TextRange`, manually separate it into chunks by splitting it around the carriage return character, translating the chunk, and re-composing the text, re-inserting the carriage returns.

Starting where we left off last time, let’s loop over the `Shapes` in the slide:

``` csharp
private void TranslateSlide()
{
   var powerpoint = Globals.ThisAddIn.Application;
   var presentation = powerpoint.ActivePresentation;
   var slide = (PowerPoint.Slide)powerpoint.ActiveWindow.View.Slide;
   foreach (PowerPoint.Shape shape in slide.Shapes)
   {
      if (shape.HasTextFrame == Microsoft.Office.Core.MsoTriState.msoTrue)
      {
         var textFrame = shape.TextFrame;
         var textRange = textFrame.TextRange;
         var text = textRange.Text;
         textRange.Text = CrudeApproach(text);
      }
   }
}
``` 

<!--more-->

The `CrudeApproach` method splits the text around the Carriage Return character (char 13), and performs a “fake” translation for the moment:

``` csharp
private string CrudeApproach(string text)
{
   var carriageReturn = (char)13;
   var textChunks = text.Split(carriageReturn);
   var translatedText = "";

   var chunks = textChunks.Length;
   for (int i = 0; i < chunks; i++)
   {
      var chunk = textChunks[i];
      translatedText += Translate(chunk);
      if (i < chunks - 1)
      {
         translatedText += carriageReturn;
      }
   }

   return translatedText;
}
``` 

If we run this on the example slide, this is what we get:

![CrudeModification]({{ site.url }}/assets/2010-08-21-CrudeModification_thumb.png)

Not too bad: each bullet point has been translated separately, and reproduced as an individual bullet point. There is a problem, though: we lost indentation. All bullet points are now represented at the same level, which was not the case in the original slide. 

## A better way

What is the problem with the “crude way”? The issue is that while the text we retrieved stored information about line breaks, it didn’t show anything about indentation. Where is that information stored?

The trick is to use the `Paragraphs()` method of the `TextRange` class, which returns… more `TextRanges`. `TextRange.Paragraphs(int first, int howMany)` returns the paragraphs in the range, starting at the first paragraph, and returns “howMany” paragraphs. Conveniently, `TextRange.Paragraphs(-1, -1)` returns all the paragraphs in the range.

Using this, we can now rewrite our code along these lines:

``` csharp
foreach (PowerPoint.Shape shape in slide.Shapes)
{
   if (shape.HasTextFrame == Microsoft.Office.Core.MsoTriState.msoTrue)
   {
      var textFrame = shape.TextFrame;
      var textRange = textFrame.TextRange;
      var paragraphs = textRange.Paragraphs(-1, -1);
      foreach (PowerPoint.TextRange paragraph in paragraphs)
      {
         var text = paragraph.Text;
         text = text.Replace("\r", "");
         paragraph.Text = Translate(text);
      }
   }
}
``` 

Running this code on our slide, we get the following result, which shows that each bullet points gets translated individually, while maintaining the indentation:

![Indented]({{ site.url }}/assets/2010-08-21-Indented_thumb.png)

Two comments on the code. First, if you go in debug mode and dig into the the first highlighted `textRange`, you’ll see two properties, `Count` and `IndentLevel`. `IndentLevel` represents the indentation of the text, and has a weird value of –2147483648, because there is no clear value for the indentation (we have a hodgepodge of paragraphs with various indentations), and `Count` is set to 1. The **paragraphs** `TextRange` `IndentLevel` is still uninformative, but `Count` is now at 8, indicating that the original textRange has been broken down into 8 paragraphs in the `TextRange`. Finally, each **paragraph** in the foreach loop has a Count of 1, and an indentation of 1 or 2, now properly representing the indentation of each bullet point. 

Then, note the line:

``` csharp
text = text.Replace("\r", "");
``` 

The reason for this is the following. The text of each paragraph ends with `\r`, a line break, and when text is added to a `TextRange`, a line break is automatically added. As a result, if we didn’t have that line of code, we would be adding 2 line breaks, involuntarily creating an extra paragraph each time – and creating an ever-expanding paragraph (*One piece I am still not clear on is that without that line, the “collection” is being modified while the iteration is going on, something which normally results in an exception but doesn’t here; I guess I’ll have to dig deeper to figure out how the TextRange really works*). 

That’s it for today, folks! Next time, we’ll try to plug in a real translation and wrap up that series. In the meanwhile, if you have any comments on this, please let me know. I am still pretty new to the PowerPoint object model, and I’d love to hear if you know of better ways to do this. Until then, take care, and “Work it harder, make it better”!

<iframe width="420" height="315" src="https://www.youtube.com/embed/K2cYWfq--Nw" frameborder="0" allowfullscreen></iframe>
