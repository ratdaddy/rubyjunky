---
title: Cleaning Up Rails 4 Production Logging
date: 2013-07-30
tags: Rails, Logging
published: false
---

I've seen some very effective use of application logging to debug difficult problems. Of course, one of the keys is to
make sure that your application is logging the right things. Almost as imporant as having the right information is for your log files to be easy to parse - both for a human reading the file and for any scripts that might be written to extract information from them.

While Rails' conventions allow you to easily write powerful web applications the default logging available comes up somewhat short. This is somewhat to be expected since Rails itself is just a framework and thus the logging available out of the box is really only about the framework itself. If you don't modify the default logging the first time you have a problem in production and go to look at your log files you may be surprised.

Most of the problems with Rails logging have to do with duplicated or superflous information. On top of that entries
aren't formated in such a way that you can easily scan a log file to see problems or patterns in the data.

READMORE

In this article I'll describe how to start taming your production logs to make them useful and ready to scale along
with your application. I'm assuming a relatively simple Rails application at the beginning of it's lifecycle
that runs as a single instance. The application might have a handful of standard RESTful resources with their
initial generated routing.

## Invalid URLs

If you take a look at a default production log for an application deployed to the wild one of the first things you'll notice is a lot of routing errors:

```
I, [2013-07-31T21:19:34.184251 #14323]  INFO -- : Started GET "/azenv.php" for 127.0.0.1 at 2013-07-31 21:19:34 -0700
F, [2013-07-31T21:19:34.384787 #14323] FATAL -- :
ActionController::RoutingError (No route matches [GET] "/azenv.php"):
  actionpack (4.0.0) lib/action_dispatch/middleware/debug_exceptions.rb:21:in `call'
  actionpack (4.0.0) lib/action_dispatch/middleware/show_exceptions.rb:30:in `call'
  railties (4.0.0) lib/rails/rack/logger.rb:38:in `call_app'
