---
title: Creating APIs Using Rails
date: 2015-03-22
tags: Rails, API
---

With the advent of increasing numbers of single page and mobile applications
developers are now more likely
to use Rails to implement a resource-oriented API
in place of more traditional HTML page-oriented applications.

There are quite a few issues and decisions
that need to be made while implementing an API in Rails.
This article is the first in a series where
I'll describe the technologies used in Rails APIs
and the issues that need to be considered while developing one.
In future articles I'll cover each issue
in more detail.

READMORE

## What Kind of API is it?

In this series of articles,
we will be using
the most common definition of a web services API:
using the HTTP method verbs in a [RESTful](http://en.wikipedia.org/wiki/Representational_state_transfer) manner,
usually with [JSON](http://en.wikipedia.org/wiki/JSON) as the data interchange format.

There are generally four different reasons
why you would create a Rails API:

- As the backend to a browser-based Single Page Application (SPA) usually in conjunction with a JavaScript framework like
  [Ember.js](https://github.com/emberjs/ember-rails#csrf-token),
  [AngularJS](https://docs.angularjs.org/api/ng/service/$http#cross-site-request-forgery-xsrf-protection),
  or [Flux](http://facebook.github.io/flux/)/[React](http://facebook.github.io/react/).
  
- As the backend to a mobile application.
- As an interface for other web-based services to access and modify the data in your application.
- As a component in a larger Service Oriented Architecture (SOA) application.

These different API types
will often lead to different implementation concerns.
For instance, for SPAs
you have the benefit of cookies
to preserve session state from request to request.
You can use this
to maintain the notion of a user being logged in.

For mobile and web-based service APIs
you'll have to do something like
return a token when a user provides their username and password to log in.
This token will then be used to prove the authenticity of the user
in subsequent requests.

Finally, for SOA applications,
the API servers may be running behind the corporate firewall
and may not require any authentication at all.

## Coming up

Future articles will cover the following topics in more detail:

- Authentication and authorization
- Resource schema and how it relates to your URIs
- How to represent the resources in JSON
- Request validation
- Error reporting
- Documentation

If you'd like to be notified
about future updates to this series,
please sign up for my email newsletter at right.
