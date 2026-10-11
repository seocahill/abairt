# WhatsApp questions

Learners record a question on the site. It reaches a native speaker as a
WhatsApp voice note. They hold the mic button and reply. That reply comes back
to the learner as the answer.

The speaker's entire interface is WhatsApp. They never see a web page, never log
in, never type a command. Everything below exists to keep it that way.

## The one rule

**A speaker holds one question at a time.** They are not sent a second question
until the first is answered.

This is not a throttle, it is what makes the whole thing work: because they are
only ever holding one question, whatever voice note they send back is
unambiguously the answer to it. No ids, no keywords, no quote-replying, nothing
for them to get wrong.

`QuestionQueue` is that rule, and it is the piece to be careful with.

## The pieces

| | |
|---|---|
| `Question` | asker, speaker, the question audio, the answer audio, status |
| `QuestionQueue` | one at a time — sends the next question if the speaker is free |
| `QuestionRouter` | picks the speaker with the shortest backlog |
| `Whatsapp::Client` | the four Cloud API calls this app makes |
| `Whatsapp::ProcessInbound` | decides whether an inbound message is an answer |
| `Whatsapp::DeliverQuestion` | sends a question, or nudges when the window is shut |
| `Whatsapp::AudioForWhatsapp` | guarantees ogg/opus |

## Two platform constraints that shape the design

**The 24 hour window.** WhatsApp only allows free-form messages — audio
included — within 24 hours of the speaker's last message to us. Outside it, the
only thing permitted is an approved template, and **templates cannot carry
audio**. So when the window is shut, `Whatsapp::DeliverQuestion` sends a nudge
template with a quick-reply button instead. One tap reopens the window and the
voice note follows immediately. The question stays `waiting` until the audio
actually goes out.

In practice a speaker who answers regularly keeps their own window open and
never sees a nudge.

**ogg/opus or nothing.** WhatsApp renders ogg/opus as a playable voice bubble
and every other format as a file attachment. A file attachment is a dead end for
an elderly user, so `Whatsapp::AudioForWhatsapp` is not optional. Browsers record
webm/opus, which is the same audio in a different container, so the usual case is
a stream copy rather than a re-encode. Requires `ffmpeg` with `libopus`.

## Setting it up

### 1. Credentials

Add under `whatsapp:` in `rails credentials:edit`, or as environment variables:

| Credential | Env var | What it is |
|---|---|---|
| `access_token` | `WHATSAPP_ACCESS_TOKEN` | System user token from Meta |
| `phone_number_id` | `WHATSAPP_PHONE_NUMBER_ID` | The business number's id |
| `app_secret` | `WHATSAPP_APP_SECRET` | Signs inbound webhooks |
| `verify_token` | `WHATSAPP_VERIFY_TOKEN` | Any string; used once at subscription |
| `api_version` | `WHATSAPP_API_VERSION` | Optional, defaults to `v23.0` |

The number connected to the Cloud API **cannot** also be used in the normal
WhatsApp app. It must be a number nobody uses personally.

### 2. Webhook

Point the app's webhook at `https://abairt.com/api/whatsapp/webhook` and
subscribe to the `messages` field. Meta calls `GET` once with a challenge; the
app answers it from `verify_token`. Every `POST` after that is signature-checked
against `app_secret` and rejected if it does not match.

### 3. The nudge template

Submit a template named **`ceist_nua`** in Irish (`ga`) for approval, with a
quick-reply button. Approval is not instant and nothing outside the 24 hour
window works until it exists. Keep the text to one short line — many older
native speakers are fluent but read Irish slowly, so the words carry no content,
the button does the work.

### 4. The speaker

Created in admin by hand — they never fill in a form:

```ruby
User.create!(
  name: "...",
  phone_number: "353861234567",   # E.164, no +
  role: :speaker,
  answers_questions: true,
  whatsapp_opted_in_at: Time.current,
  confirmed: true
)
```

Meta requires demonstrable opt-in but does not care which channel it came
through, so consent gathered on a phone call is fine — record when and how.

Speakers have no email address and no password. There is nothing for them to
forget.

### 5. First run

Ring them, explain it, then send a test question yourself and stay on the phone
while they answer it. The first attempt has to succeed.

## The learner's side

Learners never touch WhatsApp. They install the site to their home screen and
hold one button.

The questions arrive spontaneously — mid-conversation, one hand free — so the
whole learner side is built around three actions: **tap the icon, hold the
button, let go.** The question uploads on release; there is no send step.

* `/questions/new` is the one screen, and the PWA's `start_url`
* `voice_question_controller.js` is the press-and-release interaction. It
  auto-stops at 60 seconds and discards anything under 0.4s as a stray tap
* `/manifest` and `/service-worker` are what make the browser offer "Add to
  Home Screen". Their formats are pinned in `routes.rb` rather than negotiated
  off the Accept header, which is Rails' default and 500s for a client asking
  for `text/html`

### Passwords

A magic link is unusable on a phone mid-task — fetching a login link from email
is exactly the friction this is meant to remove. So:

* `has_secure_password validations: false` on `User`, because most users never
  get a password (speakers are created with only a phone number) and the magic
  link still works for everyone
* signing in sets a **permanent signed cookie** holding a `remember_token`.
  `Authentication#resume_session_from_cookie` uses it to repopulate
  `session[:user_id]`, so everything already reading the session is unchanged
* regenerating the token signs every device out; logout does this

Set one at `/password/edit` after signing in by magic link once.

## Watching it

`/admin/questions` shows the backlog, who is holding what, and whether each
speaker's 24 hour window is open. **Check queue** re-runs `QuestionQueue` for a
speaker by hand if something looks stuck.

Nothing chases a speaker who does not reply. A question sits as `sent`
indefinitely and shows up in admin. That is deliberate — no timeouts, no
reminders, no penalties.

## Debugging from the console

```ruby
speaker = User.answering.first
QuestionQueue.new(speaker).outstanding    # what they are holding
QuestionQueue.new(speaker).deliver_next   # send the next one, if they are free
speaker.whatsapp_window_open?             # can we send audio at all?
```
