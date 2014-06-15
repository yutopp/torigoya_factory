FROM ubuntu:trusty
MAINTAINER yutopp

RUN locale-gen --no-purge en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get -y update && apt-get -y upgrade
RUN apt-get install -y nginx
RUN apt-get install -y reprepro
RUN apt-get install -y build-essential
RUN apt-get install -y ruby ruby-dev

RUN gem install thin bundler

ADD build_server /etc/build_server
RUN cd /etc/build_server; bundle update

ADD nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
EXPOSE 8080

CMD nginx && cd /etc/build_server && ruby app.rb
