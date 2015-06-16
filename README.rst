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

Before installing
=================

Before you can install, either for production or development, you need:

    apt-get install build-install python-dev \
        libxml2-dev libxslt-dev zlib1g-dev

Development
===========

Installation
------------

Installation is much the same as any other buildout-based site.

1. Check out this repository somewhere, e.g. ``git clone git://github.com/tutor-web/tutorweb.buildout``
3. ``cp buildout.cfg.example buildout.cfg`` and edit it to your liking
2. ``python bootstrap.py``
4. ``bin/buildout``
5. ``bin/instance fg``

NB: You don't need to set up MySQL. By default, it will use a SQLite database
``quizdb.sqlite`` in the current directory.

All the other tutorweb repositories will be checked out for you under the
``src/`` directory.

Fake SMTP server
----------------

The development buildout will also create a fake smtpd server, running on port
1025. You can run it with ``./bin/debugsmtp``

Running tests
-------------

Once buildout is run, you should have a testrunner to run tests from any of the
modules, for example ``bin/test -s tutorweb.content``.

Production Installation
=======================

Creating MySQL Database
-----------------------

Log in to the MySQL database as root, issue the following commands::

    CREATE DATABASE tw_quizdb;
    GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,INDEX,ALTER,LOCK TABLES
        ON tw_quizdb.*
        TO 'tw_quizdb'@'localhost'
        IDENTIFIED BY 'quizdb';
    GRANT DELETE
        ON tw_quizdb.allocation
        TO 'tw_quizdb'@'localhost'
        IDENTIFIED BY 'quizdb';

Note, the database will be created automatically, but any schema alterations
will have to be performed manually in SQL.

Buildout configuration
----------------------

Next, clone this repository somewhere, copy ``buildout.cfg.example`` to
``buildout.cfg`` and edit it to your tastes.

Then run your buildout config::

    python bootstrap.py
    ./bin/buildout

Finally, start Plone::

    ./bin/supervisord

Cron jobs
---------

The buildout will automatically create entries in the current user's crontab
to:

* Pack the ZEODB
* Backup Plone
* Start Plone on machine startup

If you want more details of these, look at the ``cfgs/production.cfg`` file.

Debug instance
--------------

The buildout also sets up a buildout instance for tinkering. Invoke with
``./bin/instance-debug fg`` to run an instance accessible on port 8189,
``./bin/instance-debug debug`` to open the instance with a debug console.

Setting up the Plone site
=========================

You need to create a site by going to ``/@@plone-addsite?site_id=tutor-web&advanced=1``.
Ensure that 'Tutorweb' and 'Tutorweb content' are selected.

There are (for now) a few things you have to do manually once a site is created.

* Remove the navigation portlet from the root of the site, with ``@@manage_portlets``
* Allow users to register themselves in security control panel
* Configure a mail relay in the Plone control panel

Virtual Host Monster
--------------------

To remove the need to supply /tutor-web, you can either configure the front end
to use the VHM, or go to /manage, virtual hosting and set up a mapping such as::

    mobile.tutor-web.net/tutor-web

Notes
=====

Configuring password reset emails
---------------------------------

The template is in ``/portal_skins/PasswordReset/registered_notify_template/manage_main``.

The expiry time is set in ``/portal_password_reset/manage_overview``.
