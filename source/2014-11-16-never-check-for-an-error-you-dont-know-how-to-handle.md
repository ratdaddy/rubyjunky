---
title: Never Check for an Error You Don't Know How to Handle
date: 2014-11-16
tags: Rails, Exception Handling
---

I used to work with a curmudgeon developer who was known to say "never check for an error you don't know how to handle". Since this was back in my C programming days it was meant as a joke (I hope). At that time we didn't have exceptions. Any library or system call you made could return a myriad of errors, not all of which were obvious or expected. Yet you still had to think about all the possible error eventualities if you ever hoped to have a robust application.

Recently I've worked on a couple of Rails applications where previous developers sprinkled their code (mostly controllers) with lots of generic rescue statements. It turns out this didn't make these applications more robust. Instead, the exception handling masked real problems in production.

Given that any good framework we use today has some sort of reasonable default exception handler,  we shouldn't be trying to rescue unexpected exceptions. Without getting into whether certain framework methods should raise an exception or not we'll examine the problems presented by overly aggressive error handling and see why given our current languages, frameworks, and monitoring tools it probably is correct to "never check for an error we don't know how to handle"

READMORE

## Wrap the Whole Action

On one of the applications I was working on many of  its API controller actions were completely wrapped with a generic rescue statement. Generally the rescue action would return some sort of 4xx error with a message indicating it was presented with invalid parameters.

At first glance this seemed to be a very aggressive use of exception handling since only a portion of the action method dealt with the parameters provided by the client. However, if you were to go back and consider the evolution of the application you could see how this might have come about. Perhaps in the application's infancy when only the associated model record was being searched for, the first time an invalid id for that model was passed in the application returned a bunch of HTML to render a nice 404 page. Remember, this is an API call so the client was probably expecting JSON.

The original developer probably started with code like this:

```ruby
class UsersController < ApplicationController
  def show
	user = User.find(params[:id])
	render json: user
  end
end
```

We can assume the client developer complained about the HTML 404 status response they got back and the original developer went back and found that the `User.find` was raising an exception:

```
FATAL -- : 
ActiveRecord::RecordNotFound (Couldn't find User with 'id'=1010):
  app/controllers/users_controller.rb:3:in `show'
```

At this point the developer probably wrapped the method in a rescue statement, trying to eliminate the HTML output:

```ruby
class UsersController < ApplicationController
  def show
    user = User.find(params[:id])
    render json: user
  rescue => e
    logger.info e
    render json: { message: 'user id not found' }, status: :not_found
  end
end
```

So now everything is happy. A 404 status is returned along with an appropriate JSON error message explaining the problem. Since this fixed this method, perhaps the developer even decided to wrap the other API action methods the same way so all their `find` methods would no longer return  HTML pages (there are, of course, other ways to handle exceptions across all controller/actions which we'll look at in a little bit).

The obvious problem here is that we will be rescuing more than the errors from the `.find` method. But that may appear OK. In this action the only other thing we're doing is a render statement and that would never raise an exception. Or would it?

Let's say that some time later the API client developers are looking at things and they see that more data is being returned in the `user` JSON than they want. And there's a name field in there that they want to receive as all caps (OK, this may seem a bit contrived but not totally outside the realm of some of the requests I've seen). No problem we say, we'll just override the `User` model's `as_json` serializer. This should do it:

```ruby
class User < ActiveRecord::Base
  def as_json options
    { id: id, username: name.upcase }
  end
end
```

We do some testing on some valid `User` model entries and note that everything appears to be working fine. We go ahead and deploy to production and now the client users start to complain that they're seeing 'user id not found' messages for user show actions that used to work fine. What happened?

For the sake of this example we'll assume that the `User` model doesn't actually have validations on it (again, not completely uncommon for some of the projects I've joined). This means that the `name` attribute of the model could have been saved with an empty value and when our `as_json` method tries to run `upcase` on a nil `name` attribute we get the dreaded nil pointer exception. Fortunately a quick read of our logs tells us some of this:

```
INFO -- : undefined method `upcase' for nil:NilClass
INFO -- : Completed 404 Not Found in 54ms (Views: 0.9ms | ActiveRecord: 4.7ms)
```

