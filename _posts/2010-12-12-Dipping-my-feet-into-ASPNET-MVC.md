---
layout: post
title: Dipping my feet into ASP.NET MVC
tags:
- ASP.NET-MVC
- Unit-Tests
- TDD
- Authorize
---

I recently began playing with ASP.NET MVC (never too late), and so far I really enjoy it. One aspect I really appreciate is its testability – I can write fairly straightforward unit tests to verify that the application behaves as I believe it should, as well as make sure I understand what is going on.  

One point which got me stumped was how to test for authorization. A controller, or some of its methods, can be decorated with the attribute [Authorize], restricting users who can access the method by role or name. In the default ASP.NET MVC 2 template, when a user isn’t authorized to a specific area, he gets re-directed to the LogOn method on the AccountController.  So far so good. However, I ran into unexpected issues when I attempted to unit test that. Suppose there are two roles in our web application, Chicken and Pigs, and that we have a Controller that leads to a pigs-only area of the web site:  

``` csharp
[Authorize(Roles = "Pig")]
public class PigsOnlyController : Controller
{
   public ActionResult Index()
   {
      return View("Index");
   }
}
``` 

My first thought was to mock the ControllerContext and do something along these lines:

``` csharp
[Test]
public void OnlyPigsShouldAccessIndex()
{
   var context = new Mock<ControllerContext>();
   var userName = "PIG";
   context.SetupGet(p => p.HttpContext.User.Identity.Name).Returns(userName);
   context.SetupGet(p => p.HttpContext.Request.IsAuthenticated).Returns(true);
   context.Setup(p => p.HttpContext.User.IsInRole("Pig")).Returns(true);

   var controller = new PigsOnlyController();
   controller.ControllerContext = context.Object;

   // check what controller.Index() returns
}
``` 

However, while the web application itself behaved properly (Users in the Pig role get to the Index page, whereas Chicken get redirected to the Logon page), the test wasn’t doing what I expected: both Pigs and Chicken were happily reaching the Pigs-Only area.

As is often the case, I found out why on [StackOverflow](http://stackoverflow.com/questions/669175/unit-testing-asp-net-mvc-authorize-attribute-to-verify-redirect-to-login-page); the reason is that the re-direction is not the responsibility of the Controller. If the controller is properly decorated, the Index method won’t even be invoked, and where the call gets redirected to is handled in a different part.

So how do you unit test this behavior? In this case, we trust the framework to handle the redirection, so the only functionality we need to ascertain is that the Controller has the proper attribute.

Instead of validating the redirection, we can verify that the Controller class has an Authorize attribute, with the proper roles specified:

``` csharp
[Test]
public void ControllerShouldAuthorizePigsButNotChicken()
{
   var information = typeof(PigsOnlyController);
   var attributes = information.GetCustomAttributes(typeof(AuthorizeAttribute), false);
   Assert.AreEqual(1, attributes.Length);

   var authorization = attributes[0] as AuthorizeAttribute;
   var authorizedRoles = authorization.Roles;

   var roles = authorizedRoles.Split(',');
   Assert.IsTrue(roles.Contains("Pig"));
   Assert.IsFalse(roles.Contains("Chicken"));
}
``` 

I am not totally happy with the hard-coded strings “Pig” and “Chicken” in the test, but I don’t see a way around it; maybe it’s a sign that this test is more of an integration test than a unit test? If you know of a better way to test for that aspect, I am all ears!
