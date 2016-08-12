---
layout: post
title: Select how to sort a list dynamically
tags:
- LINQ
- Sort
---

Last week, an interesting problem came on my desk. Initially, when I was asked to sort items, I didn’t think much of it. Given a list of items, it’s fairly trivial to use LINQ and sort it by whatever property you want. What I hadn’t quite anticipated was that the user should be able to select between multiple sorting criteria.  

If there was a predetermined sorting criterion, the problem would be straightforward. For instance, given a list of Fruits with a name, supplier and price, I can easily sort them by price:  

``` csharp
static void Main(string[] args)
{
   var apple = new Product() { Supplier = "Joe's Fruits", Name = "Apple", Price = 1.5 };
   var apricot = new Product() { Supplier = "Jack & Co", Name = "Apricot", Price = 2.5 };
   var banana = new Product() { Supplier = "Joe's Fruits", Name = "Banana", Price = 1.2 };
   var peach = new Product() { Supplier = "Jack & Co", Name = "Peach", Price = 1.5 };
   var pear = new Product() { Supplier = "Joe's Fruits", Name = "Pear", Price = 2 };

   var originalFruits = new List<Product>() { apple, apricot, banana, peach, pear };

   var sortedFruits = originalFruits
      .OrderBy(fruit => fruit.Price);

   foreach (var fruit in sortedFruits)
   {
      Console.WriteLine(string.Format("{0} from {1} has a price of {2}.", 
         fruit.Name, 
         fruit.Supplier, 
         fruit.Price));
   }

   Console.ReadLine();
}
``` 

Running this simple console application produces the following list, nicely sorted by price:

![BasicSorting]({{ site.url }}/assets/2010-10-31-BasicSorting_thumb.png)

However, if we want to give the user to select how fruits should be sorted, the problem becomes a bit more complicated. We could write a switch statement, with something like “if 1 is selected, then run this sort, else run that sort, else run that other sort”, and so on. It would work, but it would also be ugly. We would be&#160; re-writing essentially the same OrderBy statement over and over again, something which reeks of code duplication. How could we avoid that, and keep our code smelling nice and fresh?

<!--more-->

If we look at the [documentation for OrderBy](http://msdn.microsoft.com/en-us/library/bb534966(v=VS.90).aspx), it is an extension method, which applies to an IEnumerable source, and requires a keySelector, which is a method that takes an item in the IEnumerable, and returns a key, the criterion to sort by:

``` csharp
public static IOrderedEnumerable<TSource> OrderBy<TSource, TKey>(
    this IEnumerable<TSource> source,
    Func<TSource, TKey> keySelector
)
``` 

So rather than explicitly defining the keySelector in the LINQ expression, we could modify our code slightly and extract the selector out, like this:

``` csharp
var originalFruits = new List<Product>() { apple, apricot, banana, peach, pear };

Func<Product, double> sortByPrice = (product) => product.Price;

var sortedFruits = originalFruits
   .OrderBy(sortByPrice);

foreach (var fruit in sortedFruits)
{
   Console.WriteLine(string.Format("{0} from {1} has a price of {2}.",
      fruit.Name,
      fruit.Supplier,
      fruit.Price));
}

Console.ReadLine();
``` 

If you run the app at that point, we get the following result – exactly the same as before. This is progress: we managed to separate the sorting expression from the type of sorting we want to apply.

We could now easily create 3 sorting methods, by price, name or supplier:

``` csharp
var originalFruits = new List<Product>() { apple, apricot, banana, peach, pear };

Func<Product, double> sortByPrice = (product) => product.Price;
Func<Product, string> sortByName = (product) => product.Name;
Func<Product, string> sortBySupplier = (product) => product.Supplier;

var sortedFruits = originalFruits
   .OrderBy(sortBySupplier);

foreach (var fruit in sortedFruits)
{
   Console.WriteLine(string.Format("{0} from {1} has a price of {2}.",
      fruit.Name,
      fruit.Supplier,
      fruit.Price));
}

Console.ReadLine();
``` 

Running this results in the following output, where we see our fruits now nicely ordered by supplier:

![MultipleSorting]({{ site.url }}/assets/2010-10-31-MultipleSorting_thumb.png)

More progress! We are using the same loop regardless of what we sort on, and we created fairly easily 3 sorting criteria, taking one line of code each.

However, there is a bit of a problem. Now what we would like to do is to have the user select one of these sorting methods, and pass it to the loop. A reasonable approach would be to create a list of sorting methods, but a typed list can contains only items of the same nature, and right now, the first sorting criterion is a `Func<Product, double>`, whereas the 2 others have a different return type, `Func<Product, string>`.

In a bold move, let’s take the lowest common denominator between the sorting methods. No matter what, we know that we will be sorting on Product, but the result of the sorting method could be anything. We have` doubles` and `string`, we may have some `DateTime`, some `int`, you name it. Let’s just create a list of `Func<Product, object>`, and rewrite the sorting methods accordingly:

``` csharp
var originalFruits = new List<Product>() { apple, apricot, banana, peach, pear };

Func<Product, object> sortByPrice = (product) => product.Price;
Func<Product, object> sortByName = (product) => product.Name;
Func<Product, object> sortBySupplier = (product) => product.Supplier;

var sortMethods = new List<Func<Product, object>>();
sortMethods.Add(sortByPrice);
sortMethods.Add(sortByName);
sortMethods.Add(sortBySupplier);

var sortedFruits = originalFruits
   .OrderBy(sortMethods[1]);

foreach (var fruit in sortedFruits)
{
   Console.WriteLine(string.Format("{0} from {1} has a price of {2}.",
      fruit.Name,
      fruit.Supplier,
      fruit.Price));
}

Console.ReadLine();
``` 

We just created a list of sorting methods, and in the sorting expression, we passed the second criterion, sortByName. Keeping our fingers crossed, we build, run, and sit back watching the following:

![DynamicSorting]({{ site.url }}/assets/2010-10-31-DynamicSorting_thumb.png)

Our list is now nicely sorted by Name, and we have a completely dynamic structure. We could easily add new sorting criteria to the list, and any of them can be selected as a valid sorting criterion – with no code duplication.

That’s it for today – hope you enjoyed this installment! Happy trick or treat, everybody.
