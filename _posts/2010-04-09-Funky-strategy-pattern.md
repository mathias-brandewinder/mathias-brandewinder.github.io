---
layout: post
title: Funky strategy pattern
tags:
- Strategy-Pattern
- Func
---

Learning new things is difficult, but the hardest thing to do is to learn new ways to do things you have always done a certain way. Case in point: the Strategy Pattern. It is the first design pattern I was introduced to, and back then, it was an eureka moment for me.

I learnt it the "classic" way: when a class is performing an operation, but could go about it a few different ways, rather than building a switch statement in the class to handle each particular case, extract an interface for the operation, and create interchangeable concrete implementations, which can be plugged in the "Context" class at run time.

![strategy]({{ site.url }}/assets/2010-04-09-strategy_thumb.gif)

Source: [http://www.dofactory.com/Patterns/Patterns.aspx](http://www.dofactory.com/Patterns/Patterns.aspx)

For some obscure reason, I went to the Wikipedia page dedicated to the Strategy pattern recently, and was [very surprised](http://www.youtube.com/watch?v=C_S5cXbXe-4) to see that the first [C# example](http://en.wikipedia.org/wiki/Strategy_pattern#C.23) proposed didn't use polymorphism at all. 

The second example is the old-school interface/concrete implementation version, but the first illustration uses the [Func<> delegate](http://msdn.microsoft.com/en-us/library/bb549151.aspx). Here is a quick example I wrote using that approach. Rather than an interface, the Strategy can be any function that takes in a string as first argument, and returns a string as a result.

``` csharp
public class Context
{
   public Func<string, string> Strategy
   {
      get;
      set;
   }

   public string SayHello(string name)
   {
      return this.Strategy(name);
   }
}
``` 

<!--more-->

The beauty is that it removes the overhead of creating an interface and specific implementations of the strategy; you can now directly create strategies "on the fly", and pass them to the context:

``` csharp
static void Main(string[] args)
{
   var greetingMachine = new Context();

   Func<string, string> hello = (name) => "Hello, " + name;
   Func<string, string> bonjour = (nom) => "Bonjour, " + nom;

   greetingMachine.Strategy = hello;
   Console.WriteLine(greetingMachine.SayHello("Johnny"));

   greetingMachine.Strategy=bonjour;
   Console.WriteLine(greetingMachine.SayHello("Gerard"));

   Console.ReadLine();
}
``` 

Of course, the original interface-based pattern still has its use - for instance, if the strategy is more than a single method, or requires maintaining some state. What I find interesting is that if someone had shown me this code, I would not have thought of it as an incarnation of the Strategy pattern; which reflects my inability to realize that the particular C# implementation I knew (more or less inherited from Java) is not the pattern itself, and that the incorporation of Functional elements into C# does open a new set of possible incarnations for classic patterns.

For instance, I am still thinking about this [generic genetic algorithm](http://azurecoding.net/blogs/icbtw/archive/2009/06/29/genetic-algorithm-add-ur-own-func.aspx): is this a Funky<> version of the Template Method pattern? Something else? What's good about it, and what are its drawbacks? One thing is for sure  -  just for the fact that it forces my brain to bend and reconsider what I consider obvious, I [can't get enough of that Funky<> Stuff](http://www.youtube.com/watch?v=DK6vNwNEtu4)!
