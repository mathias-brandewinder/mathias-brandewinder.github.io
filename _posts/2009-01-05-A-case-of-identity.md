---
layout: post
title: A case of identity
tags:
- C#
- Refactoring
- TDD
- Testing
---

I love the class System.Guid, because it has made my life so much easier; whenever I need a unique identifier on a class, I pop in a Guid, and get code which looks something like: 

``` csharp
public class Customer
{
    public Guid CustomerId
    {
        get;
        private set;
    }
}
```

However, I (painfully) realized today that this also required a bit of discipline. If you have code like this: 

``` csharp
public void SetPrice(Guid productId, Guid customerId)
{
    // do something here
}
```

... and have a change of heart about the order of the arguments, you'd better do that carefully, because everything will still compile just fine, even if you don't update the places where that method is called - and figuring out in debug mode what is not working can turn into quite an unpleasant experience. This is one case where you will be REALLY happy to have unit tests in place. 