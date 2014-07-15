FROM ubuntu:trusty
MAINTAINER yutopp

RUN locale-gen --no-purge en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get -y update && apt-get -y upgrade
RUN apt-get install -y nginx
RUN apt-get install -y reprepro
RUN apt-get install -y build-essential
RUN apt-get install -y ruby ruby-dev
RUN apt-get install -y git wget unzip python
RUN apt-get install -y cmake subversion clang
RUN apt-get install -y libsqlite3-dev

RUN gem install thin bundler fpm --no-rdoc --no-ri

ADD nginx.conf /etc/nginx/nginx.conf

RUN if [ ! -e /usr/local/torigoya ]; then mkdir /usr/local/torigoya; fi

ADD app /etc/app
ADD config.in_docker.yml /etc/app/config.yml
RUN cd /etc/app; bundle update
RUN cd /etc/app; rake db:migrate

RUN cd /etc; git clone https://github.com/yutopp/torigoya_package_scripts.git package_scripts

EXPOSE 80
EXPOSE 8080

CMD nginx && cd /etc/app && ruby web-frontend.rb
