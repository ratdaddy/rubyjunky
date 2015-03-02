---
title: "Creating Rails Admin Pages from Scratch (Part 1: Index)"
date: 2015-03-01
tags: Rails, admin
published: false
---

[Previously](/get-rid-of-your-admin-gem.html) I wrote about
some problems I've been having
using the common Rails admin gems.
This is the second article I'll be writing
as part of a series
where I'll be examining how easy it is
to create most of the functionality of these gems from scratch
with the help of a few smaller, single-purpose gems.

[Last time](/building-admin-from-the-rails-scaffold.html) I wrote about
how we could simply use the
Rails scaffold generator
to create our admin pages.
Eventually we'll find that approach
to be somewhat limited.
Instead what we'll do
is create our own base admin controller and views
and use those to build pages for an existing model
(the `Admin` user account model [from the previous post](/building-admin-from-the-rails-scaffold.html)).

There's a fair amount of work needed to implement the different
request types so this article will only cover the `index` action.

READMORE

## It's Time to Namespace

Up to now we've been content
using the default scaffolding
and its url routes
for our application's admin interface.
However, we're about
to run into some problems with that.
The first is the unfortunate naming
of our dashboard page.
Our route for that page is currently:

```ruby
get 'admin' => 'admin#home'
```

If we look at the routes and the path/url helper methods
for this route (using `rake routes`) we see the line:

```
admin GET        /admin(.:format)                admin#home
```

We would like to add our `Admin` model as a resource to our routes
so this is what we might put in our `config/routes.rb` file
(for now let's assume it's after the line for our dashboard page):

```ruby
resources :admins
```

Looking at our defined routes and helpers again
we'll see the previous route for our admin dashboard page
but we'll also see a resource route for our `show` action
on our `admins` controller:

```
      GET        /admins/:id(.:format)           admins#show
```

If we didn't have our dashboard route
this is the route that would have `admin_path` and `admin_url` helper methods
defined for it.
The first column of the `rake routes` output,
if it exists,
indicates the base name of the url/path helper methods
and as you can see here
our new resource route doesn't indicate that it has the `admin` helper.

The reason this becomes a problem
is that several other things in Rails
(most notably the `form_for` view helper methods)
rely on those helper methods
pointing to the resource controller.

## Using a Generator to Build a Namespaced Controller for an Existing Model

Our first thought
might be to turn to generators to build us
a namespaced scaffold.
By namespaced we mean that all the resource
routes will be prefixed with the
same starting path,
in our case we'll use `/admin`.

Rails also provides
a generator that will build the
controller and associated pieces
for an existing model.
We'll try using that to create
the namespaced scaffold for our `Admin` model:

```bash
$ rails generate scaffold_controller admin/admin email:string password:string
```

This will create a namespaced controller
and put it in `app/controllers/admin`
with a name of `admins_controller.rb`.
It will not create a route
for this new controller
so we need to add one to `config/routes.rb`:

```ruby
namespace :admin do
  resources :admins
end
```

However, there are a couple of problems
with this scheme.
One is that we would need
to change all of the references
to our `Admin` model
in the controller
from the namespaced `Admin::Admin`
to just `Admin`.

The other is that the `form_for(@admin_admin)` statement
in the view's form partial bases its `<form>` action URL
on the model's name.
Because of that
it won't properly follow our routing namespace scheme.
While this can be fixed
by modifying the form partial
it means we would have to do this
for each model we build an admin page for.

## Building Our Own Admin Controller

It turns out that the generator isn't doing much for us.
We can do better
if we build our own base admin controller class
and simply derive our namespaced admin controller classes from that.
In the process we'll do a bit of metaprogramming
to abstract the actions in our controller
to work with our models.

To keep things manageable
for this article we'll only create the `index` action.
Future articles will cover the rest of the actions.

### The Datagrid Gem

There is a lot of functionality
on the index page of the admin gems.
To avoid developing this all ourselves
we'll look to the [Datagrid](https://github.com/bogdan/datagrid) gem.
Datagrid works well with a couple of the pagination gems
so we'll choose [Kaminari](https://github.com/amatsuda/kaminari) for our implementation
and add them to our `Gemfile`.

```ruby
gem 'datagrid'
gem 'kaminari'
```

With these two gems
we'll get a way to create
paged tables that
can be sorted on selected fields.
We can also define
our own filters to decide
which records from our models
we wish to have displayed.

### Building a Base Controller

To figure out what we need
for our base admin controller let's first
look at what the Datagrid scaffold would build for us
by running `rails g datagrid:scaffold admin`.
Note that for our solution
we will not be using the Datagrid scaffold generator
but because setup for this gem is fairly complex
we'll use a trial run as reference output.

This is the `index` action we'll see
in the controller class that Datagrid creates for us
(it happens to be the only action this generator creates):

