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

## NB

Migration path (FIXME)

I've moved it out of 'db' because of the enclosing folder is mounted (db data) and that overwrites migrations in image.

Changed in 672f4759beaa7412089dc0d842be252eace66871, should revert and fix properly. Should have stored dbs in their own folder I guess but this was the easiest way to fix for now.

### DM

The basic unit is the dictionary_entry, which always belongs to the user that created it.

Dictionary_entry also has and can belong to one or more rangs (to avoid repetition), through rang_entries
A 'rang' is a classroom where a teacher user interacts with one or more student users.
Rangs can have multiple users and vice versa through seomras.

Dictionary_entry can also optionally belong to a voice_recording.

Dictionary_entries are the corpus of the dictionary and are comprised of words and phrases from chat messages in classes and transcriptions of recordings. A recording transcript can be exported to various formats. Each dictionary adds a the portion of the media file it transcribes as an attachment for use in the corpus is a bacground job.

A user can be admin, editor, viewer, list. A user has a voice, a dialect, a lat_lang.

Downloadable lists include:
- viewer lists:  current_viewer_user.rangs.dictionary_entries
- admin/editor lists: editor.rangs.dictionary_entries

Lists are private by default but can be made public, dictionary_entries are always public and included in the codex
Lists can be downloaded as csvs for use in spaced repition apps like anki.

## Notes on Libs
- Rufus for wrapping cron
- yui-compressor to get around sassc tailwind incompatibility


## Restoring

First do lightsream (restore only)
Then change permissions `chown nonroot:root db` `chmod 755 db`
Then add Rails
Finally when other server is retired add back replication

## FTS issues

Check if the triggers have been removed for some reason (could be altering parent table?):

```sql
SELECT name, tbl_name, sql FROM sqlite_master WHERE type = 'trigger';
```

If missing re-run approprite migration

Finally rebuild the index:

```sql
sqlite> INSERT INTO fts_dictionary_entries(fts_dictionary_entries) VALUES('optimize');
sqlite> INSERT INTO fts_dictionary_entries(fts_dictionary_entries) VALUES('rebuild');
```

## Shrink mp3s

```bash
file=/some/mp3
ffmpeg -i $file.mp3 -codec:a libmp3lame -qscale:a 2 $file-sm.mp3
```

```bash
ffmpeg -i [stream URL] -acodec libmp3lame -ab 128k [output file name].mp3
```

```bash
pg_dump --clean --if-exists --quote-all-identifiers \
 -h localhost -U postgres -d postgres \
 --no-owner --no-privileges > embeddings.sql
```

```bash
psql -h db.wtdrbfgcompphsorooqe.supabase.co -U postgres --file embeddings.sql -p 6543 -d postgres
```
