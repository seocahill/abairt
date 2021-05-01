# Abairt

https://abairt.herokuapp.com

A simple application to share, search and download irish sentences, translations and pronunciations.

* Ruby 2.7 https://www.ruby-lang.org/en/

* Rails 6.1 https://guides.rubyonrails.org/index.html

* Tailwind CSS 2.x https://tailwindcss.com/

* Hotwire https://hotwire.dev/

* Postgresql 13 https://www.postgresql.org/

* Redis https://redis.io/

* Docker https://www.docker.com/

* Amazon simple object storage https://aws.amazon.com/s3/

* Deployed on Heroku PAAS https://www.heroku.com/

* bug tracking https://sentry.io/organizations/seo-cahill/issues/?project=5656899

## Development setup

* install docker and start the daemon

* git clone this repo && cd abairt

* bundle install

* docker-compose up -d

* rails db:prepare

* rails server

The application will be accessible on http://localhost:3000

## Note on db backup / swithing

To back up remote heroku postgres to local postgres execute `pgsync`

To export pg data to sqlite db execute

```
gem install sequel
sequel -C postgres://postgres@localhost:5432/abairt_development sqlite://db/development.sqlite3
```