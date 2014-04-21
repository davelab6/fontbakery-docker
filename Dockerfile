FROM        ubuntu:13.10

MAINTAINER  Vitaly Volkov <hash.3g@gmail.com> (@hash3g)

RUN     echo "deb http://mirror.bytemark.co.uk/ubuntu/ precise main universe" >> /etc/apt/sources.list

# Add the PostgreSQL PGP key to verify their Debian packages.
# It should be the same key as https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN     apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8
RUN     add-apt-repository -y ppa:chris-lea/node.js

# Add PostgreSQL's repository. It contains the most recent stable release
#     of PostgreSQL, ``9.3``.
RUN     echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Update the Ubuntu and PostgreSQL repository indexes
RUN     apt-get update

# Install ``python-software-properties``, ``software-properties-common`` and PostgreSQL 9.3
#  There are some warnings (in red) that show up during the build. You can hide
#  them by prefixing each apt-get statement with DEBIAN_FRONTEND=noninteractive
RUN     apt-get -y -q install python-software-properties software-properties-common
RUN     apt-get -y -q install postgresql-9.3 postgresql-client-9.3 postgresql-contrib-9.3 libpq-dev

RUN     apt-get update
RUN     apt-get install -y nodejs

# Install fontforge
RUN     apt-get -y -q install pkg-config libgtk2.0-dev libperl-dev

# Install all requirements for ``fontbakery``
RUN     DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential python python-virtualenv python-pip libevent-2.0-5 libevent-dev fonttools redis-server curl git mercurial libxslt1-dev libxml2-dev automake autoconf libtool libharfbuzz-dev libharfbuzz-dev qt5-default libffi-dev supervisor openssh-server unzip python-dev libsqlite3-dev redis-server libssl-dev

ADD     https://github.com/fontforge/fontforge/archive/2.0.20140101.tar.gz /fontforge-src.tar.gz
RUN     tar zxf /fontforge-src.tar.gz
RUN     cd fontforge-2.0.20140101 && ./autogen.sh && ./configure && make && make install

# Good way is to place project installed inside ``www`` directory
RUN     mkdir /var/www/

# To make container accessable with ssh create sshd directory
RUN     mkdir /var/run/sshd

# After install please change root password to your own
RUN     echo 'root:screencast' |chpasswd

ADD     supervisord.conf     /etc/supervisor/conf.d/

ADD     https://github.com/hash3g/fontbakery/archive/master.zip /master.zip
RUN     unzip master.zip
RUN     mkdir -p /var/www/
RUN     mv fontbakery-master /var/www/fontbakery

ADD     local.cfg  /var/www/fontbakery/bakery/local.cfg

# Write configuration for Flask to local. This is initial file and
# MUST be changed to your needs manually
RUN     echo "import os" > /var/www/fontbakery/bakery/local.cfg
RUN     echo "ROOT = '/var/www/fontbakery/'" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "SQLALCHEMY_DATABASE_URI = 'postgresql://docker:docker@localhost/docker'" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "DATA_ROOT = os.path.realpath(os.path.join(ROOT, \"..\", \"data\"))" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "SECRET_KEY = `python -c 'import os; print "%r" % os.urandom(24)'`" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "GITHUB_CONSUMER_KEY = '4a1a8295dacab483f1b5'" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "GITHUB_CONSUMER_SECRET = 'ec494ff274b5a5c7b0cb7563870e4a32874d93a6'" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "SQLALCHEMY_ECHO = True" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo LANG="en_US.UTF-8" > /etc/default/locale
RUN     cp /var/www/fontbakery/bakery/local.cfg /var/www

# Setup library path so that fontforge python library can find ``fontforge.so`` library
ENV     LD_LIBRARY_PATH /usr/local/lib/:/usr/lib


# Next 3 commands RUN must be executed as ``postgres`` user
USER postgres

# Create a PostgreSQL role named ``docker`` with ``docker`` as the password and
# then create a database `docker` owned by the ``docker`` role.
# Note: here we use ``&&\`` to run commands one after the other - the ``\``
#       allows the RUN command to span multiple lines.
RUN    /etc/init.d/postgresql start &&\
    psql --command "CREATE USER docker WITH SUPERUSER PASSWORD 'docker';" &&\
    createdb -O docker docker

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN     echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.3/main/pg_hba.conf

# And add ``listen_addresses`` to ``/etc/postgresql/9.3/main/postgresql.conf``
RUN     echo "listen_addresses='*'" >> /etc/postgresql/9.3/main/postgresql.conf


# return USER to previous state
USER root

# Install `six` packer over another packages
RUN     npm install -g bower
RUN     pip install -r /var/www/fontbakery/requirements.txt
RUN     cd /var/www/fontbakery/static; bower install --allow-root
RUN     /etc/init.d/postgresql start && cd /var/www/fontbakery && python init.py && python scripts/statupdate.py

# Expose the PostgreSQL port
EXPOSE  5432

# Expose web server
EXPOSE  5000

# Expose SSH server
EXPOSE  22

RUN    cat /etc/pam.d/sshd > /sshd.pam.bak
RUN    sed 's/required     pam_loginuid.so/optional     pam_loginuid.so/g' /sshd.pam.bak > /etc/pam.d/sshd

# Add VOLUMEs to allow backup of config, logs and databases
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

CMD     ["supervisord"]
