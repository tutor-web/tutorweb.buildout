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

Setting up site
===============

There are (for now) a few things you have to do manually.

* Remove the navigation portlet from the root of the site, with @@manage_portlets
* Allow users to register themselves in security control panel

Production Installation
=======================

Creating MySQL Database
-----------------------

Log in to the MySQL database as root, issue the following commands::

    CREATE DATABASE tw_quizdb;
    GRANT SELECT,INSERT,UPDATE,CREATE,INDEX,ALTER,LOCK TABLES
        ON tw_quizdb.*
        TO 'tw_quizdb'@'localhost'
        IDENTIFIED BY 'quizdb';

Buildout configuration
----------------------

Next, make a buildout.cfg, e.g.

    [buildout]
    extends = cfgs/production.cfg
    quizdb-url = mysql+mysqldb://tw_quizdb:quizdb@localhost/tw_quizdb?charset=utf8
    
    [instance]
    user = admin:admin
