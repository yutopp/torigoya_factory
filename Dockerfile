FROM ubuntu:trusty
MAINTAINER yutopp

RUN locale-gen --no-purge en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get -y update && apt-get -y upgrade && apt-get install -y --fix-missing \
nginx reprepro \
build-essential \
ruby ruby-dev \
libsqlite3-dev \
cmake subversion clang wget zip unzip perl python autoconf \
git groff mercurial \
diffutils texinfo flex guile-2.0-dev autogen tcl expect dejagnu gperf gettext automake m4 \
libreadline6 libreadline6-dev libc6-dev-i386 \
gauche bison

RUN cd /usr/bin; wget http://stedolan.github.io/jq/download/linux64/jq; chmod 755 jq

RUN cd /etc; git clone https://github.com/yutopp/torigoya_package_scripts.git package_scripts

RUN gem install thin bundler fpm --no-rdoc --no-ri

ADD nginx.conf /etc/nginx/nginx.conf

ADD app /etc/app
ADD config.in_docker.yml /etc/app/config.yml
ADD proc_profiles /etc/proc_profiles
RUN cd /etc/app; bundle update

EXPOSE 80
EXPOSE 8080

CMD nginx && cd /etc/app && bundle exec rake db:migrate && bundle exec ruby web-frontend.rb
