---
layout: post
title: Dude, where is my log?
tags:
- NLog
- Logging
- Exceptions
- Vista
- Deployment
- C#
---

No matter how much you think you have your bases covered, users will do unexpected things with your application. Writing good unit tests: [priceless](http://www.youtube.com/watch?v=0v7D_SirqTc). For everything else, there is logging. So I decided to add exception logging to [Akin](http://www.clear-lines.com/akin.aspx), and opted for [NLog](http://www.nlog-project.org/).  

NLog rocks. It is very easy to configure: basically, add the NLog dll to your project, a configuration file defining what you want to log, and where it should go, and you are set. My configuration file looks something like that:  

``` xml
<?xml version="1.0" ?>
<nlog xmlns="http://www.nlog-project.org/schemas/NLog.xsd"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <targets>
    <target name="file" xsi:type="File"
        layout="${longdate} ${stacktrace} ${message} ${exception:format=message,type,method,stacktrace}"
        fileName="${basedir}/logs/${shortdate}.log"
        concurrentWrites="true" />
  </targets>
  <rules>
    <logger name="*" minlevel="Trace" writeTo="file" />
  </rules>
</nlog>
``` 

Which I use then to log exceptions this way:


``` csharp 
try
{
    // try to open a file
}
catch(Exception e)
{
    logger.TraceException(string.Format("Failed to open {0}.", path), e);
}
``` 

The exception gets appended to a file like 2009-06-08.log, in the logs folder located in the application folder, in that case, C:\Program Files\Akin; if the file or folder do not exist, it gets automatically created. This worked like a charm, once I realized I also needed to add the config file to the installer. 

And then I deployed on a Vista machine. Everything looked fine (I checked that logging to a message box worked), except that… there was no log file to be found. Damn.

After much anxiety and help of [StackOverflow](http://stackoverflow.com/questions/966669/nlog-does-not-write-to-file-on-vista-deployment), I found my logs. Turns out, there was a log file, but not where I expected it to be. Vista uses [File System Virtualization](http://thelazyadmin.com/blogs/thelazyadmin/archive/2007/04/26/file-system-virtualization.aspx), and writes the log to another location – in my case,

C:/Users/JohnDoe/AppData/Local/VirtualStore/Program Files (x86)/Akin/Logs/

So if you can’t find your log files, no worries. It’s just Vista playing hide-and-seek with you…
