---
title: Cleaning Up Rails 4 Production Logging
date: 2013-07-30
tags: Rails, Logging
---

I've seen some very effective use of application logging to debug difficult problems. The foundation of good logging
is being sure that your application is logging the right things. However, it's just as important
for your log files to be easy to parse - both for a human reading the file and for any scripts that might be written
to extract information from them.

While Rails' conventions allow you to easily write powerful web applications the default logging available comes up
short on both capturing critical information and providing it in a consumable fashion.
This can be expected since Rails itself is just a framework and thus the logging available
out of the box is really only about the framework itself. Left unmodified, the default logging can be a bit
surprising the first time you go to look at a production problem.

I'll be describing how to start taming your production logs to make them useful and ready to scale along with you
application. I'll show you how to turn several lines of rambling output per request into one concise line with
the essential information that needed to debugging production problems. This will be the basis for
adding logging specific to your business logic and future debugging requirements.


READMORE

In this article I'm assuming a relatively simple Rails application at the beginning of its lifecycle
that runs as a single instance. The application might have a handful of standard RESTful resources with their
initial generated routing.

Many of the ideas here have been borrowed from the [lograge](https://github.com/roidrage/lograge) gem which does
a good job at cleaning things up but isn't as extensible as creating your own logging.

## Invalid URLs

One of the first thing you're likely to notice in your default production logs for applications deployed to the
wild is a lot of routing errors:

```
I, [2013-08-08T20:30:17.677248 #14985]  INFO -- : Started GET "/manager/html" for 220.165.88.21 at 2013-08-08 20:30:17 -0700
F, [2013-08-08T20:30:17.688957 #14985] FATAL -- : 
ActionController::RoutingError (No route matches [GET] "/manager/html"):
  actionpack (4.0.0) lib/action_dispatch/middleware/debug_exceptions.rb:21:in `call'
  actionpack (4.0.0) lib/action_dispatch/middleware/show_exceptions.rb:30:in `call'
  railties (4.0.0) lib/rails/rack/logger.rb:38:in `call_app'
... plus 17 more lines
```

These errors represent lame attempts by hackers to exploit various known vulnerabilities in other applications.
They're generally harmless to your Rails application as long as you pay attention to a
[few security rules](http://blog.codeclimate.com/blog/2013/03/27/rails-insecure-defaults).

From a best-practices standpoint, I feel it is a bit severe to
classify these errors as fatal since most logging conventions consider fatal errors as catastrophic and
generally unrecoverable. For these routing errors
your server will continue happily working, send out a 404 response and go on to process future requests.

Even if you don't go on to implement any more sophisticated logging schemes like are outlined in the remainder of
this article, it is probably a good idea to solve this problem by adding a catch-all route to eliminate
routing errors. This has the
additional benefit of allowing you to put your own information on a 404 error page and provide ways to direct users
to somewhere useful, like maybe a search of your site. You also get rid of the stock Rails error page
which is thankfully looking better in Rails 4.

To create the catch-all route, add this line to the end of your `config/routes.rb` file:

```ruby
match '*path', via: :all, to: 'pages#error_404'
```

It's important that this be the last rule in your routes file as it will route all requests that aren't matched by
a previously defined route and 
anything you put after this rule will be ignored. The globbed match `*path` says match everything, and the 
`via: :all` option is needed to match all http actions because in Rails 4 you are no longer allowed to use a
generic `match` rule. Instead you are encouraged 
to use matches for specific http actions (like get, post, and put). You'll also need to add a `PagesController`
with an `error_404` method and view to render your own 404 page:

```ruby
class PagesController < ApplicationController
  def error_404
    render status: 404
  end
end
```

Now when the would-be hackers start sending bogus URLs to your service you will see logs like this:

```
I, [2013-08-08T20:30:25.090069 #15002]  INFO -- : Started GET "/manager/html" for 220.165.88.21 at 2013-08-08 20:30:25 -0700
I, [2013-08-08T20:30:25.109424 #15002]  INFO -- : Processing by PagesController#error_404 as */*
I, [2013-08-08T20:30:25.109579 #15002]  INFO -- :   Parameters: {"path"=>"manager/html"}
I, [2013-08-08T20:30:25.146743 #15002]  INFO -- :   Rendered pages/error_404.html.erb within layouts/application (1.9ms)
I, [2013-08-08T20:30:25.149406 #15002]  INFO -- : Completed 200 OK in 40ms (Views: 7.3ms | ActiveRecord: 0.0ms)
```

To avoid bugs in your routing scheme you will want to make sure that your acceptance/integration/system tests are
thorough enough to catch real errors. There may come a day when you have a bug in your routing you need to track
down but having the stack trace of what you routed to is highly unlikely to shed much light on the real problem
which probably occurred when you generated the errant URL in the first place.

## Single request logging

Our next goal is to turn the information logged for a single request into something that is parsable by both humans
and computers. For the most part the information you get in a Rails log is centered on a request and what
the framework knows about that request at various points in time. Rather than log all information about a particular
request on multiple lines it will be much easier for later processing if we have a one line format. For the humans
it works best to keep things lined up neatly in columns so that they can be quickly scanned for anomalous entries.

The five lines in the above example for a single 404 error are fairly typical of what you'll see for all
requests in a production log. There are a number of problems that are immediately apparent:

1. The "I" at the beginning of the line indicates that this is an `info` level log. The word `INFO` appears later
in each line resulting in unnecessary duplication.
2. The number inside the brackets represents the process id of the Rails server. Assuming that it's a small
application there may only be one Rails process, thus, making this unnecessary duplication. Since we'll be logging a
single request per line there won't be a need to try and sort things out and even if you do need to correlate a
request's data across several lines of logging you'll probably want something more unique to the request than the id of the process of a server.
3. In the first line that starts a request the date/time is repeated.
4. The second and fourth lines are statements about what happens internally in the application. For most routes
the controller/action and files used for rendering are well-defined and repeating this information in the log doesn't
serve much purpose. Ultimately it gets in the way of other important information.
5. I don't often find execution times like those in the fourth and fifth lines to be useful for general debugging.
If there are performance problems you'll probably need to roll out heavier tools like metrics collection anyway.
6. Finally, when you have five lines of output for each request
it makes it difficult to visually scan the log file to see problems. It's also more difficult to build
scripts to associate data from a single request and use it in other ways (such as metrics reporting).

Here are the things that we want to keep in our log:

1. Log level. The single letter is a good choice since it doesn't take up much real estate and makes it easy
to keep columns aligned.
2. Date/time, in this case we'll be using a consistent format like the [ISO 8601 standard](http://en.wikipedia.org/wiki/ISO_8601)
including time zone information. Since it is
possible that a service may end up running in different timezones it is a good idea to log in UTC so that you can
coordinate logs from different servers.
3. HTTP method (GET, POST, etc.).
4. Response status code
4. Request origin IP address
4. URL path
5. Request parameters
6. Response location (for redirect requests).

Rails' logging is done through `Rails.logger` and it is easy to add your own logging to your
application. The downside is that Rails doesn't provide convenient hooks to control the default logging
originating from the different parts of the framework. To keep our logging clean we'll be creating our own log file
and so won't be using the default `log/production.log` file. Since our logging solution captures most of the same
information as the default loggers you may want to turn off default logging entirely which you can do
by directing it to `/dev/null` by adding this to
`config/environments/production.rb`:

```
config.logger = Logger.new('/dev/null')
```

### Basic request logging

Rails provides a notification mechanism which is used to provide information to its loggers.
[`ActiveSupport::Notifications`](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) is
used to issue events at various points in time as the framework processes requests.
Rails creates subclasses of the
[`ActiveSupport::LogSubscriber`](http://api.rubyonrails.org/classes/ActiveSupport/LogSubscriber.html) for
different parts of its framework.
A search on the API documentation shows there are four different `LogSubscribers`:

* [`ActionController::LogSubscriber`](http://api.rubyonrails.org/classes/ActionController/LogSubscriber.html)
* [`ActionMailer::LogSubscriber`](http://api.rubyonrails.org/classes/ActionMailer/LogSubscriber.html)
* [`ActionView::LogSubscriber`](http://api.rubyonrails.org/classes/ActionView/LogSubscriber.html)
* [`ActiveRecord::LogSubscriber`](http://api.rubyonrails.org/classes/ActiveRecord/LogSubscriber.html)

The documentation for each of these classes enumerates most of the events available but you might find it necessary
to read the source code of the class to figure out both the information available to the event and possibly some other
undocumented events that may be issued.

As it turns out, almost all of the information we want
to log comes from a single event: the `process_action` event from the `ActionController`. So we'll create our own
`LogSubscriber` and look at the information in `event.payload` which is where all the interesting pieces are.
To figure out the data available we'll create our `LogSubscriber` class and attach it to the `ActionController`
with this code which we'll put in `app/lib/request_summary_logging.rb`:

```ruby
module RequestSummaryLogging
  class LogSubscriber < ActiveSupport::LogSubscriber
    def process_action event
      pp event.payload
    end
  end
end

RequestSummaryLogging::LogSubscriber.attach_to :action_controller
```

Running our server with `rails server -e production` and navigating to a page (a resource update makes a good example)
gives us the following output:

```ruby
{:controller=>"PostsController",
 :action=>"update",
 :params=>
  {"utf8"=>"✓",
   "_method"=>"patch",
   "authenticity_token"=>"QlEN1XvD/5Ny57GhC8WT6r9o0tP//QAa2gARm2Umqlw=",
   "post"=>{"title"=>"Rails Logging", "body"=>"Could be improved."},
   "commit"=>"Update Post",
   "action"=>"update",
   "controller"=>"posts",
   "id"=>"1"},
 :format=>:html,
 :method=>"POST",
 :path=>"/posts/1",
 :status=>302,
 :view_runtime=>nil,
 :db_runtime=>71.38505}
```

We can now see that this event provides all of the information we set out to log except for the log level
(we'll be setting our own anyway),
the date/time, IP address, and redirect location. We'll see a bit later how to get all these pieces into our log message but first
we need to have a way to get all of this into our log file.

### Setting up our logger

The `ActiveRecord::LogSubscriber` class provides a `logger` method but unfortunately it's the same as the default
Rails logger and we don't want our logging information in that same stream. We'll
need to create our own logger and point it to the file
we want our logging to go to. We can add this to our `RequestSummaryLogging::LogSubscriber` class and while we're
at it set up a `Formatter` for our logger.

```ruby
require 'active_support/buffered_logger'

module RequestSummaryLogging
  class LogSubscriber < ActiveSupport::LogSubscriber
    def logger
      @logger ||= create_logger
    end

    def create_logger
      logger = ActiveSupport::BufferedLogger.new(File.expand_path('../../../log/request_summary.log', __FILE__))
      logger.formatter = Formatter.new
      logger
    end

    class Formatter
      def call severity, time, progname, msg
        "#{severity[0]} #{time.utc.strftime('%FT%T.%6NZ')} #{msg}\n"
      end
    end
    ...

  end
end
```

Some things to note in this implementation:

* The `logger` method memoizes an instance variable so that opening the logfile and configuring it is only done once.
This also could have been done in some kind of initializer if we were developing a more general-purpose solution.
* We let the `BufferedLogger.new` method open our log file and put it in `log/request_summary.log`. It is a good
idea to do this as an absolute path since sometimes Rails doesn't run in the correct directory to be able to use
a relative path. `BufferedLogger.new` also sets the correct file attributes for things like automatically flushing buffers.
* We set up a `Formatter`. This is where the severity and time are added to the log entry. Later when we format
the rest of the entry it will be passed in as `msg` to the formatter.

We can now format the `payload` in our `process_action` method:

```ruby
module RequestSummaryLogging
  class LogSubscriber < ActiveSupport::LogSubscriber
    ...

    INTERNAL_PARAMS = %w(controller action format _method only_path)

    def process_action event
      payload = event.payload
      param_method = payload[:params]['_method']
      method = param_method ? param_method.upcase : payload[:method]
      status = compute_status(payload)
      path = payload[:path]
      params = payload[:params].except(*INTERNAL_PARAMS)

      message = "%-6s #{status} #{path}" % method
      message << " parameters=#{params}" unless params.empty?

      logger.info message
    end

    def compute_status payload
      status = payload[:status]
      if status.nil? && payload[:exception].present?
        exception_class_name = payload[:exception].first
        status = ActionDispatch::ExceptionWrapper.status_code_for_exception(exception_class_name)
      end
      status
    end
  end
end
```

Note here that we're removing certain parameters that could be inferred from the requests path, again to keep the
clutter out of our log file. Also we format the http method
to a fixed width so that the remaining information will line up in columns and we preface the parameters with
`parameters=` which makes it easier to parse log lines where optional data is involved (not all requests will have
parameters).

The logic in the `compute_status` method is necessary because we aren't given a status in the event payload if
an exception has occurred during the processing of the request. Rails doesn't provide a handy way to get
the status in and we have to compute it ourselves with code borrowed directly from
`ActionController::LogSubscriber`.

Our log now looks like:

```
I 2013-08-09T03:30:33.234173Z GET    200 /posts
I 2013-08-09T03:30:33.297396Z GET    200 /posts/new
I 2013-08-09T03:30:33.441780Z POST   302 /posts parameters={"utf8"=>"✓", "post"=>{"title"=>"Rails ...
I 2013-08-09T03:30:33.510095Z GET    200 /posts/1 parameters={"id"=>"1"}
I 2013-08-09T03:30:33.589517Z GET    200 /posts/1/edit parameters={"id"=>"1"}
I 2013-08-09T03:30:33.655532Z PATCH  302 /posts/1 parameters={"utf8"=>"✓", "post"=>{"title"=>"Rai ...
```

### Getting the IP address for our log

Looking back at our list of things we wanted to keep in our logs we see that we only have two things left to get, the
IP address and the location a redirect is sent to. Both of these are a bit tricky as they aren't part of the payload
for the event we're using. The IP address is the tougher of the two as it comes from a notification
triggered by the rack middleware. We could register for that notification too and store the IP address for later
logging but to demonstrate a different technique we'll actually register our own middleware to pick off the IP address:

```ruby
module RequestSummaryLogging
  class LogMiddleware
    def initialize app
      @app = app
    end

    def call env
      request = ActionDispatch::Request.new(env)
      Thread.current[:logged_ip] = request.ip
      @app.call(env)
    ensure
      Thread.current[:logged_ip] = nil
    end
  end
  ...

end
```

An important thing to note here is that we need some place to stash our IP address since our middleware code
runs before our chosen logging event. We need to make sure to store it somewhere that will be associated
with the later logging for the same request so we use the
[fiber-local variable storage mechanism](http://www.ruby-doc.org/core-2.0/Thread.html#method-i-5B-5D) of the current thread:
[`Thread.current`](http://www.ruby-doc.org/core-2.0/Thread.html#method-c-current). We use this rather than a global
variable which may
get overwritten if multiple requests can be processed concurrently which depends on the web application server you use.
You can read more about how this middleware works in this [RailsGuide](http://guides.rubyonrails.org/rails_on_rack.html).

To add the IP address to our one-line logger we need to add a line to retrieve the IP address from the current thread
and replace the message formatter in our `process_action` method, again padding the IP address to its maximum
potential width to keep everything nicely aligned:

```ruby
def process_action event

  ...
  ip = Thread.current[:logged_ip]

  message = "%-6s #{status} %-15s #{path}" % [method, ip]
  ...

end
```

Finally, we need to install our middleware by adding this to `config/environments/production.rb`:

```ruby
App::Application.configure do
  config.middleware.use RequestSummaryLogging::LogMiddleware
  ...

end
```

Now our logging looks like:

```
I 2013-08-09T03:30:38.270914Z GET    200 205.251.242.244 /posts
I 2013-08-09T03:30:38.311104Z GET    200 205.251.242.244 /posts/new
I 2013-08-09T03:30:38.472275Z POST   302 205.251.242.244 /posts parameters={"utf8"=>"✓", "post"=> ...
I 2013-08-09T03:30:38.553411Z GET    200 205.251.242.244 /posts/1 parameters={"id"=>"1"}
I 2013-08-09T03:30:38.631428Z GET    200 205.251.242.244 /posts/1/edit parameters={"id"=>"1"}
I 2013-08-09T03:30:38.730665Z PATCH  302 205.251.242.244 /posts/1 parameters={"utf8"=>"✓", "post" ...
```

### Adding redirect location

The final piece of information we set out to add to our log is the location for a request that has a redirect
response. Since this is an optional piece of information and not in all log entries we'll add it much like we
did the parameters, introducing it with `redirect_to=`. Like the IP address, the location is not
available to our `process_action` method but instead comes from another event from the `ActionController`,
`redirect_to`. We'll use the same thread storage mechanism that we did for the IP address to save the location.
Here's our new `redirect_to` event handler along with our completed logging in `process_action`

```ruby
module RequestSummaryLogging
  class LogSubscriber < ActiveSupport::LogSubscriber

    ...
    def redirect_to event
      Thread.current[:logged_location] = event.payload[:location]
    end

    INTERNAL_PARAMS = %w(controller action format _method only_path)

    def process_action event
      payload = event.payload
      param_method = payload[:params]['_method']
      method = param_method ? param_method.upcase : payload[:method]
      status = compute_status(payload)
      path = payload[:path]
      params = payload[:params].except(*INTERNAL_PARAMS)

      ip = Thread.current[:logged_ip]
      location = Thread.current[:logged_location]
      Thread.current[:logged_location] = nil

      message = "%-6s #{status} %-15s #{path}" % [method, ip]
      message << " redirect_to=#{location}" if location
      message << " parameters=#{params}" unless params.empty?

      logger.info message
    end
    ...

  end
end
```

Now our logging for a redirect looks like:

```
I 2013-08-09T03:30:43.445226Z POST   302 205.251.242.244 /posts redirect_to=http://rubyjunky.com/posts/3 parameters={"utf8"=>"✓ ...
``` 

## Wrapping it up

We now have a logger that collects critical information about each request we get and presents it on an easily read
single line. There are other critical things that still need to be added like logging for real application exceptions
which would indicate some sort of problem. Also, as your application grows in complexity there are additional events
that can be issued and additional information from them that you'll want logged. Finally, you'll want to start logging
information meaningful to your application domain, like each time a new user is created.
