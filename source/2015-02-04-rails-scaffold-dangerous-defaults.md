---
title: Rails Scaffold's Dangerous Defaults
date: 2015-02-04
tags: Rails, scaffold, security
---

A big attraction to Rails
is how quickly
you can set up
a database-backed web application
with a decent amount of functionality.
The Rails generators
are a big help
to initialize components
and construct
a scaffold of all the things you need
to make a resource:
models, migrations, controllers, views, routes, and even tests.

While the scaffold generator
can help build wide swaths
of an application,
you do need to pay some attention
to what it's doing for you.
One thing that might surprise developers
is how accommodating
the default scaffold is
in replying to requests for different data formats.

In this article I'll look
at how blindly using the
Rails scaffold generator (version 4.2 as I write this)
can inadvertently expose data
you might otherwise have thought
was secret to your application.

READMORE

## Building a New Resource

To demonstrate this problem
we'll use an existing Rails 4.2 application
and generate a new resource
using the scaffold generator
to get all the component files
we might need.
This resource will have
some information
that we intend to expose, `name`,
and also some information
that we don't want to show our users, `secret_info`.
Our generate command might look something like this:

```bash
$ rails generate scaffold user_info name:string secret_info:string
      invoke  active_record
      create    db/migrate/20150210074643_create_user_infos.rb
      create    app/models/user_info.rb
      invoke    test_unit
      create      test/models/user_info_test.rb
      create      test/fixtures/user_infos.yml
      invoke  resource_route
       route    resources :user_infos
      invoke  responders_controller
      create    app/controllers/user_infos_controller.rb
      invoke    erb
      create      app/views/user_infos
      create      app/views/user_infos/index.html.erb
      create      app/views/user_infos/edit.html.erb
      create      app/views/user_infos/show.html.erb
      create      app/views/user_infos/new.html.erb
      create      app/views/user_infos/_form.html.erb
      invoke    test_unit
      create      test/controllers/user_infos_controller_test.rb
      invoke    helper
      create      app/helpers/user_infos_helper.rb
      invoke      test_unit
      invoke    jbuilder
      create      app/views/user_infos/index.json.jbuilder
      create      app/views/user_infos/show.json.jbuilder
      invoke  assets
      invoke    coffee
      create      app/assets/javascripts/user_infos.coffee
      invoke    scss
      create      app/assets/stylesheets/user_infos.scss
      invoke  scss
      create    app/assets/stylesheets/scaffolds.scss
```

The important lines to note here
are the ones involving jbuilder.
Rails now runs it by default
and creates the JSON view files for the index and show methods.

Since we know we don't want to display `secret_info`
and we've only been thinking of our application as being page-based and browser-only
we would remove references
to it in the various `.html.erb` files we're familiar with.

## The Problem

Despite removing the `secret_info` references in our HTML views,
when we run our server
and access it using `curl` from a terminal
asking for a JSON formatted response,
we find that we can access
all the data we built with our scaffold:

```bash
$ curl localhost:3000/user_infos.json
[{"id":1,"name":"Brian","secret_info":"this user is really smart","url":"http://localhost:3000/user_infos/1.json"}]
```

Again, this might be a bit surprising
since we never intended to build a JSON API for our application
nor did we access it using AJAX from our browser pages.

## An Attempted Solution

Thinking the problem might be the jbuilder files
created by the scaffold you can go ahead and remove them
from the views directory:

```bash 
$ rm app/views/user_infos/*.jbuilder
```

This at least takes care of the problem
of exposing our `secret_info`.
However, on a production environment
it returns a 500 error:

```json
$ curl localhost:3000/user_infos.json
{"status":"500","error":"Internal Server Error"}
```

This comes with the usual big ugly stack backtrace in the log file
and may also trigger any application monitoring tools you have running like
[Honeybadger](https://www.honeybadger.io/) or
[Airbrake](https://airbrake.io/).
The complaint is the missing jbuilder template we removed.

Trying to access files of other MIME types
by using other extensions like `.xml`
will give similar results.

## The Real Solution

The best way to handle this
is to add a constraint to the resource's route
limiting requests to HTML.
Doing this will insure
that any clients that attempt to access our server
requesting formats other than HTML will
get an appropriate response.

```ruby
resources :user_infos, constraints: { format: :html }
```

Now using a `curl` command that displays only the status code
when we try to request JSON
we see the appropriate error code:

```
$ curl -w "%{http_code}\n" -o /dev/null -s localhost:3000/user_infos.json
404
```

You get the same error code
for other MIME types.

## Don't Trust the Generators

My personal preference
is to limit the use of Rails' generators.
Since I'm a fairly strict adherent
to [outside-in testing](http://robots.thoughtbot.com/testing-from-the-outsidein)
if I rely on scaffolds
I end up with chunks of code
that don't have feature-level tests.

I also see a good number of Rails applications
that have remnants of previous generator runs in them
With specs that were never implemented
and are left in the pending state,
each star in the output making me a little sad.
Assets and helpers also
remain unused yet checked into the application's repository.

When I'm developing an application I will often have a directory
sitting right next to the directory I'm working on
set up with the same version of Rails.
I will run the full scaffold generator there
to reference what is generated
because each version of Rails uses controllers, tests, assets and other files slightly differently.
I then go back to my application,
open up an editor with a new blank file
for the component I'm creating and add
only the code I actually need.
That way I don't end up with actions in my controller
that I don't ever use.
I also limit my resource routes
to only the actions I'm actually using,
eliminating routes for actions
I don't yet have feature-level tests for
or may never use like `edit`/`update` and `delete`.

The one exception I usually make
is to use the generator to create my models
and their associated migrations.
There's a fair amount of convention
around the migration class and DSL
and it's usually more typing than I
can easily replicate paging back and forth
to my example directory.

In the end, you shouldn't put too much trust
in code you haven't written yourself.
Many bugs and security holes
occur in the areas of our applications
that we understand the least.
