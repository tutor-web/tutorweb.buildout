Tutor-web replication
^^^^^^^^^^^^^^^^^^^^^

One tutor-web server can relay it's questions to another, assuming that both instances have the same questions installed.

Creating a dump
===============

All data for a time period can be got via the a url like::

    http://localhost:8080/@@quizdb-replication-dump?from=2010-04-20&to=2019-04-24

This will return all answers given in the time period, and any ancillary data needed to interpret it.

Ingesting the dump
==================

Before a dump can be ingested, any hostKeys need to be set on the receiving tutor-web instance. For example::

    http://localhost:8080/@@quizdb-replication-updatehost?fqdn=remote.tutor-web.net&hostKey=12345

This information can be found in the dump. Once this is done you can send the dump to::

    http://localhost:8080/@@quizdb-replication-ingest

Copying tutor-web content
=========================

The entire content can be cloned by copying ``filestorage`` and ``blobstorage``.
Individual parts can be done via. /manage exports

Afterwards, visit the following link to make sure the DB is up-to-date::

    http://tutor-web.eias.lan/@@sync-all
