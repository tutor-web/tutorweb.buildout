Tutorweb
^^^^^^^^

A Plone site to aid in teaching.

Introduction
============

The tutorweb is broken up into several repositories:

* tutorweb.buildout: The configuration needed to build plone/tutorweb (this repo)
* tutorweb.quiz: The javascript quiz engine
* tutorweb.quizdb: The server-side DB to distribute and record answers
* tutorweb.content: The Plone content type configuration
* Products.Tutorweb: Legacy bits and bobs not yet ported over.

Development
===========

Installation
------------

Installation is much the same as any other buildout-based site.

1. Check out this repository somewhere
2. ``python bootstrap.py``
3. ``echo -e "[buildout]\nextends = cfgs/development.cfg" > buildout.cfg``
4. ``bin/buildout``
5. ``bin/instance fg``

By default, it will use a SQLite database ``quizdb.sqlite`` in the current
directory. You can find the other repositories already checked out under
``src/``.

Running tests
-------------

Once buildout is run, you should have a testrunner to run tests from any of the
modules, for example ``bin/test -s tutorweb.content``.
