# Questions

A learner records a question. It reaches a native speaker as a voice note in
Telegram. They hold the mic button and reply, and that reply comes back to the
learner as the answer.

How it reaches the speaker is `telegram_setup.md`. Why Telegram and not
something else is `speaker_transport.md`. This is everything either side of the
transport.

## The one rule

**A speaker holds one question at a time.** They are not sent a second until the
first is answered.

This is not a throttle, it is what makes the whole thing work: because they are
only ever holding one question, whatever voice note comes back is unambiguously
the answer to it. No ids, no keywords, no quote-replying, nothing for them to
get wrong.

`QuestionQueue` is that rule, and it is the piece to be careful with.

## The pieces

| | |
|---|---|
| `Question` | asker, speaker, the question audio, the answer audio, status |
| `QuestionQueue` | one at a time — sends the next question if the speaker is free |
| `QuestionRouter` | picks the speaker with the shortest unanswered backlog |
| `ProcessInbound` | decides what an arriving message means |
| `RecordAnswer` | files a voice note as the answer |
| `OpusVoiceNote` | guarantees ogg/opus |
| `Telegram::*` | the transport — see `telegram_setup.md` |

`QuestionQueue`, `QuestionRouter` and the draft/send flow never name a
transport. Only `Telegram::` does.

## The learner's side

**Admins only, for now.** Asking a question spends a native speaker's time and,
once payments exist, real money. `QuestionsController` and `QuestionPolicy` both
say so — two places deliberately, so neither alone opens it by accident.

Learners never touch Telegram. They install the site to their home screen and
hold one button.

The questions arrive spontaneously — mid-conversation, one hand free — so the
whole learner side is built around three actions: **tap the icon, hold the
button, let go** — then listen back and send.

* `/questions/new` is the one screen, and the PWA's `start_url`
* `voice_question_controller.js` is the press-and-release interaction. It
  auto-stops at 60 seconds and discards anything under 0.4s as a stray tap
* releasing the button records a **draft**, it does not send. The learner plays
  it back and then taps Seol or Scrios. A recording made one-handed is often not
  the question you meant to ask, and once a question costs credits, sending
  unheard is the wrong default. Sending is `POST /questions/:id/delivery`
* `/manifest` and `/service-worker` are what make the browser offer "Add to
  Home Screen". Their formats are pinned in `routes.rb` rather than negotiated
  off the Accept header, which is Rails' default and 500s for a client asking
  for `text/html`

### What it looks like

| | | |
|---|---|---|
| ![Sign in](screenshots/1-sign-in.png) | ![Ask](screenshots/2-ask.png) | ![Recording](screenshots/3-recording.png) |
| Password first, magic link below | The whole learner side | Held down |
| ![Draft](screenshots/8-draft.png) | ![Sent](screenshots/9-sent.png) | ![Answers](screenshots/12-answer.png) |
| Play it back, Seol or Scrios | Queued once sent | Answers play in place |

### Passwords

A magic link is unusable on a phone mid-task — fetching a login link from email
is exactly the friction this is meant to remove. So:

* `has_secure_password validations: false` on `User`, because most users never
  get a password (speakers never sign in at all) and the magic link still works
  for everyone
* signing in sets a **permanent signed cookie** holding a `remember_token`.
  `Authentication#resume_session_from_cookie` uses it to repopulate
  `session[:user_id]`, so everything already reading the session is unchanged
* regenerating the token signs every device out; logout does this

Set one at `/password/edit` after signing in by magic link once.

## The founder's side

Speakers are created at **Users → New User**, which is the only place one can
come from: they have no email, no password and never see a web page. An
existing user can be promoted to a speaker by editing them. Their page carries
the invite link that connects them — see `telegram_setup.md`.

`/admin/questions` shows the backlog and who is holding what. **Check queue**
re-runs `QuestionQueue` for a speaker by hand if something looks stuck.

![Admin backlog](screenshots/7-admin-backlog.png)

Nothing chases a speaker who does not reply. A question sits as `sent`
indefinitely and shows up in admin. That is deliberate — no timeouts, no
reminders, no penalties.

## Debugging from the console

```ruby
speaker = User.answering.first
QuestionQueue.new(speaker).outstanding    # what they are holding
QuestionQueue.new(speaker).deliver_next   # send the next one, if they are free
speaker.telegram_invite_link              # nil once they have followed it
```
