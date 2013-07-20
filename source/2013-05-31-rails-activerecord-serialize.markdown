---
title: Rails ActiveRecord Serialize
date: 2013-05-31
tags: Rails, ActiveRecord, serialize, Serialization
---

First off I have to admit I am not the best Googler in the world. So when I set out to figure out how to store a bunch of key/value pairs into a single text column in a database it is somewhat understandable that I turned up confusing results around Rails serialize. Unfortunately it looks like they've somewhat overloaded the "serialize" concept in Rails. The root of the term refers to both:

1. [The notion of marshaling your data into a string of text and storing it in a column in the database.](http://api.rubyonrails.org/classes/ActiveRecord/Base.html#label-Saving%2Barrays%252C%2Bhashes%252C%2Band%2Bother%2Bnon-mappable%2Bobjects%2Bin%2Btext%2Bcolumns)
2. [Creating data for a rails API (often to be used with a JavaScript framework) from a model.](http://api.rubyonrails.org/classes/ActiveModel/Serialization.html)

My use case is storing a bunch of key/value data that I don't necessarily control the source of. I may want to add data for new keys or have older keys' data be deprecated. Also, I likely won't need to query on any of the data so one of the best solutions would be to encode the data into some kind of text format and store it as a `text` column on an appropriately associated model. I'm using MySQL and thus don't have the capabilities of a nosql or schema-less database at my disposal.

READMORE

I wanted to be able to use my data as much like an ActiveRecord object as possible. For instance, being able to use it in a `form_for` helper or possibly do validations on the data.

Rails provides the foundational structure for marshaling and storing arbitrary data in `ActiveRecord` with the [`serialize`](http://api.rubyonrails.org/classes/ActiveRecord/Base.html#label-Saving%2Barrays%252C%2Bhashes%252C%2Band%2Bother%2Bnon-mappable%2Bobjects%2Bin%2Btext%2Bcolumns) method.
Our implementation starts with a parent model that will contain the `text` column for our data (in this case a `User` class). We'll provide information about our data, which we'll call `properties`, to the parent model by sending a message to `serialize`.

```ruby
class User < ActiveRecord::Base
  serialize :properties
end
```

We need to make sure there is a place for our data by adding the appropriate migration and running it:

```bash
$ rails generate migration AddPropertiesToUser properties:text
$ rake db:migrate
```

Now if we create a new user their `properties` attribute starts out as `nil`:

```ruby
irb(main):001:0> user = User.create
irb(main):002:0> user.properties #=> nil
```

## Storing new data

At this point `user.properties` needs to have a data structure assigned to it. The quickest and easiest way to do this is to use a standard Ruby `Hash` object and we'll also go ahead and save our hash to our database:

```ruby
irb(main):003:0> user.properties = { twitter_handle: '@BrianVanLoo', location: 'CA' }
irb(main):004:0> user.save
```

 Now that we've saved the `user` object let's take a look at what is stored in the `properties` column in the database:

```
---\n:twitter_handle: '@BrianVanLoo'\n:location: CA\n
```

So what is this string? It turns out it is the [YAML](http://yaml.org/) representation of the `Hash` passed in earlier. YAML is the default "coder" for a serialized attribute and it allows us to store an object and pull it out into the same object type. Retrieving that record again gives us our original `Hash`:

```ruby
irb(main):005:0> user = User.last
irb(main):006:0> user.properties #=> {:twitter_handle=>"@BrianVanLoo", :location=>"CA"}
```

## Using a different coder

It turns out it probably isn't a great idea to use YAML to encode things inside our Rails application. I won't re-hash all the security issues that have come to light using YAML but Bryan Helmcamp has a good write-up in his [Code Climate blog](http://blog.codeclimate.com/blog/2013/03/27/rails-insecure-defaults#).

As Bryan describes in his blog, `JSON` can be used as an alternative coder. The `serialize` method takes a second optional parameter which is a class that defines the coder to use to serialize the data:

```ruby
class User < ActiveRecord::Base
  serialize :properties, JSON
end
```

Now when we create an object and save it as above we see this JSON encoded string in the database:

```
{"twitter_handle":"@BrianVanLoo","location":"CA"}
```

We need to be careful because when our data is put in to the database the keys are symbols but as it comes back out, the json format is not able to preserve the data type so the keys are now strings:

```ruby
irb(main):007:0> user = User.last
irb(main):008:0> user.properties #=> {"twitter_handle"=>"@BrianVanLoo", "location"=>"CA"}
```

Here again things are a bit overloaded as that second serialize parameter also defines the object type to be retrieved. If the retrieved object isn't a descendant of the given class hierarchy an exception will be raised. There will be a bit more on that later.

## Storing other object types

This all works great as long as a `Hash` or other simple object is all we need to store. But what happens when we want to have a more complex class? In my case I wanted to use the object in a form helper, perhaps like this:

```erb
<%= form_for @user.properties do |f| %>
  #...
<% end %>
```

One of the first problems this presents is that `properties` for a newly created user object is still `nil` giving us an error like this if we have set `@user` in our controller to something like `User.new`:

```
ActionView::Template::Error (undefined method `model_name' for NilClass:Class):
    1: <%= form_for @user.properties do |f| %>
    2:   #...
    3: <% end %>
```

This can be taken care of by initializing `properties` to an empty hash in the controller:

```ruby
@user.properties ||= {}
```

Now we'll get a similar error complaining about the `model_name` method being undefined:

```
ActionView::Template::Error (undefined method `model_name' for Hash:Class):
    1: <%= form_for @user.properties do |f| %>
    2:   #...
    3: <% end %>
```

The problem we have is that `form_for` wants an object that looks more like an `ActiveRecord`. Jos&eacute; Valim explains what needs to be done to make a PORO into a suitable object in chapter 2 of his [Pragmatic Programmers](https://pragprog.com/) book: [Crafting Rails 4 Applications](http://pragprog.com/book/jvrails2/crafting-rails-4-applications). We'll also throw in a couple of attributes that we want to set and get so now our
`Properties` model will look something like:

```ruby
class User
  class Properties
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    attr_accessor :twitter_handle, :location

    def persisted?; true end

    def id; 1 end
  end
end
```

We also had to create methods for `persisted?` and `id`. In our parent `User` model these things make sense but here in  the `Properties` model it's a bit more difficult to get them to do the right thing. For now we'll give them some default return values that generally won't matter.

## Storing our object

Returning to the `User` model that will be storing our new, more capable object, we can replace the
`JSON` serializer with our new object:

```ruby
class User < ActiveRecord::Base
  serialize :properties, Properties
end
```

One of the first things we notice is that instantiating a new `User` object will also
make us a new `Properties` object:

```ruby
irb(main):007:0> user = User.new
irb(main):008:0> user.properties #=> #<User::Properties:0x9c579e4>
```

At this point we can remove the empty hash initialization we put in the controller earlier.

As might now be expected, our new object will be serialized with YAML because the `JSON` object
has been replaced. Now our object looks something like this in the database:

```
--- !ruby/object:User::Properties {}\n
```

## Writing our own serializer

The trick is to have our `Properties` class be recognizable as something that can serialize
itself. There doesn't appear to be any readily available documentation describing this but a quick
read of the `serialize` method [source code](https://github.com/rails/rails/blob/master/activerecord/lib/active_record/attribute_methods/serialization.rb#L38) shows that we need to provide our own class methods for `load` and `dump`:

```ruby
def serialize(attr_name, class_name = Object)
  ...

  coder = if [:load, :dump].all? { |x| class_name.respond_to?(x) }
            class_name
          else
            Coders::YAMLColumn.new(class_name)
          end

  ...
end
```

To get our `Properties` class to quack like a coder we'll add the needed methods:

```ruby
class User
  class Properties
    ...

    def self.load json
      obj = self.new
      unless json.nil?
        attrs = JSON.parse json
        obj.twitter_handle = attrs['twitter_handle']
        obj.location = attrs['location']
      end
      obj
    end

    def self.dump obj
      obj.to_json if obj
    end
  end
end
```

We now have a properties object that will work with the `form_for` helper and behave
a lot like an `ActiveRecord` object. When we add the appropriate create and/or update controller methods
we're there. Let's take a quick look at some examples of setting, saving, and getting
attributes:

```ruby
irb(main):009:0> user = User.new
irb(main):010:0> user.properties.twitter_handle = '@BrianVanLoo'
irb(main):011:0> user.save
irb(main):012:0> User.last.properties.twitter_handle #=> "@BrianVanLoo"
```

Finally, a quick peek in the database shows our object properly serialized as a json string:

```
{"twitter_handle":"@BrianVanLoo"}
```

## What's left?

There are still a few bits of ugliness left before this works as a good generalized solution:

 * `Properties` should be DRYed up a bit better. Setting the attributes in `load` should work off a list of attributes used throughout the class.
 * The `persisted?` and `id` methods that were stuck in `Properties` to satisfy the `form_for` helper are really based on attributes of the `User` model. There doesn't appear to be a clean way to let `Properties` know about `User` like passing in a reference in `initialize`. As it stands, anywhere a `Properties` object is used you'll probably want to keep around its associated `User` to properly answer questions like this and to perform operations like `save` once you've set your properties.

Overall the `ActiveRecord` serialize method gives a decent hook into storing data in your model that may be changing frequently and that you don't want to query against. However, it does seem to lack full functionality for easily defining new coders and being able to treat your new class more like it is embedded in your model class.



    