There's a couple of unfortunate things here. First, even though we log the exception's message, we have provided no context like a stack trace. After all, we didn't really think we were reporting an anomalous condition. For similar reasons we logged the problem at the `INFO` level so it doesn't really stand out, nor would it likely be reported on by log monitoring tools.

Of course, the most unfortunate thing is that we're reporting an error back through our API when it really isn't an error condition. This happened because we put in an overzealous exception handler in our `show` action method.

## What Should We Do Instead?

Ideally we should only rescue exceptions that we expect to occur or those that we need to perform some sort of recovery on. Everything else we should let fall through to the framework or to our own error notification code. If you don't have a service set up to notify you of application errors you should use one. [Honeybadger](https://www.honeybadger.io/) and [Airbrake](https://airbrake.io/) are two good hosted options.

When using services like these it's important to stay on top of the errors that are reported so that it's easier to see when new problems arise. If you don't resolve problems as they come up you're likely to fall into the trap where your team ignores the messages because there are too many false positives.

My experience has shown that using services like these on applications turns up errors very quickly, whether they come from a new deployment with a bug in it, rogue client applications, or bad data being introduced into your system.

## How to Handle Exceptions

There are some code structure issues around rescuing only those exceptions that are expected to occur. Generally it is best to localize the exception and handling to the method you expect to raise exceptions. To do this our earlier code example might become:

```ruby
class UsersController < ApplicationController
  def show
    begin
      user = User.find(params[:id])
    rescue => e
      logger.info e
      return render json: { message: 'user id not found' }, status: :not_found
    end
    render json: user
  end
end
```

This style has the disadvantage of interrupting our code flow. Another way that keeps the same relative code flow is to rescue specific exceptions that only the methods we are concerned about can raise:

```ruby
class UsersController < ApplicationController
  def show
    user = User.find(params[:id])
    render json: user
  rescue ActiveRecord::RecordNotFound => e
    logger.info e
    return render json: { message: 'user id not found' }, status: :not_found
  end
end
```

The disadvantage of this style is the possibility that some day code gets added that causes the `ActiveRecord::RecordNotFound` exception to be raised that is not part of the `User.find` call. Then our API call will return a possibly incorrect "user id not found" message.

## How do You Insure Your API Always Returns a JSON Response?

If you must insure that your API always returns a JSON response then you'll need to rescue all exceptions for your API's controller actions. While you could add code to each action method it is easier to use Rails' [ActiveSupport::Rescuable::ClassMethods#rescue_from](http://api.rubyonrails.org/classes/ActiveSupport/Rescuable/ClassMethods.html#method-i-rescue_from).

It's important to remember that once you take over error handling you no longer get the services the framework provides for you. Specifically, a default renderer and any kind of logging. You'll also lose add-on facilities like error notifications from Honeybadger or Airbrake.

A default error handler that insures you always reply with JSON might look like:

```ruby
class ApplicationController < ActionController::Base
  rescue_from StandardError do |exception|
    # Add your own call to your exception notification system here.

    message = "\n#{exception.class} (#{exception.message}):\n"
    message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
    message << "  " << ActionDispatch::ExceptionWrapper.new(env, exception).application_trace.join("\n  ")
    logger.error("#{message}\n\n")

    render json: { message: 'Internal server error' }, status: :internal_server_error
  end
end
```

This example exposes another one of Rails' dirty secrets surrounding logging: there is no packaged method available to replicate the default exception logging. The code shown here replicates the default logging you get for standard request processing with abbreviated stack traces that only log the lines of code from your application.

A quick scan of the Rails source code finds these logging lines replicated in at least three separate places. Another issue I have with Rails logging is that the severity level is done at fatal which to me would indicate problems that would take down your application server. An exception in the handling of a single request allows your server to continue running and feels far from fatal. I cover these and several other logging problems in [Cleaning Up Rails 4 Production Logging](/cleaning-up-rails-4-production-logging.html).

## Takeaway

Unfortunately the Rails framework's use of exceptions can make it difficult for our applications to return the meaningful error messages we'd like them to. This causes us to add our own exception handling to our applications. When we do that, we should do it carefully and insure our code is only handling those errors it expects. You should let the rest fall through to a mechanism that is better equipped to cause your team to do the right thing, with the default being to notify someone so they can fix latent bugs or put guardrails as appropriate around your application.
