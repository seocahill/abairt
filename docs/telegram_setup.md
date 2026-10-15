# Telegram questions

One of two transports a speaker can be on. The other is WhatsApp
(`whatsapp_setup.md`); why there are two, and why Telegram is the one to start
with, is in `speaker_transport.md`.

Everything above the transport — `QuestionQueue`, `QuestionRouter`, the
draft/send flow, the admin backlog — is shared and knows nothing about
Telegram. `QuestionTransport` is the only place that picks.

## Why this is the shorter document

No 24 hour window, so no templates, no nudge and nothing waiting on approval.
No business entity, no verification, no card on file. The webhook secret is a
string Telegram echoes back rather than an HMAC over the body. Setting the whole
thing up is five minutes with @BotFather.

The audio requirement is the same — `sendVoice` wants ogg/opus, which is exactly
what `OpusVoiceNote` already guarantees for WhatsApp.

## Setting it up

### 1. The bot

Message [@BotFather](https://t.me/BotFather) and send `/newbot`. Keep the token
it gives you.

Then make the bot look like the app rather than like a bot:

| | |
|---|---|
| `/setname` | Abairt |
| `/setuserpic` | the logo |
| `/setdescription` | one line, in Irish |
| `/setcommands` | leave it empty, so there is no slash menu to discover |

The speaker should never have a reason to think of this as a bot, or of Telegram
as anything other than where Abairt lives.

### 2. Credentials

Add under `telegram:` in `rails credentials:edit`, or as environment variables:

| Credential | Env var | What it is |
|---|---|---|
| `bot_token` | `TELEGRAM_BOT_TOKEN` | What @BotFather gave you |
| `webhook_secret` | `TELEGRAM_WEBHOOK_SECRET` | Any long random string you choose |
| `bot_username` | `TELEGRAM_BOT_USERNAME` | e.g. `AbairtBot` — only used to build invite links |

The secret is not optional. Telegram echoes it in a header on every delivery and
the controller rejects anything that does not match — including every request if
no secret is configured, so a deployment that forgets it fails shut rather than
accepting updates from anyone who guesses the URL.

### 3. The webhook

A one-off call. There is no handshake to answer and nothing to subscribe to:

```sh
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -d "url=https://abairt.com/api/telegram/webhook" \
  -d "secret_token=$TELEGRAM_WEBHOOK_SECRET"
```

Check it with `getWebhookInfo`, which also reports the last delivery error if
something is wrong.

**Locally, do not set a webhook at all.** Poll instead:

```sh
bin/rails telegram:poll
```

It long polls and hands each update to the same `InboundMessage` and
`ProcessInbound` the webhook uses, so what works under it works deployed. No
tunnel, no public URL, which is what makes a first run with a real speaker
possible from a laptop.

The two are mutually exclusive — Telegram answers 409 to `getUpdates` while a
webhook is set, and the task stops and says so rather than deleting it, since
that webhook may be production's. **Use a second bot for development.**

### 4. The speaker

Created in admin: **Users → New User**. A name, *Takes questions* checked, and
the channel set to Telegram. That is all that is required — no email, no
password, and **no phone number**: on Telegram the identity is a chat id, and
an invite link supplies it.

Leave the chat id alone. It fills itself in.

Their page then shows an **invite link** — `t.me/<bot>?start=<token>`. Send it
to them however you like. One tap connects them, and the link stops working the
moment it is used, so a forwarded or screenshotted one claims nothing. If they
lose it, or a speaker predates invite links and has no token, the same page has
a button to issue a new one, which invalidates the old.

### 5. Their phone — one visit

The steps, and why each one matters, are in `speaker_transport.md`. The short
version: install, **deny the contacts permission**, lock down who can message
them, **tap the invite link**, **allow notifications**, and on Android exclude
Telegram from battery optimisation.

Until they tap it there is no chat id, so `User.answering` leaves them out and
nothing is routed to them. That is deliberate: a question with nowhere to go
would otherwise sit as `waiting` with no explanation.

#### If they arrive without a link

Someone who finds the bot and taps Start is asked to share their phone number
instead, which is matched against a speaker record holding that number. Telegram
vouches for the number, so it is better evidence than anything they could type,
and a contact card describing somebody else is refused — a card can be forwarded
from an address book, so only one describing the sender counts.

This is the fallback. The link is what to hand out: one tap, nothing typed, and
no number to collect or store.

A chat already connected to a speaker cannot redeem an invite for a different
one — the sender is recognised before onboarding is reached. Re-pointing someone
at a new record means clearing the old chat id first.

Then send a test question and watch it land. Leave it an hour and send a second
one cold — that is what catches an Android battery manager.

For that first run, `bin/rails telegram:poll` on a laptop is enough. The webhook
is only needed once it has to work while nobody is watching.

## How it fits together

| | |
|---|---|
| `Telegram::Client` | the four Bot API calls this app makes |
| `Telegram::DeliverQuestion` | sends a question |
| `Telegram::InboundMessage` | one update, and who sent it |
| `Telegram::Poller` | long polling, for local runs — same path as the webhook |
| `User#telegram_invite_link` | the link to send a new speaker |
| `ProcessInbound` | shared with WhatsApp — decides what arriving means |
| `RecordAnswer` | shared — files a voice note as the answer |
| `OpusVoiceNote` | shared — guarantees ogg/opus |
| `QuestionTransport` | picks between this and WhatsApp |

Inbound updates are secret-checked and handled idempotently, since Telegram
redelivers anything it does not get a 200 for. Message ids are stored prefixed
with their channel: a Telegram message id is only unique within its chat, and
both transports' ids share one uniquely-indexed column.
