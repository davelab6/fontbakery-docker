FROM        ubuntu:14.04

MAINTAINER  Vitaly Volkov <hash.3g@gmail.com> (@hash3g)

RUN     echo "deb http://mirror.bytemark.co.uk/ubuntu/ precise main universe multiverse" >> /etc/apt/sources.list

RUN     apt-get update
RUN     apt-get -y -q --fix-missing install python-software-properties software-properties-common
RUN     add-apt-repository -y ppa:chris-lea/node.js
RUN     apt-get update
RUN     apt-get install -y nodejs


# Install fontforge
RUN     apt-get -y -q install pkg-config libgtk2.0-dev libperl-dev

# Install all requirements for ``fontbakery``
RUN     DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential python python-virtualenv python-pip libevent-2.0-5 libevent-dev fonttools redis-server curl git mercurial libxslt1-dev libxml2-dev automake autoconf libtool libharfbuzz-dev qt5-default libffi-dev supervisor openssh-server unzip python-dev libsqlite3-dev redis-server libssl-dev subversion

ADD     https://github.com/fontforge/fontforge/archive/2.0.20140101.tar.gz /fontforge-src.tar.gz
RUN     tar zxf /fontforge-src.tar.gz
RUN     cd fontforge-2.0.20140101 && ./autogen.sh && ./configure --prefix=/usr && make && make install

# ADD     http://downloads.sourceforge.net/project/freetype/ttfautohint/1.1/ttfautohint-1.1.tar.gz /ttfautohint-1.1.tar.gz
# RUN     tar zxf /ttfautohint-1.1.tar.gz
# RUN     cd ttfautohint-1.1 && ./configure && make && make install

# Good way is to place project installed inside ``www`` directory
RUN     mkdir /var/www/
RUN     git clone https://github.com/khaledhosny/ots.git
RUN     cd ots && python gyp_ots && make

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
RUN     cd /var/www/fontbakery/static; bower install --allow-root
RUN     cd /var/www/fontbakery && python init.py && python scripts/statupdate.py

# Expose web server
EXPOSE  5000

# Expose SSH server
EXPOSE  22

EXPOSE  587

RUN    sed -ri 's/^session\s+required\s+pam_loginuid.so$/session optional pam_loginuid.so/' /etc/pam.d/sshd

CMD     ["supervisord"]
