#!/bin/sh
docker build -t tutorweb .
docker run tutorweb:latest tar -c -C /srv/tutorweb.buildout eggs download-cache | tar x
