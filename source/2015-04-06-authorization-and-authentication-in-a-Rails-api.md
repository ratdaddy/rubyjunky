---
title: Authorization and Authentication in a Rails API
date: 2015-04-06
tags: Rails, API
---

When creating an API in Rails
your authentication (and to some extent authorization) techniques
will vary somewhat based on your API's purpose.

This article is [part of a series](/2015-03-22-creating-apis-using-rails.html)
on writing APIs in Rails.
You can refer back to the original article
for a list of the different types of APIs,
links to other articles in the series,
and background information.

READMORE

## Some Definitions

The terms authentication and authorization
sometimes get mixed up when discussing application access control.
It's important to think about them
as separate concerns when writing your application
so here are some short definitions:

<dl>
  <dt>Authentication</dt>
  <dd>Verification of the identity of the program or user making a request. Often uses something like a unique username and a password associated with that username.</dd>
  
  <dt>Authorization</dt>
  <dd>Once identity has been verified, allows/prevents programs or users from accessing certain part of the system or data stored in the system.</dd>
</dl>

## Web-Based Single Page Applications (SPA)

If your API is for a SPA
it's easiest to use [Rails sessions](http://guides.rubyonrails.org/action_controller_overview.html#session)
to keep track of a user
after they have authenticated.
You won't need any extra authentication/authorization provisions beyond what
you would normally have
for a page-oriented application.

Because everything is standard Rails
it is easiest to use one of the popular authentication gems.
[Devise](https://github.com/plataformatec/devise) or [Clearance](https://github.com/thoughtbot/clearance)
authenticate a user with their username or email and a password.
Alternatively, you can use [Omniauth](https://github.com/intridea/omniauth)
to authenticate based on credentials from another service like Facebook, Twitter, or Github.

After you have authenticated your user
subsequent post requests
to create/update data in your application
should maintain Rails' [CSRF](http://guides.rubyonrails.org/security.html#cross-site-request-forgery-csrf) protection mechanism.

Most of the JavaScript frameworks like
[Ember.js](https://github.com/emberjs/ember-rails#csrf-token) and
[AngularJS](https://docs.angularjs.org/api/ng/service/$http#cross-site-request-forgery-xsrf-protection)
provide mechanisms
for using Rails' CSRF mechanism.

Rails' [jquery-ujs](https://github.com/rails/jquery-ujs) library
also provides this for all [XHR](http://en.wikipedia.org/wiki/XMLHttpRequest) requests made via [jQuery](http://jquery.com/).
It does this by setting `HTTP_X_CSRF_TOKEN`
in the post request's header.
Just make sure you're still including `jquery-ujs` via your asset pipeline.

## Mobile and External Services

Because mobile device and other service applications
typically don't have the same cookies/session support as a browser
you will need some other authorization scheme.
Security is a very big consideration here
so you'll need to choose carefully.

The APIs available on existing popular services
employ a variety of authentication schemes
and there isn't a common standard.
Generally the simpler the scheme you
choose the easier it will be to implement on the client and server,
but also the less secure it will be.

### Using a Simple Access Token

One of the simplest schemes is to use some sort of authorization token
in a header or other part of the request.
If you're looking for a place to start
you can create an API login endpoint
and have it authenticate the user.
You then create and store a token in the database
and return it to the client application.
Subsequent requests will be made with this token
in the HTTP header data (preferred)
or payload
and will be used to look up the user for authorization purposes.

You'll also need to consider token expiration policies.
Simple implementations may use the same token
for a single user on multiple devices or services.
You can then move the token expiration forward
with each request, effectively keeping the user logged in
as long as they're active.
If you choose to set a fixed expiration
users will effectively be logged out
at the time the token expires.

You can also use a gem like [Tiddle](https://github.com/adamniedzielski/tiddle)
which combines with [Devise](https://github.com/plataformatec/devise)
to create and manage a unique token for each device or server
your user logs in with.

### More Sophisticated/Secure Schemes

If you need something more secure
then [OAuth](http://en.wikipedia.org/wiki/OAuth)
is probably the most widely adopted standard.
You can use the [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper) gem
to help with your implementation.

### Forgery Protection

Regardless of how you authenticate a user
for these types of APIs,
you'll need to turn off CSRF provisions
on POST requests or otherwise
you'll get these entries in your log files:

```
Can't verify CSRF token authenticity
```

You can override the default
forgery protection initially set in `app/controllers/application_controller.rb`:

```ruby
protect_from_forgery with: :null_session
```

This will remove the server errors generated by the default setting
that causes exceptions to be raised
but it won't get rid of the log messages.

You should be careful not to remove this check
for server requests other than those directed at your API.
If you have any admin pages
or other browser-based forms for users to submit
you should still perform this check on those POST requests.

You can skip the token authentication (leaving `protect_from_forgery` set to `:exception`)
by adding this to the appropriate controller files:

```ruby
skip_before_action :verify_authenticity_token
```

This method also takes an `:if` option
where you can provide a predicate proc
that determines if this request is for
the API specifically,
effectively shutting off CSRF checking.

## Service Oriented Architectures

Depending on the network architecture
of your SOA application,
you may be able to run API endpoints
without any authentication scheme at all
if your services live behind a firewall.

If that isn't the case then
the methods mentioned previously
for mobile and external services will also work.
[HTTP basic access authentication](http://en.wikipedia.org/wiki/Basic_access_authentication)
is another option
and can be set up in your web server (e.g. Nginx/Apache)
and not be a concern of your Rails application server.
Client application servers
will need to provide proper credentials
when they make requests.

You'll also need to consider
where to authenticate any external users.
It's probably best to do that at the edge of your service
in which case you may need to pass the user's identity
to other components in your service.

## Authorization

Authorizing access to data in your system
can be handled with the same techniques
you use for page-oriented applications
after authenticating the user's credentials.
[Cancancan](https://github.com/CanCanCommunity/cancancan) is a popular gem to do this
but recently I've been leaning more towards [Pundit](https://github.com/elabs/pundit)
because I find it a bit more transparent in how its rules are checked.

## Next Up

Authentication and authorization
may be one of the more complex issues
you'll need to tackle when implementing your API in a Rails application.
There are several ways to accomplish this
and a fair amount of discussion and debate
around which ones are best.

Another heavily discussed topic is
how to represent the data in your system.
In the next article in this series
I'll start to talk about that
with a discussion of how to define
resources and build the URI routes for them.
