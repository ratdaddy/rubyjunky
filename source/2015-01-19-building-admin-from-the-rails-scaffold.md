---
title: Building Admin From the Rails Scaffold
date: 2015-01-19
tags: Rails, admin
---

[Previously](/get-rid-of-your-admin-gem.html) I wrote about
some problems I've been having
using the common Rails admin gems.
This is the first article I'll be writing
as part of a series
where I'll be examining just how hard it really is
to create most of the functionality of these gems from scratch
(with the help of a few smaller, single-purpose gems).

In this article we'll set up a new example application
(it's the classic blog example)
and create the basic CRUD (create/read/update/delete) functionality for our admins.
We'll also set up basic admin user accounts
to control access to our data.

READMORE

At the time of this writing Rails 4.2 is freshly out
so we'll also take advantage of some of the new features that version has to offer
(in the case of this article, foreign key constraints on models).

# Creating the Application

I like to start my new Rails applications
with a fresh version of Rails.
Often I'm not yet using that version
on my development system but I may still need to run older Rails versions
for my other projects.
Because I always try to load all my gems via bundler
and have a `Gemfile` representing each project
the first thing I do is create my project directory
and create a new `Gemfile` in it:

```bash
$ mkdir blog_project
$ cd blog_project
$ bundle init
```

I then edit the Gemfile that was created
to contain the version of Rails I wish to use:

```ruby
source 'https://rubygems.org'
gem 'rails', '4.2.0'
```

All that's left is to install Rails and all its gems,
create the project,
and create some models:

```bash
$ bundle install
$ rails new . --skip-test-unit --skip-turbolinks --database=postgresql
$ rails generate scaffold post title:string body:text author:string published:boolean published_at:datetime
$ rails generate scaffold comment body:text commenter:string email:string website:string post:references{foreign_key}
$ rake db:create db:migrate
```

# The Admin Dashboard

We'll need a page
with links
to all the models
we've created.
We'll create the controller
for an admin home page:

```bash
$ rails g controller admin home
```

To make the admin home page
reside at `/admin`
we'll change `get 'admin/home'`
in `config/routes.rb` to:

```ruby
get 'admin' => 'admin#home'`
```

All that's left
is to put links to each model's index page
in `app/views/admin/home.html.erb` like:

```erb
<h1>Admin Dashboard</h1>
<ul>
  <li><%= link_to 'Posts', posts_path %></li>
  <li><%= link_to 'Comments', comments_path %></li>
</ul>
```

# Authentication

Out of the box
Rails applications don't have any sort
of user authentication (like login forms).
If we were to deploy our applicaiton now
anyone with our server's address
could make any change they wanted
to any of the data in our application.

We'll be using the [Devise](https://github.com/plataformatec/devise) gem
to authenticate our admin users
so the first step is to add it
to our `Gemfile`.

```ruby
gem 'devise'
```

Now we can create
the admin user routes and migrations
and generally configure Devise.
We'll name our model `Admin`
because in the future we might want
to allow other types of users 
to have accounts on our system.

```bash
$ rails generate devise:install
$ rails generate devise Admin
$ rake db:migrate
```

You'll note at this point
that we've now created a new model
for admin users.
You'll probably want
to administer these users
much like the rest of the data
in your system
but you won't have resource routes,
a controller, or view templates.
You'll need to add your own routes/controller/templates
similar to the ones the scaffold previously made for us.

We'll need to disable general admin sign up
because we'll want to control who actually gets an admin account.
To do this, you'll need to modify the Devise configuration
in `app/models/admin.rb` to use only these options:

```ruby
devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable
```

We'll also need to seed the admin table
with at least one user
so that they can create and manage
any future admin users
(presumably through the admin interface we skipped building earlier).
The proper way to do this is
to add code to `db/seeds.rb`
to create that first user with a password
(which should be immediately changed on any production systems).
We'll add this to our `db/seeds.rb` file:

```ruby
Admin.create email: 'brian.vanloo@gmail.com', password: 'insecure-password'
```

It is best to make sure your `db/seeds.rb` code
is idempotent,
which in this case means
you can re-run it without it creating duplicate records.
Because Devise validations require email to be unique
this won't create duplicate records
so it's fine to leave the code this way.

To actually create our admin user
we'll need to run:

```bash
$ rake db:seed
```

# Requiring Admin Authentication

Now that we have a way to create admin users
and the initial user created on our system
we need to limit access to our admin pages.
While devise offers several methods
that can be used to control access
at different granularities
and authorization tools like [cancancan](https://github.com/CanCanCommunity/cancancan) offer even easier ways to control access,
for this example we'll take a less complicated approach.
We'll limit access to our admin dashboard
and all of the scaffold controller actions
by adding:

```ruby
before_action :authenticate_admin!
```
to the classes in `app/controllers/admin_controller.rb`, `app/controllers/comments_controller.rb`, and `app/controllers/posts_controller.rb`.
After doing that,
attempting to navigate to any of our admin pages
without being logged in as an admin
will take us to the admin sign in form.
Successfully logging in will then allow
us to perform all the operations allowed
by our scaffold controllers.

# Coming up

In a few short steps we've
been able to create our application,
define a few models with basic CRUD (create/read/update/delete) operations for them, and
create a way to limit access to those operations on those models for admin users.

However, the various tables and forms
that we get out of the box are rather barren and ugly
and perhaps a bit difficult to read and use.
In the next article in this series
we'll look at how to quickly add some styling to 
our admin pages.

Other topics we'll also need to
address to bring our admin tool to parity
with the gems already out there are:

* Searching/filtering and table ordering to allow admin users to find exactly the model records they're looking for
* How to export our form data to some common file formats (`.csv`, JSON, and XML)
