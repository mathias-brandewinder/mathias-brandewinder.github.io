---
layout: post
title: Selecting an item in a list with WPF and M-V-VM
tags:
- Design
- WPF
- User-Interface
- MVVM
---

The M-V-VM seminar of last month inspired me to finally get serious about WPF. The best way to learn a technology is to write some code with it, so I have begun working on a project of my own, which I hope to complete by end-March (in spite of being working full bore on a project for a client).  So far, working with Model-View-ViewModel and WPF has proven easier than what I expected. Once you get the logic, things flow pretty naturally. One of my recent stumbling blocks was binding with a collection. Now that I got it to work, it seems trivial, but maybe this will help some other WPF beginner on the path to enlightenment!  Imagine that your model contains a list of persons, and that you want to display two things:  

1) the list of persons,

2) detailed information about the selected person  

<!--more-->

First, let's create a WPF application project, and add a super-simple Person class: 

``` csharp 
public class Person
{
    public string LastName
    {
        get;
        set;
    }
    public string FirstName
    {
        get;
        set;
    }
}
``` 

For the sake of simplicity, in this example we will not separate the Model and ViewModel. Let's add a class ViewModel, with an ObservableCollection of Persons, which we pre-populate at construction time. 

``` csharp 
public class ViewModel
{
    private ObservableCollection<Person> m_Persons;
    public ObservableCollection<Person> Persons
    {
        get
        {
            return m_Persons;
        }
    }
    public ViewModel()
    {
        var albert = new Person() { FirstName = "Albert", LastName = "Einstein" };
        var bruno = new Person() { FirstName = "Bruno", LastName = "Latour" };
        var charles = new Person() { FirstName = "Charles", LastName = "Darwin" };
        m_Persons = new ObservableCollection<Person>() { albert, bruno, charles };
    }
}
``` 

Our first task is to build a view to display the ModelView. We will use the main Window (which I renamed as "MainWindow") as the view, replace the Grid by a StackPanel, and add a ListView to it. 

``` xml
<Window x:Class="WpfCollectionSelectionTest.MainWindow"
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
Title="MainWindow" Height="300" Width="150">
<StackPanel>
<ListBox Height="150" 
Name="personsListBox" />
</StackPanel>
</Window>
``` 

Let's connect the View to the ViewModel. In the "startup" code of the application, we instantiate a ViewModel, and pass it as the DataContext to the View, in this case, the Window. This will allow the View to have access to data from the ViewModel. Note that the ViewModel knows nothing about the View. 

``` csharp 
public MainWindow()
{
    InitializeComponent();
    var viewModel = new ViewModel();
    DataContext = viewModel;
}
``` 

We want the ListBox to fill from the collection in the ViewModel. To do this, add the following code to the ListBox: 

``` xml
<ListBox Height="150" 
Name="personsListBox" 
ItemsSource="{Binding Persons}" 
DisplayMemberPath="LastName"/>
``` 

The first part, ItemsSource, binds the contents of the ListBox to the ObservableCollection, by telling it to look for the Persons property in the DataContext (our ViewModel class). The second part declares that the data should be displayed calling the LastName property on the items in the list. If you don't do this, by default the display will call "ToString()", which is typically not all that great. 
First part is done; if you run the app, you should see the ListBox display the names of some fine people. 

Now let's add the following code to the ViewModel, to keep track of the selected Person: 

``` csharp 
private Person m_SelectedPerson;
public Person SelectedPerson
{
    get
    {
        return m_SelectedPerson;
    }
    set
    {
        m_SelectedPerson = value;
    }
}
``` 

we want the selected item in the ListBox to drive the SelectedPerson in the ViewModel. We could do this by setting the selection through code in the view, working with the DataContext, or firing events. Rather, we will use binding again, and bind the SelectedItem property on the ListBox to the SelectedPerson property in the ViewModel, by adding this code: 

``` xml
<ListBox Height="150" 
Name="personsListBox" 
ItemsSource="{Binding Persons}" 
DisplayMemberPath="LastName"
SelectedItem="{Binding SelectedPerson}" />
``` 

To prove that the binding work, let's add this code to the View, which will display the FirstName and LastName of the SelectedPerson: 

``` xml
<StackPanel>
<ListBox Height="150" 
Name="personsListBox" 
ItemsSource="{Binding Persons}" 
DisplayMemberPath="LastName"
SelectedItem="{Binding SelectedPerson}" />
<Label Content="Selected person"/>
<Label Content="{Binding SelectedPerson.FirstName}"/>
<Label Content="{Binding SelectedPerson.LastName}"/>
</StackPanel>
``` 

Et voila! If you run the application, the list should be populated, and whenever you select a person in that list, it will update the selected person in the View Model, and display the first and last name in the view. 
