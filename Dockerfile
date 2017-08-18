#use ruby version 2.3.3
FROM ruby:2.3.3

#set up working directory; create a new one this container;
RUN mkdir /myapp
WORKDIR /myapp

ADD Gemfile /myapp/Gemfile
ADD Gemfile.lock /myapp/Gemfile.lock

RUN bundle install

# ADD ./myapp /myapp
