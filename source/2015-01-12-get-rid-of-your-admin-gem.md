---
title: Get Rid of Your Admin Gem
date: 2015-01-12
tags: Rails, ActiveAdmin, Rails Admin
---

After using the two most popular Rails admin gems
[ActiveAdmin](http://activeadmin.info/)
and [RailsAdmin](https://github.com/sferik/rails_admin)
I have been increasingly disillusioned with their overall utility.
While they both provide a quick way
to put up a *pretty* interface to the
various models in your system,
they also come with their own baggage:
application bloat and inflexibility amongst them.
Eventually you may find it necessary
to modify their configurations and inner workings
to the point where it might have been easier
to just build things from scratch in the first place.

In this post I'll look at
some of the basics of these two popular gems
and some of the drawbacks I've encountered using them.
In subsequent articles I'll explore
what it takes to build your own admin interface
providing admin users on your site
the controls necessary to make changes to the system
to keep their users happy.

READMORE

After reading the rationale
for why it's good to write your own admin interface,
come back here to read the other articles in the series
where we look at what it takes to create our interface:

- [Building Admin From the Rails Scaffold](2015-01-19-building-admin-from-the-rails-scaffold.html)

## [ActiveAdmin](http://activeadmin.info/) and [RailsAdmin](https://github.com/sferik/rails_admin)

These two widely-used gems
come with essentially the same set of features out of the box:

- A Browser interface to perform CRUD on your models:
  You can Create/Read/Update/Delete records
  in your model using easy-to-navigate web forms and displayed pages and tables.
- Form validations:
  The create and update forms can key off
  the defined validations in your model
  telling you which fields are required
  and preventing your admin users from entering invalid data.
- Search and filtering:
  Various forms of searching and filtering
  can be performed on the index view
  of the paginated rows in your model tables.
- Data export:
  Data can be exported to `.csv`, JSON, or XML format files.
- Authorization and authentication:
  Both gems use [Devise](https://github.com/plataformatec/devise) for admin user authorization
  and [CanCan](https://github.com/ryanb/cancan) for authentication.
  This way you can create individual admin users
  and control what data they are allowed
  to see and modify.

## Problems

Let's take a look at some
of the problems I've found
while using these tools.

### Not The Rails Way

ActiveAdmin introduces
its own view/controller structure
that you must learn.
Because of this certain things
you understand from Rails aren't clear
like how to pass data between the controller and display code
(hint, it's probably not via an instance variable like in Rails). 

RailsAdmin doesn't really follow
a view/controller pattern at all.
Instead you define a series of
view types right along with their display information.

Also, although you can define normal Rails template views
to be used by each of these gems,
they each come with their own display DSLs.
The gems attempt to leverage meta data from the models,
like model attributes and types,
to display the data with less code needing to be written.
There are provisions for using
whatever templating system you've chosen for your application,
like ERB or HAML,
but that's not what the admin gems use out of the box.

### Soon You're All In

By default, once you've set up
a model to use one of these gems
it will display all fields on that model.
This seems good at first
until you take a look at a table or particularly long display or create/update form.
There may be old fields on the model
or fields your admin never cares about.
Fortunately, both gems allow you
to override the default and configure which fields will appear in the various displays.

The downside is that once you start configuring fields for a model
you must remember to add or exclude new fields
from the admin configuration
as you add them to your model.
I find that fairly soon I am choosing which fields to display
for all my models
and this is no more convenient
than if I were building my own admin interface.

### The Admin Definition Code Ends up in Weird Places

ActiveAdmin puts its configuration/code
in an `apps/admin` subdirectory.
RailsAdmin either puts the entire configuration
in one big file in `config/initializers/rails_admin.rb`
or has you include it in each model.
In either case this
doesn't follow Rails' conventions
for locating controller and view code.

### You May End up With Inefficient Queries

While you can configure custom derived fields
for the various view types
it can sometimes be difficult crafting efficient queries.
This is especially true for things like associated records
where you might want to do something like counting or summing
some attributes of those records.
It gets even worse when you want
to display some aggregate values of associated models
followed by a ratio of two of them that you've already calculated.
The table display logic
will cause your application
to loop through
queries for each aggregate value
then go back and possibly
do both queries yet again to calculate the ratio.

### Limited View Types Per Model Class

ActiveAdmin only allows controls
for a given model
to be defined once.
If you want an index table with a different set of information
you will need to derive another model
specifically for that purpose.
Contrast this to what you might do
in a vanilla Rails application
where you could either
create additional actions on a model's controller
or use one action that looks at additional URL parameters
to produce different index views.

### Can be Too Powerful

Because the admin gems abstract away operations like record deletion
you might need to be careful that associated records
are properly deleted (or not)
as per your business requirements.
You encounter a similar problem
when creating new records,
especially if you're trying not to use `ActiveRecord` callbacks
(which generally, you should try to avoid).

It's nice having all the controls you might want
added to the interface for you
but you need to make sure that
the default behaviors of your models
match what you intend for the application
especially when you're not directly invoking
operations like model object delete and create.

### It Bloats Your Application

These admin gems drag in a bunch of other dependencies
when you add them to your `Gemfile`. 
I've [written elsewhere](http://www.toptal.com/ruby-on-rails/top-10-mistakes-that-rails-programmers-make#common-mistake-5-using-too-many-gems) on
why lots of gems in your application can be a problem.

## Summing up

There are a lot of tradeoffs
to consider when using an admin gem in your application.
Over the next few weeks I'll
be examining just how hard
it would be to patch together
an equivalent set of functionality
through smaller gems
and coding your admin interface yourself.
In the process we'll
see if we can't build a more robust and powerful admin interface
that better suits the needs of our admin users
without having to spend too much on development in the process.
