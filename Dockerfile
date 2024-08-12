FROM docker.io/library/ruby:2.7
ENV BUNDLER_VERSION=2.4.22
RUN gem install bundler:$BUNDLER_VERSION
WORKDIR /app
COPY Gemfile Gemfile.lock .
RUN bundle install
COPY . .
EXPOSE 4000
CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]
