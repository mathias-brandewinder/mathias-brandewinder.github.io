---
layout: post
title: Strategy or Func
tags:
- Translation
- Func
- Strategy-Pattern
- Design-Patterns
---

![fail-owned-translation-fail]({{ site.url }}/assets/2010-09-19-fail-owned-translation-fail.jpg)

I have been involved recently with a project for a foreign company with offices in the US; the US team receives lots of documents in a foreign language which require translation, and they were interested in a way to speed up the process, using [Bing Translator](http://www.microsofttranslator.com/) and [Google Translate](http://translate.google.com/#).   

Why not just pick one? Both are awesome, but if you have tried them, you know the results can be somewhat random. Having the option to compare their respective results is a good way to make sure you end up with something which makes sense.  This sounded like a perfect case for the Strategy Pattern. I started by defining a common interface:  

``` csharp
public interface ITranslator
{
  string TranslateToHindi(string original);
  string TranslateToEnglish(string original);
}
``` 

… and implemented two versions, the **BingTranslator** and the **GoogleTranslator**, using the API for each of these services. So far so good, but when I started working on the user interface, I ran into a small problem. My user interface has just 2 buttons, “translate to English”, and “Translate to Hindi”, and Ideally, I would have liked to&#160; just pass the specific language pair to use, along these lines:

```  csharp
private void toEnglishButton_Click(object sender, RibbonControlEventArgs e)
{
  ITranslator translator = this.GetTranslator();
  this.TranslateStuff(translator, stuffToTranslate, “en”, “hi”);
}
``` 

<!--more-->

However, there is a small issue here: the Google Translation .NET API and Bing Translator use different codes for languages. I could add a generic signature to the interface, like this:

``` csharp
string Translate(string original, string from, string to);
``` 

But in that case, I would have to convert “from” and “to” to the proper language code for each version. Not very difficult, but un-necessarily complicated. Worse, the interface would have a general signature, suggesting that any language can be requested, with only 2 languages supported, which is pretty misleading.

And then I realized that this was a perfect situation for the [Funky Strategy Pattern]({{ site.url }}/2010/04/09/Funky-strategy-pattern/):

```  csharp
private void toHindiButton_Click(object sender, RibbonControlEventArgs e)
{
   ITranslator translator = this.GetTranslator();
   Func<string,string> translation = translator.TranslateToHindi;
   this.TranslateStuff(stuffToTranslate, translation);
}

private void toEnglishButton_Click(object sender, RibbonControlEventArgs e)
{
   ITranslator translator = this.GetTranslator();
   Func<string, string> translation = translator.TranslateToEnglish;
   this.TranslateStuff(stuffToTranslate, translation);
}
``` 

No matter what language and translator we use, the translator is expected to receive a string, the original text, and return another string, the result of the translation. Rather than mess around trying to translate language codes into each specific Translator system, just retrieve the method that corresponds to the language of interest for the current translator, and pass that method (Func) instead of the Translator, which we can then use deeper in the code along these lines:

``` csharp
public static IList<string> TranslateList(
 IList<string> paragraphs,
 Func<string, string> translation)
{
    var translated = new List<string>();
    foreach (string paragraph in paragraphs)
    {
        translated.Add(translation(paragraph);
    }
    
    return translated;
}
``` 

If the objective was to support multiple language pairs, this would not be a great design, but in this case, where it’s clear that only two languages are going to be used, this is an approach which works really well – and is very economical.
