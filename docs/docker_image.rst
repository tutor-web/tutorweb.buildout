Generating Tutor-web Docker image
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This repository includes a ``Dockerfile`` for generating a Docker image.

Regenerating image
==================

Install docker::

    apt install docker.io

Generate a ``dump.tar.bz2`` containing another server's ``var/filestorage`` and ``var/blobstorage``.

Generate a host key to install into the image for forwarding dumps::

    ssh-keygen -N "" -f id_rsa

Build the image::

    docker build -t tutorweb .

Running image
=============

Run the image::

    docker run -d -p 8080:8080 tutorweb

NB: Tutor-web expects incoming requests on port 8080, if this is incorrect then
the image needs to be changed correspondingly.

Before questions can be answered, sync_all needs to be run to populate mySQL::

    docker exec -i $(docker ps | awk '/tutorweb/ { print $1 }') \
        /bin/su -s/bin/bash - tutorweb -c '/srv/tutorweb.buildout/bin/sync_all'

Regenerating dump
=================

A dump for populating a new Dockerfile can be generated with::

    docker exec -it $(docker ps | awk '/tutorweb/ { print $1 }') \
        /bin/su -s/bin/bash - tutorweb -c '/srv/tutorweb.buildout/bin/zeopack'

    docker exec $(docker ps | awk '/tutorweb/ { print $1 }') \
        tar -jcC /srv/tutorweb.buildout var/filestorage var/blobstorage \
        > dump.tar.bz2

Buildout cache
==============

You can save buildout eggs for re-use on subsequent builds with::

    docker run tutorweb:latest tar -c \
        -C /srv/tutorweb.buildout \
        eggs download-cache \
        | tar x

Run debug instance
==================

Run the image, forwarding web and debug ports::

    docker run -d -p 8080:8080 -p 8189:8189 tutorweb

Run the debug instance in the container::

docker exec -it $(docker ps | awk '/tutorweb/ { print $1 }') \
    /bin/su -s/bin/bash - tutorweb -c '/srv/tutorweb.buildout/bin/instance-debug fg'

Or get a bash shell to a running container::

docker exec -it $(docker ps | awk '/tutorweb/ { print $1 }') bash
