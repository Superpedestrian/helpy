FROM ruby:2.4

ARG HELPY_USERNAME
ARG HELPY_PASSWORD

ENV RAILS_ENV=production \
    HELPY_HOME=/helpy \
    HELPY_USER=helpyuser \
    HELPY_SLACK_INTEGRATION_ENABLED=true \
    BUNDLE_PATH=/opt/helpy-bundle

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y nodejs postgresql-client imagemagick --no-install-recommends \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --no-create-home $HELPY_USER \
  && mkdir -p $HELPY_HOME $BUNDLE_PATH \
  && chown -R $HELPY_USER:$HELPY_USER $HELPY_HOME $BUNDLE_PATH

WORKDIR $HELPY_HOME

ADD Gemfile /$HELPY_HOME/Gemfile
ADD Gemfile.lock /$HELPY_HOME/Gemfile.lock
ADD vendor /$HELPY_HOME/vendor

# add the slack integration gem to the Gemfile if the HELPY_SLACK_INTEGRATION_ENABLED is true
# use `test` for sh compatibility, also use only one `=`. also for sh compatibility
RUN test "$HELPY_SLACK_INTEGRATION_ENABLED" = "true" \
    && sed -i '128i\gem "helpy_slack", git: "https://github.com/helpyio/helpy_slack.git", branch: "master"' $HELPY_HOME/Gemfile

# install rails dependencies
RUN bundle config gems.helpy.io $HELPY_USERNAME:$HELPY_PASSWORD
RUN bundle install

# add local files
COPY . /$HELPY_HOME

RUN touch /helpy/log/$RAILS_ENV.log && chmod 0664 /helpy/log/$RAILS_ENV.log

# Due to a weird issue with one of the gems, execute this permissions change:
RUN chmod +r /usr/local/bundle/gems/griddler-mandrill-1.1.3/lib/griddler/mandrill/adapter.rb

# manually create the /helpy/public/assets and uploads folders and give the helpy user rights to them
# this ensures that helpy can write precompiled assets to it, and save uploaded files
RUN mkdir -p $HELPY_HOME/public/assets $HELPY_HOME/public/uploads \
    && chown $HELPY_USER $HELPY_HOME/public/assets $HELPY_HOME/public/uploads

VOLUME $HELPY_HOME/public


# Asset Precompile
RUN DB_ADAPTER=nulldb bundle exec rake assets:precompile

# Adjust permissions
RUN chown -R $HELPY_USER:$HELPY_USER /$HELPY_HOME

# Run the server
CMD bundle exec unicorn -E $RAILS_ENV -c config/unicorn.rb

# Enter the right user
USER $HELPY_USER