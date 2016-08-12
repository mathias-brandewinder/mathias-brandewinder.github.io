---
layout: post
title: More dynamic list sorting
tags:
- LINQ
- Sort
---

A little while ago, I looked into [dynamically sorting a list]({{ site.url }}/2010/10/31/Select-how-to-sort-a-list-dynamically/), based on a criterion supplied by the user. There was one limit on the solution I presented, however: only one criterion could be applied at a time. What if we wanted to sort by multiple criteria?  
For instance, using the same example as in the previous post, if we had a list of `Products` with a Name, a `Supplier` and a `Price`, how would we go about sorting by Supplier and then by Price? Or by Name and then Supplier? And how could we make that flexible, so that we can sort by an arbitrary number of criteria. This would be particularly useful if we had in mind the development of a user interface where users could select how they want to see a list of items displayed on screen.  

Besides **OrderBy**, LINQ provides the **[ThenBy](http://msdn.microsoft.com/en-us/library/bb534743.aspx)
<a href="http://msdn.microsoft.com/en-us/library/bb534743.aspx">ThenBy</a>** extension method. `ThenBy` is applied to an `IOrderedEnumerable` – a collection that has already been ordered – and sorts its, maintaining the existing order. For instance, in the following example, products are first sorted by `Supplier`, and for each `Supplier`, by `Price`:  

``` csharp
private static void Main(string[] args)
{
   var apple = new Product() { Supplier = "Joe's Fruits", Name = "Apple", Price = 1.5 };
   var apricot = new Product() { Supplier = "Jack & Co", Name = "Apricot", Price = 2.5 };
   var banana = new Product() { Supplier = "Joe's Fruits", Name = "Banana", Price = 1.2 };
   var peach = new Product() { Supplier = "Jack & Co", Name = "Peach", Price = 1.5 };
   var pear = new Product() { Supplier = "Joe's Fruits", Name = "Pear", Price = 2 };

   var originalFruits = new List<Product>() { apple, apricot, banana, peach, pear }; 

   Func<Product, IComparable> sortByPrice = (product) => product.Price;
   Func<Product, IComparable> sortByName = (product) => product.Name;
   Func<Product, IComparable> sortBySupplier = (product) => product.Supplier;

   var sortedFruits = originalFruits
      .OrderBy(sortBySupplier)
      .ThenBy(sortByPrice);

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

<!--more-->

Note that this is not the same as the following:

``` csharp
var sortedFruits = originalFruits
   .OrderBy(sortBySupplier)
   .OrderBy(sortByPrice);
``` 

This version orders products by `Supplier` first, and then completely re-orders by `Price`, ignoring the initial sorting by `Supplier`.

Now that we know how to perform a hierarchical sort, let’s see if we can go further and make that more dynamic, by applying an arbitrary list of sorting criteria. Naively following the pattern we have established above, we need a list of sorting criteria, which we will apply in order, first using `OrderBy`, then `ThenBy`:

``` csharp
public static IEnumerable<Product> HierarchicalSort(
   IEnumerable<Product> products,
   IList<Func<Product, IComparable>> criteria)
{
   if (criteria == null || criteria.Count == 0)
   {
      return products;
   }

   var sorted = products.OrderBy(criteria[0]);
   for (var index = 1; index < criteria.Count; index++)
   {
      sorted = sorted.ThenBy(criteria[index]);
   }

   return sorted;
}
``` 

Let’s try that out, and use the HierarchicalSort method in place of the hard-coded sortedFruit:

``` csharp
var criteria = new List<Func<Product, IComparable>>();
criteria.Add(sortBySupplier);
criteria.Add(sortByPrice);

var sortedFruits = Sort.HierarchicalSort(originalFruits, criteria);
``` 

Running it produces the following output, sorting fruits by price for each supplier:

![HierarchicalSort]({{ site.url }}/assets/2010-12-26-HierarchicalSort_thumb.png)

That’s it – we now have a sorting method which will take an arbitrary list of criteria, and apply it in order to a list of items. It wouldn’t take much of an effort to turn it into a generic method – I trust that my smart readers won’t have much of a problem with that part.
