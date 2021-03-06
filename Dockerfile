FROM debian:latest

# Arguments
ARG pass_tutorweb=pwtutorweb
ARG pass_mysql=pwmysql
ARG pass_smlyrpc=pwsmlyrpc
ARG pass_smlywallet=pwsmlywallet

# Straighten out Debian install
RUN echo 'APT { Install-Recommends false; };' > /etc/apt/apt.conf.d/no-recommends
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils locales \
	&& localedef -i en_GB -c -f UTF-8 -A /usr/share/locale/locale.alias en_GB.UTF-8
ENV LANG en_GB.utf8

# Install dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    procps \
    dumb-init \
    cron \
    file \
    openssh-client \
    logrotate \
    python \
    python-dev \
    python-tk \
    python-virtualenv \
    virtualenv \
    build-essential \
    gfortran \
    libxml2-dev \
    libxslt1-dev \
    libjpeg62-turbo-dev \
    git

# Install MySQL
RUN echo 'mysql-server mysql-server/root_password password "$pass_mysql"' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password "$pass_mysql"' | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server default-libmysqlclient-dev

# Install Nginx
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

# Copy requirements, run pip (NB: Do this first so docker can cache)
RUN adduser --system tutorweb
COPY requirements.txt /srv/tutorweb.buildout/requirements.txt
RUN chown -R tutorweb /srv/tutorweb.buildout
RUN ["/bin/su", "-s/bin/sh", "-", "tutorweb", "-c", "\
  cd /srv/tutorweb.buildout \
  && virtualenv . \
  && ./bin/pip install -r requirements.txt \
"]

# Copy buildout config, run buildout
COPY eggs /srv/tutorweb.buildout/eggs/
COPY download-cache /srv/tutorweb.buildout/download-cache/
COPY local-eggs /srv/tutorweb.buildout/local-eggs/
COPY cfgs/* /srv/tutorweb.buildout/cfgs/
COPY docker/buildout_base.cfg /srv/tutorweb.buildout/docker/
RUN /bin/echo -e "\n\
[buildout]\n\
extends = docker/buildout_base.cfg\n\
[passwords]\n\
admin = $pass_tutorweb\n\
mysqlroot = $pass_mysql\n\
smlyrpc = $pass_smlyrpc\n\
smlywallet = $pass_smlywallet\n\
" > /srv/tutorweb.buildout/buildout.cfg
RUN chown -R tutorweb /srv/tutorweb.buildout
RUN ["/bin/su", "-s/bin/sh", "-", "tutorweb", "-c", "\
  cd /srv/tutorweb.buildout \
  && ./bin/buildout \
"]

# Copy SSH key into place
COPY id_rsa /home/tutorweb/.ssh/
RUN /usr/bin/ssh-keyscan -H tutor-web.net > /home/tutorweb/.ssh/known_hosts
RUN ["chown", "-R", "tutorweb", "/home/tutorweb/.ssh/"]

# Untar Data.fs tarball
COPY dump.tar.bz2 /srv/tutorweb.buildout
WORKDIR /srv/tutorweb.buildout
RUN ["/bin/su", "-s/bin/sh", "-", "tutorweb", "-c", "tar -C /srv/tutorweb.buildout -jxf /srv/tutorweb.buildout/dump.tar.bz2"]
VOLUME /srv/tutorweb.buildout/var/filestorage /srv/tutorweb.buildout/var/blobstorage /srv/tutorweb.buildout/local-dumps

# Set-up Nginx
RUN rm /etc/nginx/sites-enabled/default
COPY docker/nginx_site.conf /etc/nginx/sites-enabled/tutorweb

# Set-up MySQL
COPY docker/cfg_mysql.sh /srv/tutorweb.buildout/docker/cfg_mysql.sh
RUN /srv/tutorweb.buildout/docker/cfg_mysql.sh $pass_mysql $pass_tutorweb
VOLUME /var/lib/mysql

# Generate start script to start all daemons, and run that on startup
RUN /bin/echo -e "#!/usr/bin/dumb-init /bin/sh\n\
/etc/init.d/cron start \n\
/etc/init.d/nginx start \n\
/etc/init.d/mysql start \n\
/srv/tutorweb.buildout/bin/supervisord -u tutorweb -n \n\
" > /sbin/start
RUN chmod a+x /sbin/start
CMD ["/sbin/start"]
EXPOSE 8080
EXPOSE 8189
