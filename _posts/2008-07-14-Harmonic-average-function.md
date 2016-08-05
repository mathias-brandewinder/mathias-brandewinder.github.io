---
layout: post
title: Harmonic average function
tags:
- Harmonic-Average
- User-Defined-Function
- Excel
- VBA
- Math
---

I was just reading [this post](http://jcandkimmita.info/jc/2008/07/data-analysis/harmonic-averages/) on Juan Carlos M&eacute;ndez-Garc&iacute;a's blog, where he describes when and how to use harmonic averages. I hadn't seen that average in a long while, and thought his example provided a good illustration as to why this seemingly odd way to compute averages would make sense.
Practically, there is one issue, though: Excel doesn't come up with a built-in Harmonic Average function. I thought I would give a shot at writing a user-defined function that does just that. The function I wrote mimics SUMPRODUCT(), but is called HarmonicAverage, and takes 2 ranges as arguments. The first range is the weight of each observation, the second the value of the observation. 

<!--more-->

The worksheet attached [(HarmonicAverage.zip (7.63 kb)](https://1drv.ms/u/s!AiindlgV58srw89_jm8y9wlyjXxZVA)) illustrates the function in action, on Juan Carlos' example. If you want to use it in your own workbook, the best way to go is to follow these steps:

1. Open your workbook, and go to Tools > Macros > Visual Basic Editor:

![]({{ site.url }}/assets/2008-07-14-VisualBasicEditor.JPG)

2. On the left-hand side, right-click on VBA Project (Your Workbook name), and select "Import File":

![]({{ site.url }}/assets/2008-07-14-ImportModule.JPG)

Navigate to the file "Module1.bas" (attached with this post, [Module1.bas (1.47 kb)](https://1drv.ms/u/s!AiindlgV58srw9ACTUJeZ3arwWh8Pw)) and select "Open"; your should now see a folder "Modules" on the left-hand side of your screen.

3. Close the editor, and go back to your workbook. Select a cell.

4. Go to Insert > Function > select the category "User Defined" > select "HarmonicAverage". You should now see a window, where you can select the range that contains the units, and the range that contains the values.

![]({{ site.url }}/assets/2008-07-14-UsingTheFunction.JPG)

That's it! Once you click OK, it should compute the Harmonic Average.

I attached below the code of the function. In spite of the weird syntax highlighting, it is written in VBA - I just could not get the syntax to work (If anyone knows how to get BlogEngine.Net to properly format VB and/or VBA code, he/she would earn my gratitude!).


``` vb
Function HarmonicAverage(unitsRange As Range, valuesRange As Range) As Double
    
    Dim numberOfItems As Integer
    numberOfItems = unitsRange.Rows.Count
    Dim numberOfValues As Integer
    numberOfValues = valuesRange.Rows.Count
    
    'Validate that the ranges have same size
    If (numberOfItems <> numberOfValues) Then
        HarmonicAverage = Error
    Else
        Dim units As Double
        Dim value As Double
        Dim totalUnits As Double
        Dim denominatorValue As Double
        Dim totalDenominator As Double
        ' Iterate over the items in the ranges
        For Item = 1 To numberOfItems
            units = unitsRange.Cells(Item, 1)
            value = valuesRange.Cells(Item, 1)
            ' Guard for 0 values
            If (value > 0) Then
                denominatorValue = units / valuesRange.Cells(Item, 1)
            Else
                denominatorValue = 0
            End If
            totalUnits = totalUnits + units
            totalDenominator = totalDenominator + denominatorValue
        Next
        If (totalDenominator > 0) Then
            HarmonicAverage = totalUnits / totalDenominator
        Else
            HarmonicAverage = Error
        End If
    End If
    
End Function
```

[(HarmonicAverage.zip (7.63 kb)]({{ site.url }}/downloads/HarmonicAverage.zip)
[Module1.bas (1.47 kb)]({{ site.url }}/downloads/Module1.bas)
