---
layout: post
title: Create an Excel 2007 VSTO add-in&#58; display differences
tags:
- Excel-2007
- MVVM
- Binding
- Converter
- OBA
- VSTO
- Add-In
- Excel
- C#
---

{% include vsto-series.html %}

Today’s post will be much lighter than the [previous episode]({{ site.url}}/2010/04/26/create-excel-2007-vsto-add-in-read-worksheet-value/): we will display detailed information about the differences that have been found on the `ComparisonView` control. To do this, we will bind properties of the Difference to the control, and use a WPF Value Converter to dynamically format the control.   

## Displaying how the cells differ  

The add-in tracks cells where either the values or the formulas are different. We will simply display “side-by-side” the values and formulas of the cell that is being compared in the `ComparisonView` control:  

![DifferenceDisplay]({{ site.url }}/assets/2010-05-06-DifferenceDisplay_thumb.png)

To do this we need to provide a way to access the value and formula of each side of the comparison, so first we add the following properties to the `Difference` class:  

``` csharp
public class Difference
{
   public string OriginalValue
   {
      get; set;
   }

   public string OtherValue
   {
      get; set;
   }

   public string OriginalFormula
   {
      get; set;
   }

   public string OtherFormula
   {
      get; set;
   }
``` 

<!--more-->

We need to fill these, and the natural place to do this is when the list of differences is generated, in `WorksheetsComparer.FindDifferences`:

``` csharp
if (firstValue != secondValue || firstFormula != secondFormula)
{
   var difference = new Difference();
   difference.Row = row;
   difference.Column = column;
   difference.OriginalValue = firstValue;
   difference.OtherValue = secondValue;
   difference.OriginalFormula = firstFormula;
   difference.OtherFormula = secondFormula;
   differences.Add(difference);
}
``` 

Done. The only thing left is to create appropriate display elements on the `ComparisonView` control, and bind them to the properties. We need to simply display text, so a `TextBlock` would be adequate, however, I like the looks of the `TextBox` a bit better, so I’ll go for 4 read-only textboxes. After a bit of reorganization, removing the display of the row and column, expanding the grid and adding the textboxes, this is the xaml we end up with in `ComparisonView`:

``` xml
<Grid>
  <Grid.RowDefinitions>
     <RowDefinition Height="23" />
     <RowDefinition Height="23"/>
     <RowDefinition Height="23"/>
     <RowDefinition Height="23"/>
  </Grid.RowDefinitions>
  <Grid.ColumnDefinitions>
     <ColumnDefinition Width="30"/>
     <ColumnDefinition Width="55"/>
     <ColumnDefinition Width="*"/>
     <ColumnDefinition Width="30"/>
  </Grid.ColumnDefinitions>
  <Button Grid.Row="0" Grid.Column="0" Grid.RowSpan="2" 
          Command="{Binding Path=GoToPreviousDifference}"
          Content="&lt;" 
          Height="30"/>
  <Button Grid.Row="0" Grid.Column="3" Grid.RowSpan="2" 
          Command="{Binding Path=GoToNextDifference}"
          Content=">" 
          Height="30"/>
  <Label Grid.Row="0" Grid.Column="1" Content="Value"/>
  <Label Grid.Row="2" Grid.Column="1" Content="Formula"/>
  <TextBox Grid.Row="0" Grid.Column="2" 
           Text="{Binding Path=SelectedDifference.OriginalValue}"
           IsReadOnly="True"/>
  <TextBox Grid.Row="1" Grid.Column="2" 
           Text="{Binding Path=SelectedDifference.OtherValue}"
           IsReadOnly="True" Background="GhostWhite"/>
  <TextBox Grid.Row="2" Grid.Column="2" 
           Text="{Binding Path=SelectedDifference.OriginalFormula}"
           IsReadOnly="True"/>
  <TextBox Grid.Row="3" Grid.Column="2" 
           Text="{Binding Path=SelectedDifference.OtherFormula}"
           IsReadOnly="True" Background="GhostWhite"/>
</Grid>
``` 

And that’s it. Pretty straightforward, no? At that point, if you run the add-in, you’ll see something like this:

![SideBySideComparison]({{ site.url }}/assets/2010-05-06-SideBySideComparison_thumb.png)

## Spice up the display with a Converter

Because it was almost too easy this time, let’s see if we can channel the energy we have left over into improving the display (That’s the beauty of spending time upfront laying good foundations: at that point, we are merely tweaking elements, and getting a big bang for the buck in little changes).

