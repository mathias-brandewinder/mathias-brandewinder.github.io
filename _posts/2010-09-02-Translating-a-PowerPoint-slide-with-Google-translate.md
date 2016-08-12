---
layout: post
title: Translating a PowerPoint slide with Google translate
tags:
- Powerpoint
- VSTO
- C#
- Translation
- Office
---

The beauty of working with a framework like .NET is that when you have a problem, chances are, someone else did before you, and might have even resolved it for you. In our last post, I explained how to [find text in a PowerPoint slide using C#.]({{ site.url }}/2010/08/21/Exploring-the-PowerPoint-TextRange-object/). My goal was to translate it using the Google Translate service, and I intended to write my own code to call the web service and retrieve the translation. Turns out, there is a [.NET API for Google Translate](http://code.google.com/p/google-api-for-dotnet/), ready to use, which does it for you already (of course, I found that out already after rolling out my own code, which wasn’t nearly as good).  

Building up where we left off, I quickly wrote this class, which will translate the slide currently in view; I think the code is self-explanatory: get the slide, create a Google translator, pass it the language of origin and of destination, and translate every chunk of text you find! The only thing I needed to do was to download GoogleTranslateAPI_0.3.1, add the dll to the project as a reference.  

```  csharp
namespace ClearLines.PowerPointTranslator
{
   using Google.API.Translate;
   using PowerPoint = Microsoft.Office.Interop.PowerPoint;

   public class SlideTranslator
   {
      public static void TranslateSlide(Language from, Language to)
      {
         var googleTranslator = new TranslateClient("http://www.clear-lines.com");

         var powerpoint = Globals.ThisAddIn.Application;
         var slide = (PowerPoint.Slide)powerpoint.ActiveWindow.View.Slide;

         foreach (PowerPoint.Shape shape in slide.Shapes)
         {
            if (shape.HasTextFrame == Microsoft.Office.Core.MsoTriState.msoTrue)
            {
               var textFrame = shape.TextFrame;
               var textRange = textFrame.TextRange;
               TranslateTextRange(textRange, googleTranslator, from, to);
            }
         }
      }

      public static void TranslateTextRange(
         PowerPoint.TextRange textRange, 
         TranslateClient translator, 
         Language from,
         Language to)
      {
         var paragraphs = textRange.Paragraphs(-1, -1);
         foreach (PowerPoint.TextRange paragraph in paragraphs)
         {
            var text = paragraph.Text;
            text = text.Replace("\r", "");
            paragraph.Text = translator.Translate(text, from, to);
         }
      }
   }
}
``` 

Later this week, after I do some code scrubbing, I’ll post the entire VSTO solution. Until then, have fun – it’s almost the week-end!
