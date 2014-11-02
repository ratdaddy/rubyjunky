---
title: Getting Strapped Down by Bootstrap
date: 2014-11-01
tags: Bootstrap, Foundation, Bourbon/Neat/Bitters/Refills, CSS, Sass, less
---

[Twitter's Bootstrap](http://getbootstrap.com/) is a CSS styling framework that can easily be dropped into a web application providing a nice look and responsive design out of the box. For developers that are design-challenged like myself, tools like this provide a very nice polish over the browser's default settings.

While the framework is easy to implement it encourages a coding style for the HTML in your application that makes your code less maintainable and goes against many best practices that you probably use throughout the rest of your code. The biggest part of the problem is the prescribed class names that you have to put in your HTML to define how you'd like your page to be styled.

READMORE

## Grid Layouts

Most page frameworks provide a 12-column grid as their default layout and Bootstrap is no different. To get a bit of a feel for how they suggest you create grid markup let's look at an example where we define some terms. The terms will be on the left, taking up about a quarter of the page and the definition will be on the right. It will look something like this:

<table>
<tr>
<td style="border: none; width: 25%; vertical-align: top;">Semantic Markup</td>
<td style="border: none; vertical-align: top;">Separation of presentation and content is a methodology applied in the context of various publishing technology disciplines</td>
</tr>
<tr>
<td style="border: none; background: #fff; vertical-align: top;">Cascading Style Sheet</td>
<td style="border: none; background: #fff; vertical-align: top;">A style sheet language used for describing the look and formatting of a document written in a markup language</td>
</tr>
</table>

The HTML for a single definition using Bootstrap will be structured like this:

	<div class="container">
      <div class="row">
        <div class="col-md-3">
          ...
        </div>
        <div class="col-md-9">
          ...
        </div>
      </div>
	</div>

It's important to note here that the class names `container`, `row`, `col-md-3`, and `col-md-9` have been given to us by the Bootstrap framework. As developers we would never accept a programming language that dictated what all of our variable names must be so i. It's interesting that we accept the same from our page styling framework.

The biggest problem with markup like this is what happens when we need to make a change. Let's say for instance that we decide we want to change our definition column to be larger and to take up about a third of the page rather than a quarter. Let's also say we have quite a few definitions on our page that will need to be changed. Now we potentially have to change multiple instances of `col-md-3` to `col-md-4` and `col-md-9` to `col-md-8`. The problem only gets worse if we've replicated this markup on several different pages.

## Button, Button...

Buttons are another example where your markup may become a bit ugly. Say for instance that we wish to put a button on our page, styled by Bootstrap, make it the "primary" button color, and make it smaller than a standard size button. So if we wanted something that looked like this:

<button style="padding: 5px 10px; font-size: 12px; line-height: 1.5; border-radius: 3px; color: #ffffff; background-color: #428bca; border: 1px solid #357ebd">Do It Now!</button>

In Bootstrap our markup for that button will look like:

	<button type="button" class="btn btn-primary btn-sm">Do It Now!</button>

Notice again, Bootstrap tells us we have to give our button exactly the classes `btn`, `btn-primary`, and `btn-sm` (and don't forget that it's "sm" and not "small" on that last item).

As above, if we decide to start making changes to the style of our pages we're somewhat handicapped in what we can easily do. For instance, let's say we only want to change the color of our call to action buttons like above. Bootstrap exposes the Less/Sass variables controlling our button color as `@btn-primary-color`, `@btn-primary-bg`, and `@btn-primary-border`. But what if we've added the `btn-primary` class to buttons other than our call to action button? We may have to change them to another Bootstrap button type and then set the color on that type to match the old primary color. Again this is more code than we should need to change.

## Semantic Markup

To address these problems we should fall back on our software development best practices. In this case, we should be abstracting explicit information about our styling out of our HTML and moving it into our CSS, using names for elements of our markup that are applicable to our domain. That way we can label a set of buttons for a similar task with the same name. Now the styling changes for those buttons can be limited to a single place in our CSS file. This is ultimately where all of our styling decisions should reside.

This is a form of [semantic markup](http://en.wikipedia.org/wiki/Semantic_markup), something the recommended practices of Bootstrap and its common usage violates.

Ideally, we'd like the markup from the two examples above to look something more like:


	<div class="definition">
	  <div class="term">
	    ...
	  </div>
	  <div class="description">
	    ...
	  </div>
	</div>

	<button type="button" class="call-to-action">Do It Now!</button>

## Enter Less or Sass

It turns out we have good tools to structure our web applications to use semantic markup. The two most popular being [Less](http://lesscss.org/) and [Sass](http://sass-lang.com/) which are CSS preprocessors that use a superset of CSS syntax. Both of these tools allow the creators of styling libraries to provide nice styling defaults like Bootstrap does without dictating the naming conventions that you must use for your HTML classes.

Web application frameworks provide support for one or both of these preprocessors either natively or with the use of a plugin.

## Alternatives to Bootstrap

Some readers may be quick to point out that Bootstrap is written in Less (with a port to Sass so you can use it with either preprocessor) and promotes changing certain aspects of its default styling through the use of variables. However, the documentation has little coverage of the mixins needed to  create your own CSS classes (some past Bootstrap versions excluded the mixins from the documentation entirely). A quick survey of sites claiming to use Bootstrap from listings like the [Bootstrap Expo](http://expo.getbootstrap.com/) and [Built with Bootstrap](http://builtwithbootstrap.com/) would seem to indicate that most developers are using the HTML conventions dictated by Bootstrap.

There are other styling frameworks out there that are geared towards using semantic markup for your styling. Two of the more popular ones are [Foundation](http://foundation.zurb.com/) and the [Bourbon/Neat/Bitters/Refills](http://bourbon.io/) libraries.

The Foundation library sits inbetween Bootstrap and the Bourbon ecosystem in that it both provides its own CSS class definitions and well-documented mixins and variables to use with Sass.

Bourbon, Neat, Bitters, and Refills are a collections of libraries and patterns that exist exclusively as Sass mixins and variables requiring you to define your own classes in your Sass/CSS files. Extending the example of semantic HTML we looked at above we can get styling similar to our Bootstrap examples with the following Sass code:

	.definition {
	  @include outer_container;
	  .term {
	    @include span-columns(3);
	  }
	  .description {
	    @include span-columns(9);
	  }
	}
	
	button.call-to-action {
	  @include button;
	}

In this example I've only used the mixins provided by Bourbon/Neat but you could also add any other CSS styling to these elements.

## Wrapping it up

Twitter's Bootstrap framework has spared many a developer from ugly default web page styling, however it typically comes with the cost of suggesting bad code design. This leads to potential maintainability problems as your application grows.

As design frameworks like Foundation and Bourbon/Neat/Bitters/Refills that encourage the use of semantic markup continue to evolve, developers should be more willing to consider them as their go-to for starting to create a well-designed site. Not only do they provide nice looking web pages from the start they'll allow your styling to easily evolve with your application as it grows over time.
