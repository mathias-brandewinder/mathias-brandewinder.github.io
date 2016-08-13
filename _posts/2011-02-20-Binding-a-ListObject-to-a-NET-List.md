---
layout: post
title: Binding a ListObject to a .NET List
tags:
- Listobject
- Excel
- C#
- VSTO
---

While browsing the [ListObject](http://msdn.microsoft.com/en-us/library/microsoft.office.tools.excel.listobject.aspx) documentation today, I realized that, while all the examples given focused on binding to a DataSet, it also supports databinding to “any component that implements the IList interface”. This is something I wasn’t aware of, so I figured I would give it a try.  

I quickly created a Excel 2007 Template project in VS2010, and added a simple Product class as follow:  

``` csharp
public class Product
{
   public string Name { get; set; }
   public double Price { get; set; }
}
``` 

I then added the following code behind Sheet1, creating a straightforward list of Product, as well as a ListObject, setting the DataSource to the list:

``` csharp
public partial class Sheet1
{
   private List<Product> products;
   private ListObject listObject;

   private void Sheet1_Startup(object sender, System.EventArgs e)
   {
      this.listObject = this.Controls.AddListObject(this.Range["B2"], "Products");

      this.products = new List<Product>();
      this.products.Add(new Product() { Name = "Alpha", Price = 10d });
      this.products.Add(new Product() { Name = "Bravo", Price = 20d });
      this.products.Add(new Product() { Name = "Charlie", Price = 30d });

      this.listObject.DataSource = products;
      this.listObject.AutoSetDataBoundColumnHeaders = true;
   }
   // auto-generated code omitted
}
``` 

Hit F5, and watch:

![image]({{ site.url }}/assets/2011-02-20-image_thumb_1.png)

Out of the box, we get a nicely formatted list, with filters in the headers. If anything, that’s a convenient way to display a list of items on a Worksheet. I didn’t have time to dig deeper into it, but I am now very curious about how much more can be done with this mechanism. Can I add data validation? Can I control what properties to display?
