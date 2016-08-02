---
layout: post
title: First steps in Silverlight
tags:
- Silverlight
---

Unless you are living (and working) under a rock, if you are a .NET developer, 
you must have come across the word Silverlight in the past few months. In a 
nutshell, &ldquo;Microsoft&reg; Silverlight&trade; is a cross-browser, cross-platform plug-in 
for delivering the next generation of .NET based media experiences and rich 
interactive applications for the Web&rdquo;.


I have attended a few presentations about Silverlight recently, and 
[was really impressed by the results](http://silverlight.net/Showcase). 
The thing is, demos ARE designed to look good &ndash; what they are 
not designed for is to show you the limitations of the technology. You will find 
that part on your own, when you start actually using it. I was pretty impressed 
by what Silverlight could do - I thought it was time for me to check out what 
Silvelight would actually do for me, on a real example. You can see the 
[final result here](http://www.clear-lines.com/samples/silverlight001/stopmotion.html).

<!--more-->

## Use case

Silverlight's announced strength is "fast, cost-effective delivery of 
high-quality video to all major browsers running on the Mac OS or Windows"; on 
the other hand, in its current released version (1.0), it comes with virtually 
no standard controls out of the box. Therefore, I chose a project light on 
controls, but where video playing was crucial, and decided to refactor a page of 
my personal website, where visitors can choose from a list of videos, and play 
them on the page. I was never satisfied with the original page; the rendering 
was unpredictable, depending on the installation of the media player plugin in 
the browser.

The use case for the page is:

- The user is presented the choice between multiple videos
- The user selects a video
- The system accesses the video through its url
- The system plays the video

## Solution

The solution implemented is very simple - you can watch the result 
[here](http://www.clear-lines.com/samples/silverlight001/stopmotion.html). 
I created a main Silverlight control, defined through a xaml file, containing 5 
&ldquo;buttons&rdquo;, each of them corresponding to the selection of a video, and a &ldquo;video 
player&rdquo; to play them. I also created a plain html page, with a a div section to 
host the Silverlight control. The control is instantiated through a javascript 
in its own file:

``` html

<script type="text/javascript">

function createMySilverlightPlugin()
{  
   Silverlight.createObject(


   "VideoPlayer.xaml", 


   parentElement,  


   "videoControlHost", 


   { width:'800',  height:'500', inplaceInstallPrompt:false, background:'white', isWindowless:'false', framerate:'24', version:'1.0'}, 


   { onError:null, onLoad:null }, 


   null);                         

}

</script> 
``` 

The control is organized through a 
xaml file, which contains a main canvas (the outermost container for the 
control) and 6 canvasses for each of the controls. Each nested canvas contains 
information defining its location in the main canvas, and the type, appearance 
and behavior of each control, through xml-style tags and 
attributes. (For brevity, I omitted the canvasses for button 3 to 6).

``` xml
<Canvas
   xmlns="http://schemas.microsoft.com/client/2007"
   xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
   Height="400" Width="400" Background="white" Canvas.Left="100" Canvas.Top="100">
  
  <Canvas 
      MouseLeftButtonDown="PlayTrack1"
      MouseEnter="EnterTrack1Button"
      MouseLeave="LeaveTrack1Button"
      Canvas.Left="5" Canvas.Top="5">
    <Rectangle x:Name="playTrack1Rectangle" 
      Stroke="#d0d0d0" StrokeThickness="2" Fill="white"
       Height="30" Width="150" RadiusX="3" RadiusY="3" >
    </Rectangle>
    <TextBlock
      Canvas.Left="5" Canvas.Top="5" Text="Mission and 18th" FontFamily="Verdana" Foreground="black" />
  </Canvas>

  <Canvas 
      MouseLeftButtonDown="PlayTrack2" 
      MouseEnter="EnterTrack2Button"
      MouseLeave="LeaveTrack2Button"
      Canvas.Left="5" Canvas.Top="45">
    <Rectangle x:Name="playTrack2Rectangle"
      Stroke="#d0d0d0" StrokeThickness="2" Fill="white"
       Height="30" Width="150" RadiusX="3" RadiusY="3">
    </Rectangle>
    <TextBlock 
      Canvas.Left="5" Canvas.Top="5" Text="Door" FontFamily="Verdana" Foreground="black" />
  </Canvas>
 
  <Canvas
    Canvas.Left="170" Canvas.Top="5">
    <Rectangle x:Name="borderAroundVideo"
       Stroke="#d0d0d0" StrokeThickness="2" Fill="white"
       Width="420" Height="320"
       RadiusX="3" RadiusY="3">
    </Rectangle>
    <MediaElement x:Name="VideoDisplay"
      Source="door.wmv" 
      Width="400" Height="300"
      Canvas.Top="10" Canvas.Left="10"/>
  </Canvas>

</Canvas>
```

Each button has a `MouseLeftButtonDown` event, defined in the xaml file. Its property 
is set to a string which corresponds to the name of a javascript function hosted 
on the html page. The event triggers a javascript specific to the selected 
button, which stops whatever could be playing in the video player, sets the 
reference to the url of the video file specific to that button, and starts the 
video player.

In addition to that, each button has 2 events, `MouseEnter` and `MouseLeave`, which dynamically change the 
color of the box, through its property, when the mouse hovers over into and out 
of the box. 

``` html
<script type="text/javascript">
function PlayTrack1(sender, args) 
{
    sender.findName("VideoDisplay").stop();
    sender.findName("VideoDisplay").Source="http://www.brandewinder.com/movies/missionand18.wmv";
    sender.findName("VideoDisplay").play();
}

function EnterTrack1Button(sender, args)
{
    sender.findName("playTrack1Rectangle").Fill="red";
}
function LeaveTrack1Button(sender, args)
{
    sender.findName("playTrack1Rectangle").Fill="white";
}
</script>
``` 

## Conclusion 

I am reasonably familiar with web applications, but this is not my area 
of expertise; in particular, I have no expertise in Javascript &ndash; this was 
essentially my first time writing some javascript. Yet, I was surprised at how 
easy it was to get the video player to work. It took me about 2 hours, included 
[reading through the tutorials](http://silverlight.net/quickstarts/silverlight10/default.aspx) 
(which are great, by the way), to get the page 
to the state you can see. Getting rich media to play with active x controls 
always looked to me like a form of dark magic, and IE and Firefox seem to always 
be fighting each other when it&rsquo;s time to play audio or videos. Silverlight got 
this to work flawlessly in both browsers, in under 2 hours.

The code itself is very inelegant, and its limits are obvious to me. 
The amount of code duplication between the scripts corresponding to each of the 
buttons is ugly. This should blamed on my lack of knowledge of javascript, but 
it is also a choice; I wanted to get something to work quickly, and chose to 
display the code as is was after 2 hours of work, rather than show a 
full-fledge, polished solution. I will build on it soon to clean up these 
issues.  

Silverlight lets you do amazing things with 
animations, so I had originally intended to have cool-looking buttons, animated 
when hovered on and clicked. That part turned out to be a bit more complex than 
I anticipated; I got it to nearly work, except that when the mouse was moved 
over the text label, it ceased to recognize that it was over the box. I think it 
is because the text label is over the box, and hides it, and I will try to get 
that resolved in my next iteration. However, the fact remains that using Visual 
Studio 2005 only, getting a simple button-like control took some work.

Finally, I had initially planned on hosting the xaml component in an 
ASP.NET page, and ran into problems. I could not figure out yet what the issue 
was; it seems to be related to using masterpages, themes, and possibly the fact 
that the masterpage contains a javascript. Silverlight does work with ASP.NET 
and masterpages, so this in itself is not the problem, but until I understand 
what is going on I had to opt temporarily for a simple html 
page.