In the example above, note that the current cell has the same value in both sheets (4), but that the formulas are different. All combinations are possible: a difference could mean that the values, the formulas, or both, are different. Wouldn’t it be nice if the textboxes displaying the content of the “other” cell was highlighted when a difference was found for that specific content (value or formula)?

I will use a converter to get the job done. I am sure there are different ways to achieve that, but it’s a useful trick to know. The idea of converters is simple: their purpose is to translate values between WPF and C#, so that you can bind anything on your view to any property of your view model.

In this case, we want to map “is there a difference?”, a boolean, to the background color of a `TextBox` (a Brush). I found these two posts helpful in [understanding](http://learnwpf.com/Posts/Post.aspx?postId=05229e33-fcd4-44d5-9982-a002f2250a64) [converters](http://www.switchonthecode.com/tutorials/wpf-tutorial-binding-converters) (they cover more complex cases than the one I will present), and I followed a similar approach.

First, let’s create a class, `HasDifferenceConverter` in the Comparison folder, which implements the interface `IValueConverter`. We need to convert one way only, from the `ViewModel` to the `View`, so we will flesh out `Convert`, and leave `ConvertBack` alone.

The `Convert` method expects to receive a bool value, and depending on that value, will return an Orange or GhostWhite color.

``` csharp
namespace ClearLines.Anakin.TaskPane.Comparison
{
   using System;
   using System.Globalization;
   using System.Windows.Data;
   using System.Windows.Media;

   [ValueConversion(typeof(bool), typeof(Brushes))]
   public class HasDifferenceConverter : IValueConverter
   {
      public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
      {
         var hasDifference = (bool)value;
         if (hasDifference)
         {
            return Brushes.Orange;
         }

         return Brushes.GhostWhite;
      }

      public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
      {
         return null;
      }
   }
}
``` 

Now let’s add the binding to the `ComparisonView`. First we need to reference the converter in the xaml. We add the namespace xmlns:this, and insert a `Resources` section at the top of the control, where we declare that “formatter” will refer to the class `HasDifferenceConverter`:

``` xml
<UserControl x:Class="ClearLines.Anakin.TaskPane.Comparison.ComparisonView"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:this="clr-namespace:ClearLines.Anakin.TaskPane.Comparison"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
   <Grid>
      <Grid.Resources>
         <this:HasDifferenceConverter x:Key="formatter"/>
      </Grid.Resources>
``` 

Then, we bind the `Background` of the two TextBoxes containing the Value and Formula of the “other” worksheet to the properties `AreValuesDifferent` and `AreFormulasDifferent`, converting the property to a Brush using the “formatter” we just declared:

``` xml
<TextBox Grid.Row="1" Grid.Column="2" 
       Text="{Binding Path=SelectedDifference.OtherValue}"
       IsReadOnly="True"
       Background="{Binding Path=SelectedDifference.AreValuesDifferent, Converter={StaticResource formatter}}"/>
``` 

Finally, we need to create these two properties on the `ViewModel`. This is completely straightforward: on `Difference`, we add the following code:

``` xml
public class Difference
{
  public bool AreValuesDifferent
  {
     get
     {
        return this.OriginalValue != this.OtherValue;
     }
  }

  public bool AreFormulasDifferent
  {
     get 
     { 
        return this.OriginalFormula != this.OtherFormula; 
     }
  }
``` 

And here we go – when we debug now, using the same example as before. There is no difference between the values, so the “other” value has an elegant GhostWhite background, but the difference between formulas is highlighted in a potent Orange. Being color blind, I don’t have high expectations in dazzling you with my color combinations – but at least I hope that you'll have enjoyed the Converter trick! 

![HighlightDifferences]({{ site.url }}/assets/2010-05-06-HighlightDifferences_thumb.png)

On that note, we’ll close shop for today. I will give the code a scrub and post it shortly, and then we will be off to other adventures, and look into deploying that add-in on a user machine. As usual, please feel free to leave me comments or questions, if anything isn’t clear, or if you know of a better way to do this!

## References

* [Using WPF converters to format numbers using format strings.](http://learnwpf.com/Posts/Post.aspx?postId=05229e33-fcd4-44d5-9982-a002f2250a64)
* [Using WPF converters to bind the colors of a traffic light to an enum.](http://www.switchonthecode.com/tutorials/wpf-tutorial-binding-converters)
