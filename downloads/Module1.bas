Attribute VB_Name = "Module1"
' Written by Mathias Brandewinder
' Clear Lines Consulting, LLC
' http://www.clear-lines.com/blog
' Feel free to use this in any way you find fit
' Acknowledgements are always welcome, though!

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
