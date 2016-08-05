---
layout: post
title: VSTO vs. VBA performance comparison
tags:
- VSTO
- C#
- Performance
- Simulation
- Excel
---

During my VSTO add-in session last week-end, the following question came up: what performance difference should I expect if I run code in VSTO instead of VBA? This is particularly important for Excel power users, who leverage VBA to automate their workbooks and run computation intensive procedures. One audience member had a good example: he used VBA to run Monte-Carlo simulations on budget forecasts stored in Excel.My answer was that I expected VSTO to outperform VBA in the area of pure computation, but that VBA might do better for direct interaction with the application (reading data for instance), because of overhead. However, I had no hard evidence for that, and the question got me wondering, so I decided to run comparisons. My first test confirmed my intuition: on a calculation-heavy procedure, the VSTO code ran about 3 times faster than the equivalent VBA code (30 seconds vs. 1 minute and a half, on the same machine).

<!--more-->

The code I wrote was intended to isolate computation speed; to do that, I tried to write something simple and comparable in both languages, using little memory, with no interaction with the host application.The code performs a simple Monte Carlo simulation, replicating the gambler's ruin problem. A gambler calls heads or tails, starting with $30, and loses/wins 1$ at every coin toss; what is the probability that he loses all his money if he plays up to 1,000 times? The simulation runs 1,000,000 games, and records all the cases where the gambler is ruined. The code for both implementations is provided below.Next I'll try and see how things look with procedures involving lots of object manipulation and memory usage. Oh, and the by the way, the gambler has about 34% chances of going home with no money left!

**The VBA version:**

``` vb
Option Explicit
Public Sub GamblerRuin() 
Dim startTime As Date
Dim endTime As Date
startTime = Now
Dim run As Long
Dim runs As Long
Dim game As Integer
Dim games As Integer
Dim ruins As Long
Dim toss As Double

runs = 1000000
games = 1000

For run = 1 To runs
    Dim fortune As Integer
    fortune = 30    
    For game = 0 To games
        toss = Rnd()
        If toss < 0.5 Then
            fortune = fortune + 1
        Else
            fortune = fortune - 1
        End If
        If fortune <= 0 Then
            ruins = ruins + 1
            Exit For
        End If
    Next
Next

endTime = Now
Dim proba As Double
proba = ruins / runs
MsgBox (startTime & endTime & proba)
End Sub
```

**The C# / VSTO version**

 ``` csharp 
 public void Run()
 {    
    RunStart = DateTime.Now;
    Random randomizer = new Random();
    int runs = 1000000;
    int ruins = 0;
    int games = 1000;
    for (int run = 0; run < runs; run++)
    {
        int fortune = 30;
        for (int game = 0; game < games; game++)
        {            
            double toss = randomizer.NextDouble();            
            if (toss < 0.5)            
            {                
                fortune--;            
            }            
            else            
            {                
                fortune++;            
            }
            if (fortune <= 0)            
            {                
                ruins++;                
                break;            
            }        
        }    
    }    

    RunEnd = DateTime.Now;    
    double proba = (double)ruins / (double)runs;    
    MessageBox.Show(string.Format("Started at {0} and ended at {1}: {2} ruins probability observed.", RunStart.ToLongTimeString(), RunEnd.ToLongTimeString(), proba.ToString()));
 }
```   
