FROM seocahill/abairt

LABEL Name=abairt Version=0.0.1

EXPOSE 3000

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /workspace
COPY . /workspace

COPY Gemfile Gemfile.lock ./
RUN bundle install --without="test,development" --deployment=true

CMD ["bin/rails", "-b", "0.0.0.0", "s"]
