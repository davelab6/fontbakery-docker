FROM        ubuntu:14.04

MAINTAINER  Vitaly Volkov <hash.3g@gmail.com> (@hash3g)

RUN     echo "deb http://mirror.bytemark.co.uk/ubuntu/ precise main universe multiverse" >> /etc/apt/sources.list

RUN     apt-get update
RUN     apt-get -y -q --fix-missing install python-software-properties software-properties-common
RUN     apt-get -y -q --fix-missing install alien dpkg-dev debhelper build-essential vim
RUN     add-apt-repository -y ppa:chris-lea/node.js
RUN     add-apt-repository ppa:fontforge/fontforge
RUN     apt-get update
RUN     apt-get install -y nodejs python-fontforge


# Install fontforge
RUN     apt-get -y -q install pkg-config libgtk2.0-dev libperl-dev

# Install all requirements for ``fontbakery``
RUN     DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential python python-virtualenv python-pip libevent-2.0-5 libevent-dev fonttools redis-server curl git mercurial libxslt1-dev libxml2-dev automake autoconf libtool libharfbuzz-dev qt5-default libffi-dev supervisor openssh-server unzip python-dev libsqlite3-dev redis-server libssl-dev subversion

ADD     http://dl.fedoraproject.org/pub/fedora/linux/updates/20/x86_64/ttfautohint-1.1-1.fc20.x86_64.rpm /ttfautohint-1.1-1.fc20.x86_64.rpm
RUN     cd / && alien ttfautohint-1.1-1.fc20.x86_64.rpm
RUN     cd / && dpkg -i ttfautohint*.deb

# Good way is to place project installed inside ``www`` directory
RUN     mkdir /var/www/
RUN     cd /var/www/ && git clone https://github.com/khaledhosny/ots.git
RUN     cd /var/www/ots && python gyp_ots && make

# To make container accessable with ssh create sshd directory
RUN     mkdir /var/run/sshd

# After install please change root password to your own
RUN     echo 'root:screencast' |chpasswd

ADD     supervisord.conf     /etc/supervisor/conf.d/
ADD     run  /usr/bin/
RUN     chmod +x /usr/bin/run

ADD     crontab   /crontab
RUN     crontab < /crontab

ADD     https://github.com/googlefonts/fontbakery/archive/master.zip /master.zip
RUN     unzip master.zip
RUN     mkdir -p /var/www/
RUN     mv fontbakery-master /var/www/fontbakery

ADD     local.cfg  /var/www/fontbakery/bakery/local.cfg

# Write configuration for Flask to local. This is initial file and
# MUST be changed to your needs manually
RUN     echo "import os" > /var/www/fontbakery/bakery/local.cfg
RUN     echo "ROOT = '/var/www/fontbakery/'" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "SQLALCHEMY_DATABASE_URI = 'sqlite:////%s/../../data.sqlite' % os.path.dirname(os.path.abspath(__file__))" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "DATA_ROOT = os.path.realpath(os.path.join(ROOT, \"..\", \"data\"))" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "GITHUB_CONSUMER_KEY = '4a1a8295dacab483f1b5'" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "GITHUB_CONSUMER_SECRET = 'ec494ff274b5a5c7b0cb7563870e4a32874d93a6'" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "SQLALCHEMY_ECHO = True" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo "OTS_BINARY_PATH = '/var/www/ots/out/Default/ot-sanitise'" >> /var/www/fontbakery/bakery/local.cfg
RUN     echo LANG="en_US.UTF-8" > /etc/default/locale
RUN     cp /var/www/fontbakery/bakery/local.cfg /var/www


# return USER to previous state
USER root

RUN apt-get autoremove -y

# Clear package repository cache
RUN apt-get clean all

# Install `six` packer over another packages
RUN     npm install -g bower
RUN     pip install six==1.6.1
RUN     pip install supervisor-stdout
RUN     pip install -r /var/www/fontbakery/requirements.txt
RUN     pip install git+https://github.com/behdad/fontTools.git
RUN     pip install git+https://github.com/googlefonts/fontbakery-cli.git
RUN     cd /var/www/fontbakery/static; bower install --allow-root

# Expose web server
EXPOSE  5000

# Expose SSH server
EXPOSE  22

# Expose 80 for mandrill messages
EXPOSE  80

RUN    sed -ri 's/^session\s+required\s+pam_loginuid.so$/session optional pam_loginuid.so/' /etc/pam.d/sshd
RUN    sed -ri 's/without-password/yes/' /etc/ssh/sshd_config


CMD     ["/usr/bin/run"]