... plus 17 more lines
```

These errors represent lame attempts by hackers to exploit various known vulnerabilities in other application. They're harmless to your Rails application as long as you pay attention to a [few rules](http://blog.codeclimate.com/blog/2013/03/27/rails-insecure-defaults). It also feels a bit severe to label these errors as fatal since most logging conventions consider fatal errors as unrecoverable yet for errors like these your server will continue happily working and processing future requests.

The solution to this is to add a catch-all route to eliminate any potential routing errors. This has an additional benefit of allowing you to put your own information on a 404 error page and ways to direct users to somewhere useful (like maybe a search of your site). You can also get rid of the stock Rails error page which is thankfully looking better in Rails 4.

Add this line to the end of your `config/routes.rb` file:

```ruby
match '*path', via: :all, to: 'pages#error_404'
```

It's important that this be the last rule in your routes file as it will route all paths not already defined and
anything after this rule will be ignored. This is accomplished with the globbed match `*path` which says match everything. The 
`via: :all` option is needed to match any http action because in Rails 4 as you are no longer allowed to use a
 generic `match` but instead encouraged 
to use matches for specific http actions (like get, post, and put). Finally, you'll need to add a `PagesController`
with an `error_404` method and view to render your own 404 page.

(Also should mention that this makes an argument to make sure your acceptance/integration/system tests are thorough
enough to catch real routing programming errors).

Now when the would-be hackers start sending bogus URLs at your service you will see logs like this:

```
I, [2013-07-31T22:03:36.748347 #14677]  INFO -- : Started GET "/azenv.php" for 127.0.0.1 at 2013-07-31 22:03:36 -0700
I, [2013-07-31T22:03:36.922370 #14677]  INFO -- : Processing by PagesController#error_404 as
I, [2013-07-31T22:03:36.922650 #14677]  INFO -- :   Parameters: {"path"=>"azenv"}
I, [2013-07-31T22:03:36.961711 #14677]  INFO -- :   Rendered pages/error_404.html.erb within layouts/application (0.7ms)
I, [2013-07-31T22:03:36.976078 #14677]  INFO -- : Completed 404 Not Found in 53ms (Views: 22.4ms | ActiveRecord: 0.0ms)
```

## Single request logging

(relate back to aspects of logging that will help with debugging - discuss motivation to capture important information and do so on perhaps a single line).

Our new routing error logging basically matches the logging that we'll see on most requests. Looking at the five lines above there are quite a few problems that are immediately apparent:

1. The "I" at the beginning of the line indicates that this is an `info` level log. The word `INFO` appears later in each line resulting in unnecessary duplication.
2. The number inside of the brackets represents the process id of the Rails server. Assuming that it's a small
application there may only be one Rails process making this unnecessary duplication. Also, it's unlikely that for
most debugging tasks that the process id will be of any use.
3. In the line that starts a request the date/time is repeated.
4. The second and fourth lines are statements about what happens internally in the application. For most routes
the controller/action and files used for rendering are well-defined and repeating this information in the log doesn't
serve much purpose and gets in the way of other important information.
5. I don't often find execution times like those in the fourth and fifth lines to be useful for general debugging.
If there are performance problems you'll probably need to roll out heavier tools like metrics collection.
6. Finally, when you have five lines of output for each request and all that information is smashed together in
a single log it makes it difficult to visually scan the log file to see problems. It's also more difficult to build
scripts to associate data and use it in other ways (such as metrics reporting).

Here are the things that we want to keep in our log:

1. Log level. The single initial is a good choice since it doesn't take up much real estate and makes it easy
to keep columns aligned.
2. Date/time.
3. HTTP method (GET, POST, etc.).
4. Status code
4. IP address
4. URL path
5. Parameters 
6. Location (for redirect requests).

Rails' logging is done through `Rails.logger` and so it isn't too much problem to add your own logging to your
application. The downside is that Rails doesn't provide convenient hooks to control the default logging which
also originates from different parts of the framework. Because of this the first thing we'll do to tame our
request logging is to shut down the default logging by directing it to `/dev/null` by adding this to
`config/environments/production.rb`:

```
config.logger = Logger.new('/dev/null')
```

### Basic request logging

Now that we've shut off all the default logging we need to replace it with our own.
[`ActiveSupport::Notifications`](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) is
used to issue an event at various points in the framework. For logging, Rails creates subclasses of the [`ActiveSupport::LogSubscriber`](http://api.rubyonrails.org/classes/ActiveSupport/LogSubscriber.html) for it's various frameworks. A
search on the API documentation shows there are four different `LogSubscribers`:

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
We'll put the following code in `app/lib/clean_logging.rb`:

```ruby
module CleanLogging
  class LogSubscriber < ActiveSupport::LogSubscriber
    def process_action event
      pp event.payload
    end
  end
end

CleanLogging::LogSubscriber.attach_to :action_controller
```

Running our server with `rails server -e production` and navigating to a page gives us the following output:

```ruby
{:controller=>"PostsController",
 :action=>"index",
 :params=>{"action"=>"index", "controller"=>"posts"},
 :format=>:html,
 :method=>"GET",
 :path=>"/posts",
 :status=>200,
 :view_runtime=>8.374248,
 :db_runtime=>0.267353}
```

This provides all of the information we set out to log except for the log level (we'll be setting our own anyway),
the date/time, and the IP address. We'll see a bit later how to get all these pieces into our log message but first
we need to have a way to get all of this into our log file.

### Setting up our logger

As you'll remember earlier we shut off the default Rails logger to suppress the default logging messages we no longer
need. The `ActiveRecord::LogSubscriber` class provides a `logger` method but unfortunately it's the same as the
Rails logger that we shut off. To keep things consistent we'll need to create our own logger and point it to the file
we want our logging to go to. We can add this to our `CleanLogging::LogSubscriber` class and while we're at it set up a
`Formatter` for our logger.

```ruby
require 'active_support/buffered_logger'

module CleanLogging
  class LogSubscriber < ActiveSupport::LogSubscriber
    def logger
      @logger ||= create_logger
    end

    def create_logger
      f = File.open('log/production.log', 'a')
      f.sync = true
      logger = ActiveSupport::BufferedLogger.new(f)
      logger.formatter = Formatter.new
      logger
    end

    class Formatter
      def call severity, time, progname, msg
        "#{severity[0]} #{time.strftime('%FT%T.%6N')} #{msg}\n"
      end
    end
    ...

  end
end
```

Some things to note with this implementation:

* The `logger` method memoizes an instance variable so that opening the logfile and configuring it is only done once.
This also could have been done in some kind of initializer if we were developing a more general-purpose solution.
* We open the same `log/production.log` file that the default logger was using and of course it's opened to append
to any existing file. We also set file sync on so that write buffers are synced for each entry. This way any other
programs that try to read from the file (like `tail -f`) will immediately see the information in the file.
* We set up a `Formatter`. This is where the severity and time are added to the log entry. Later when we format
the rest of the entry it will be passed in as `msg`.

To round out the logging we can do with the information currently available we can format the `payload` in our
`process_action` method:

```ruby
module CleanLogging
  class LogSubscriber < ActiveSupport::LogSubscriber
    ...

    def process_action event
      payload = event.payload
      method = payload[:method]
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
```

Note here that we're removing certain parameters that can be inferred from the requests path, again to keep the
clutter out of our log file. Also we format the http method
to a fixed width so that the remaining information will line up in columns and we preface the parameters with
`parameters=` which makes it easier to parse log lines where optional data is involved.

The logic in the `compute_status` method is necessary because we aren't given a status in the event payload if
an exception has occurred during the processing of the request. Rails doesn't provide a handy way to get just
the status and so we have to compute it again here with code borrowed directly from `ActionController::LogSubscriber`.

Our log now looks like:

```
I 2013-08-01T22:56:22.548527 GET    200 /posts
I 2013-08-01T22:56:24.523393 GET    200 /posts/1 parameters={"id"=>"1"}
I 2013-08-01T22:56:27.101631 GET    200 /posts/1/edit parameters={"id"=>"1"}
I 2013-08-01T22:56:38.375335 POST   302 /posts/1 parameters={"utf8"=>"✓"...
```

### Getting the IP address for our log

Looking back at our list of things we wanted to keep in our logs we see that we only have two things left to get, the
IP address and the location a redirect is sent to. Both of these are a bit tricky as they aren't part of this payload
for the event we're currently using. The IP address is the tougher of the two as it comes from a notification
triggered by the rack middleware. We could register for that notification too and store the IP address for later
logging but to demonstrate a different technique we'll actually register our own middleware to pick off the IP address:

```ruby
module CleanLogging
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

An important thing to note here is that we need some place to stash our ip address since this middleware code is
running before our logging is done. We need to make sure we store it somewhere where we know it will be associated
with the logging for the same request so we use the
[fiber-local variable storage mechanism](http://www.ruby-doc.org/core-2.0/Thread.html#method-i-5B-5D) of the current thread
[`Thread.current`](http://www.ruby-doc.org/core-2.0/Thread.html#method-c-current) data rather than a global variable which may
get overwritten if multiple requests can be processed concurrently which depends on which web application you are using.
You can read more about how this middlware works in this [RailsGuide](http://guides.rubyonrails.org/rails_on_rack.html).

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
  config.middleware.use CleanLogging::LogMiddleware
  ...

end
```

Now our logging looks like:

```
I 2013-08-03T14:04:23.024267 GET    200 127.0.0.1       /posts
I 2013-08-03T14:04:25.178910 GET    200 127.0.0.1       /posts/1 parameters={"id"=>"1"}
I 2013-08-03T14:04:27.985404 GET    200 127.0.0.1       /posts/1/edit parameters={"id"=>"1"}
I 2013-08-03T14:04:30.217523 POST   302 127.0.0.1       /posts/1 parameters={"utf8"=>"✓", ...
```

### Adding redirect location

The final piece of information we set out to add to our log is the location for a request that has a redirect
response. Since this is an optional piece of information and not in all log entries we'll add it much like we
did the parameters, introducing it's information with `location=`. Like the IP address, the location is not
available to our `process_action` method but instead it comes from another event from the `ActionController`,
`redirect_to`. We'll use the same thread storage mechanism that we did for the IP address to save the location:

```ruby

## Wrapping it up

- Plenty more information to add back - like stack traces for real errors
