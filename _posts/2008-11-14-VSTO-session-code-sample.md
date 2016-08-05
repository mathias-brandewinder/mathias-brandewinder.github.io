---
layout: post
title: VSTO session: code sample
tags:
- VSTO
- Add-In
- Office
- Svcc
---

Thanks to you guys who attended my session on VSTO at Silicon Valley Code Camp 2008! This was the first time I gave a talk on VSTO, and I really enjoyed the discussion and questions. 

I have put the code I presented up for download [here]({{ site.url }}/files/tictactoe.zip); it includes the TicTacToe "engine", the add-in itself, the installer, and the Excel workbook. As a result, the download is somewhat big - sorry! The purpose of the code was to keep things simple and understandable, and it could definitely be tightened up. Specifically, it is very optimistic in the way it is accessing the data in the workbook: adding some checks for whether a workbook/worksheet are open would be highly recommended... Let me know if you have questions or comments! 
