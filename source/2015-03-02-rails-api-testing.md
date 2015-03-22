---
title: Rails API Testing
date: 2015-03-02
tags: Rails, Rspec, API, Testing
published: false
---

As I've worked more with TDD and Ruby/Rails
I've developed an implicit set of rules
about where I test certain things.
I do Outside In testing [Put a ref here]
so at the very least I have high and low level tests.

Part of my rules are around
what goes in the high-level tests
and what goes in the low-level tests.
I also have rules about
how my application is structured
(usually with testability being a major driver)
and thus what kinds of things I test
for the various Model/View/Controller/etc. components.

At some point I'm thinking
I may open up a public repo
capturing my various rules.
I've mostly applied my rules
to standard page-oriented applications
but recent work for a couple of clients
has had me developing and testing backend APIs
and from that I've had a chance to reflect on
how my rules apply to API testing.

I've also discovered some differences
in how API requests are made
depending on whether you're making them
from rspec's request/integration specs
versus from controller specs.

In this article I'll describe
some of the issues around
developing and testing APIs in Rails
and how I apply my rules to the outside-in testing I do.
I'll also cover how rspec's requests are different
between request/integration and controller tests.

The most common interpretation
of API (or application programming interface) [wikipedia ref](http://en.wikipedia.org/wiki/Application_programming_interface)
for a Rails server is a service using typical HTTP requests.
Generally they follow REST [wikipedia ref] guidelines
with various levels of rigor (see HATEOS and Fielding) [moar refs]
and most often their data communication interchange is JSON [more refs].
For the examples
in this article
we'll be following those standards
(HTTP/REST/JSON).

## APIs can represent different things

There are generally three different reasons
why developers create a Rails API:

- As the backend to a mobile application.
- As the backend to a browser-based single page applications (usually in conjunction with a Javascript framework like EmberJS, Angular, or FlexJS/ReactJS.
- As an interface for other web applications to access and modify the data in their application.

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

feature (browser) == integration/release (api) for high level tests

## What to Test With Requests

- All data in JSON schema
- Authentication
- Error codes
- Routes?

### The Data in the JSON schema

It's likely that if your API has a complex schema
you'll be using a DSL/templating system
to extract and build that data.
In fact, a stock Rails application
now includes the [Jbuilder](https://github.com/rails/jbuilder) JSON builder DSL.

For my page-oriented applications
I generally don't have view-specific tests.
Instead I prefer to use a decorator/view model
like [Draper](https://github.com/drapergem/draper)
to encapsulate any logic.
I then use my feature tests
to make sure that my views
are correctly hooked into the decorator/view models.

I choose to use a similar hueristic
for my API testing and I view Jbuilder
as the equivalent to my template code.
It's probably best
to minimize the amount of code
in any single Jbuilder source file
so as to keep your JSON schemas
relatively small.
For these reasons I prefer to check
that all the data for my JSON schema
is available and properly formatted
with integration/request-level tests.

### Authentication

If your API is for a single page application
you'll likely be using Rails sessions
to keep track of a user
after they have authenticated.
Instead, for APIs consumed by mobile devices or other services
you'll probably be using some sort of authorization token
in a header or other part of the request.
In either case you'll want to perform some end-to-end
testing to make sure that a session or token
can be created
then subsequently used to appropriately access the correct data.
Generally my higher-level testing
is much more step-wise and adding an external login step
to each test is idiomatic.

### Error Codes/Error Messaging

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

<left off here>

### Routes

What was I thinking?

### How rspec creates scaffolds for these tests

`rails generate rspec:integration` vs. `rails generate rspec:request` (looks like it's the same thing - both put the specs in `spec/requests`

[ActionDispatch::Integration::RequestHelpers](http://api.rubyonrails.org/classes/ActionDispatch/Integration/RequestHelpers.html)

from within an

[ActionDispatch::Integration::Session](http://api.rubyonrails.org/classes/ActionDispatch/Integration/Session.html)

- get
- post
- put
- delete

also:

- patch
- head
- delete
- xhr/xml_http_request

There is also a set of requests
that will follow redirect responses
but they are really only useful
for testing page-based browser requests.
I can't think of any instance where
I'd need them for API testing.

get:
/home/brian/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/actionpack-4.2.0/lib/action_dispatch/testing/integration.rb
335
RSpec::ExampleGroups::Users::GETUsers

## What to Test With Controller Tests

- Logic through the controller
- Authorization
- Ideally uses mocks on calls to models (fits with not liking to use model find/update/create methods directly)
- Setting of assigns

[ActionController::TestCase::Behavior](http://api.rubyonrails.org/classes/ActionController/TestCase/Behavior.html)

- get
- post
- put
- delete

also:

- patch
- head
- xhr/xml_http_request

get:
/home/brian/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/actionpack-4.2.0/lib/action_controller/test_case.rb
504

post:
/home/brian/.rbenv/versions/2.2.0/lib/ruby/gems/2.2.0/gems/actionpack-4.2.0/lib/action_controller/test_case.rb
510

inside spec class:
RSpec::ExampleGroups::UsersController::GETIndex