```ruby
def index
  @grid = AdminsGrid.new(params[:admins_grid]) do |scope|
    scope.page(params[:page])
  end
end
```

To create an `index` method for our base admin controller
we'll need to do a bit of metaprogramming
wherever we see 'admins' in this code.
Specifically we'll need:

- `AdminsGrid` - we will be defining a grid class
  for every model in our admin interface
  so that we can define
  the filters and fields
  we wish to use (more on how we do that in a bit).
- `params[:admins_grid]` - the form data for the filter
  on each grid page.

We will also
structure our base controller
a bit differently but we'll get to that in a bit.
First let's take a look
at how we want the controller for our model to look:

```ruby
class Admin::AdminsController < Admin::BaseController
  class Grid
    include Datagrid
    scope { Admin }
    #...
  end
end
```

That will be it for now.
We're going to define the `Grid` class
for each model type
in the corresponding controller
rather than having a separate directory
of these classes.

Going back to our base controller
we can see it will be fairly straightforward
to get the grid class and maybe just
a little more work
to get the correct parameters
from the `params` hash.

We've added a default of 10
for the number of items to show per page
by adding `.per(10)` to our scope.
We will also need 
to provide a path for the filter form
so we'll set the instance variable `@index_path`
for this purpose.
Finally, we'll want to render a base form template
and we'll need to explicitly call that out
in our `render` method call.

```ruby
class Admin::BaseController < ApplicationController
  def index
    @grid = grid_class.new(grid_params) do |scope|
      scope.page(params[:page]).per(10)
    end
    @index_path = request.path
    render 'admin/base/index'
  end
end
```

### Some Fancy Metaprogramming

We now need to write methods
for `grid_class` and `grid_params`:

```ruby
class Admin::BaseController < ApplicationController
  # ...

private
  def grid_class
    @@grid_class ||= eval(grid_class_name)
  end

  def grid_params
    params[grid_class_name.underscore]
  end

  def grid_class_name
    @@grid_class_name ||= "#{self.class.name}::Grid"
  end
end
```

Note here that we've memoized a couple of things
using class variables.
This speeds up our controller modestly
and we can use class variables
because these values
will remain constant for all instantiations of objects
from the child class.
We did not memoize `grid_params`
because we anticipate that it could
be different for every request.

### The Base View

The default view for the base controller index can be pretty much the same
as what we were given by Datagrid's scaffold generator.
Our file wil reside
at `app/views/admin/base/index.html.erb` and in it we see:

```erb
<%= datagrid_form_for @grid, :method => :get, :url => @index_path %>

<%= paginate(@grid.assets) %>
<%= datagrid_table @grid %>
<%= paginate(@grid.assets) %>
```

We saw earlier how `@grid` and `@index_path`
were set in our `index` action.

### What Goes in the Grid Class?

It's now time to fill in the `Grid` class
we created in our `Admin::AdminsController` earlier.
This class is a DSL for the Datagrid gem
and it primarily defines two things about our grid display:
the fields to use in a form
to filter which items we want displayed
and the columns to display.
For our `Admin` model we have several fields
defined by the Devise gem that we might want to display.
For example, we might define our `Grid` like:

```ruby
class Admin::AdminsController < Admin::BaseController
  class Grid
    include Datagrid

    scope { Admin }

    filter(:id, :integer)
    filter(:email, :string) { |value| where('email like ?', "%#{value}%") }
    filter(:sign_in_count, :integer)
    filter(:last_sign_in_at, :date, range: true)
    filter(:created_at, :date, :range => true)

    column(:id)
    column(:email)
    column(:sign_in_count)
    column(:current_sign_in_at) do |model|
      model.current_sign_in_at.to_time if model.last_sign_in_at
    end
    column(:last_sign_in_at) do |model|
      model.last_sign_in_at.to_time if model.last_sign_in_at
    end
    column(:created_at) do |model|
      model.created_at.to_time
    end
  end
end
```

One thing to note here is that I didn't
use a full string match on the email field
but instead I'm using `like` pattern matching.
This way our users can enter
partial email addresses in
and have the filter act more like a search function.

You can read more on the Datagrid DSL [on github](https://github.com/bogdan/datagrid).

### Linking to our New Page

Finally we need to add a link
to our new admin users index to our admin home page
in `app/views/admin/home.html.erb`:

```erb
<ul>
  <li><%= link_to 'Admin Users', admin_admins_path %></li>
  ...
</ul>
```

When we navigate to our new index page
we'll see something like this:

![Example index page](admin_index.png)

## Conclusion

While this looks like quite a bit of code
for just the index action,
we'll have a lot more control
over where our admin pages go from here.
We can override the index action
for individual controllers
to set things up slightly differently
if we wish to.

Index is also likely
one of the most difficult actions
to create/display.
We should see in future articles
that the other actions like show, new/create, and edit/update
are much simpler to implement.
