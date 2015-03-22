---
title: Creating APIs Using Rails
date: 2015-03-15
tags: Rails, API
published: false
---

Originally I set out
to write a post
on -testing- Rails APIs
but in the process I discovered that
to explain how I test an API meant that
I also needed to explain how I write that API.
So to keep that original post
from being too long and boring to read
I've decided to break it into several pieces.

In this first part
I'll describe the things I consider
when creating an API in Rails.
In upcoming articles I'll go
into how I test an API,
first describing what I put in my high-level tests
followed by how I test at the component level.

READMORE

## What Kind of API is it?

Just to be clear, when I speak of an API
in this article I am referring
to what has become somewhat of a de facto definition for a web services API:
Using HTTP to create an interface to an application,
using the method verbs in a [RESTful](http://en.wikipedia.org/wiki/Representational_state_transfer) manner,
usually using JSON as the data interchange format.

There are generally three different reasons
why you would create a Rails API:

- As the backend to a browser-based single page applications (from here on referred to as a SPA) usually in conjunction with a Javascript framework like EmberJS, Angular, or FlexJS/ReactJS.
- As the backend to a mobile application.
- As an interface for other web-based services to access and modify the data in their application.

These different API types
will often lead to a few different implementation concerns.
For instance, for single page applications
you have the benefit of cookies
to give you session state from request to request.
This means that you can use the session
to maintain the notion of a user being logged in
and you can use CSRF (link to definition) forgery checking turned on.
For the other types of APIs
you'll have to do something like
return a token to be used in subsequent requests
when the user/application authenticates itself.
You'll also want to disable CSRF forgery checking on these requests.

## Things to Consider

There are several things
you need to consider for your API design
and how you'll implement it:

- Authentication and authorization
- Resource schema and how it relates to your URIs
- How to represent the resources in JSON
- Request validation
- Error reporting
- Documentation

### Authentication and Authorization

If your API is for a single page application
you'll likely be using Rails sessions
to keep track of a user
after they have authenticated.
This usually means you won't need any extra authentication/authorization provisions beyond what
you would normally have for a page-oriented application.

You might need to pay a bit of attention
to how [CSRF](http://guides.rubyonrails.org/security.html#cross-site-request-forgery-csrf) protction is maintained.
Most of the JavaScript frameworks
([Ember.js](https://github.com/emberjs/ember-rails#csrf-token),
[AngularJS](https://docs.angularjs.org/api/ng/service/$http#cross-site-request-forgery-xsrf-protection))
provide mechanisms
for handling this.
Rails' [jquery-ujs](https://github.com/emberjs/ember-rails#csrf-token) library
also provides this for all [XHR](http://en.wikipedia.org/wiki/XMLHttpRequest) requests made via jQuery
(just make sure you're including the file via your asset pipeline).

For APIs consumed by mobile devices or other services
you'll probably be using some sort of authorization token
in a header or other part of the request.
I've come across various schemes
at different levels of complexity
(and usually security) and a full discussion
is probably best done in its own article.
If you're looking for a place to start,
perhaps the easiest thing to do
is to create an api login endpoint
(sometimes done as a session resource)
and have it authenticate the user and store a token in the database.
Subsequent requests will be made with this token
(usually as HTTP header data)
then the token can be used to look up the user for all subsequent authorization checks.

For all of the API types,
after authenticating the user's credentials
authorization can then be handled in the typical way.
[Cancancan](https://github.com/CanCanCommunity/cancancan) is a popular gem to do this
but recently I've been leaning more towards [Pundit](https://github.com/elabs/pundit)
There are standards to be implemented too.
because I find it a bit more transparent in how its rules are checked.

Also discus [Tiddle](https://github.com/adamniedzielski/tiddle)

### How to Represent the Resources in JSON

It's likely that if your API has a complex schema
you'll be using a DSL/templating system
to extract and build that data.
In fact, a stock Rails application
now includes the [Jbuilder](https://github.com/rails/jbuilder) JSON builder DSL.

### Request Validation

### Error Reporting

Error codes and messaging become more important
for the more decoupled uses of your API (mobile and external services)
than for a SPA.
In the case of the SPA you're often most concerned only with
whether things errored or not since it's much more likely
that your requests are otherwise well-formed and sesnible.

On the other hand, for mobile and eternal services
I have found that there is a desire
for codes and messages that are even more descriptive than
those specified by the http standards
since there is greater need for the clients
to be able to interpret the failures
and act on them correctly or display messages
to their users better describing how to change their input to fix their problem.

### Documentation

To tell the truth, I haven't yet worked
on a Rails API where I've been happy with the documenation.

There are some clever all-in-one solutions
like [apipie]()
that provide a DSL that you can include in your controllers.
Not only does the DSL provide page endpoints
with nicely formatted documentation about your API
but it also performs error checking on API inputs.

The problem I have with this
is the DSL becomes very invasive to your code
with long blocks of code before each action in your controller.
Also, as I've found with other DSL-heavy solutions
([like admin controllers](/get-rid-of-your-admin-gem.html)
having to learn another system
with different paradigms than Rails
can be a burden on the development team.

I've looked briefly at other solutions
like [RAML](http://raml.org/)
and [Slage](https://github.com/tripit/slate)
and... from my Evernote notes

## Relationship to the Rest of Your Application

If your API is only the backend
to a SPA then it is usually best
to incorporate it in to your larger Rails application.
You will likely have some html
served from standard Rails templates
and be making use of the asset pipeline
to serve the Javascript and Stylesheets
for your pages.

For mobile and standalone service backends
you may decide you would like to get rid of
some of the rest of Rails' overhead and
only use a subset of Rails.
The [Rails::API](https://github.com/rails-api/rails-api) gem
exists specifically for that purpose.
I generally recommend
against a solution like that.
Eventually you're likely to find
that you need to serve a page or two of HTML
and before long you're pulling all the pieces of Rails back in.
