# How the speaker receives questions

The learner's side is settled: a PWA, one button, record and send. This is
about the other end — how a question reaches an elderly native speaker and how
his answer comes back. It is the live question, and the one with no obviously
right answer.

`QuestionQueue`, `QuestionRouter`, the draft/send flow and the admin backlog
never knew what the transport was. Only the `Whatsapp::*` namespace does. So
this is a swappable decision, and the point of writing it down is that the
reasoning is harder to recover than the code.

## Decision

**Telegram, as a proof of concept.** Then decide whether a native app is worth
building.

## Why not WhatsApp

It works, it is built (#59), and it is the only option that asks nothing of the
speaker — he already has it. It loses on what it asks of us.

To send a single voice note to one man you need: a Facebook account, a Meta
business portfolio, a developer app, a system user with three permissions, an
app secret, a template submitted for approval, and a payment method on file
with Meta. Business verification turns out to be unnecessary — unverified
accounts get 250 unique recipients per rolling 24 hours, and replies inside an
open window do not count — but the display name is then barely shown, so the
speaker sees a bare phone number in his chat list until he saves the number as
a contact.

Going through a BSP does not avoid this. 360dialog documents that Embedded
Signup uses Facebook Login and requires your Facebook profile; Twilio routes
onboarding through a Meta Business Manager. Managed Meta Accounts would avoid a
personal profile but are gated to enterprise customers through an IdP.

Since 1 October 2026 service messages are billable, with 1,000 free per number
per month. Below that allowance nothing is charged, but without a payment
method in Meta's Billing Hub delivery stops once it is used — the failure mode
is silence, not an invoice.

None of that is a technical objection. It is a decision not to hold that
relationship for this.

## Why Telegram

- A bot is five minutes with @BotFather. No verification, no entity, no card,
  no approval of any kind, free.
- `sendVoice` wants OGG/OPUS, which is exactly what the existing audio
  guarantee already produces. That logic carries over unchanged.
- No 24 hour window, so no templates, no nudge, no `ceist_nua` approval wait.
- `getUpdates` long polling means local development needs no tunnel at all.
- Webhook auth is a `secret_token` echoed in `X-Telegram-Bot-Api-Secret-Token`
  — a string comparison, not an HMAC over the body.
- Wideband opus, so no loss of the pronunciation detail the whole product
  exists to capture.

Device support is not a concern: Telegram needs iOS 13 or Android 5, WhatsApp
needs iOS 15.1 (15.5 from 30 November 2026) and Android 6. Any phone running
WhatsApp runs Telegram with room spare, and Telegram is the less likely of the
two to raise its floor under him.

### Telegram becomes the Abairt app

The useful accident: if his Telegram contains essentially one chat, there is no
wrong thread to reply in, and every notification he ever gets from it is a
learner's question rather than one banner among forty.

Not *exactly* one chat, and not an enforcement mechanism — registering creates a
Telegram service chat, which is where his login code arrives, and Saved Messages
sits alongside it. The invariant the design rests on — *whatever voice note
comes back is the answer to the one question he holds* — is still `QuestionQueue`
and nothing else. What the single chat buys is that he cannot plausibly reply in
the wrong place, which is a usability property, not a correctness one.

Set the bot's name to Abairt with `/setname`, give it the logo with
`/setuserpic`, and leave `/setcommands` empty so there is no slash menu. The
word Telegram barely appears.

## Setting up his phone — one visit

1. Install, register with his number, SMS code.
2. **Deny the contacts permission.** Allow it and Telegram trawls his address
   book, finds people he knows and starts showing suggestions — and it stops
   being a single-purpose app.
3. **Lock down who can reach him.** Settings → Privacy: messages, calls and
   group invites to Nobody or My Contacts. The default is everybody, and a fresh
   number attracts spam — a likelier way this stops being a single-purpose app
   than the contacts permission is.
4. Open `t.me/<bot>` and tap **Start**. A bot cannot message someone who has
   not started it, so this is the opt-in, and it is better than Meta's rules:
   the consent *is* the mechanism, and it happens in front of you.
5. **Tap the one button that shares his number.** This is what connects his chat
   to the speaker record: the number is matched against the one we already hold.
   Telegram vouches for it, so it is better evidence than anything he could
   type, and a contact card describing somebody else is refused.
6. **Tap Allow on the notification prompt.** The main failure mode — dismissing
   prompts is a reflex. Push is APNs/FCM, so it arrives whether the app is
   running or not, but only if this is granted.
7. Check the phone is not silent, and not caught in a Focus mode or iOS's
   Scheduled Summary.
8. On Android, exclude Telegram from battery optimisation. Stock Android
   honours high-priority FCM in Doze, but manufacturer skins restrict apps that
   are rarely opened. Verify on the actual handset.
9. Send a test question and watch it land. Then leave it an hour and send a
   second one cold, which is what catches the battery manager.
10. Optional: a Shortcuts icon named "Abairt" opening `tg://resolve?domain=<bot>`
    puts it on his home screen under the right name. Android does chat shortcuts
    natively.

Until step 5 there is no chat id, so `User.answering` leaves him out and nothing
is routed to him — a question with nowhere to go would otherwise sit `waiting`
with no explanation.

## The alternatives, and why they lost

**A call-in line (Twilio).** He dials a number, hears the queued question,
records an answer, hangs up — or we ring him. No app, no account, no install,
no smartphone needed, and no upload to fail. The most familiar interface of
any option and the most reliable. Ireland asks an individual for photo ID and
proof of address with an Eircode, not a company number, so there is no
"Abairt is not a business" problem.

It loses on audio: PSTN is narrowband, and narrowband eats the high frequencies
that carry sibilants and fricatives. For answers about pronunciation that is a
real loss, not a cosmetic one. Worth revisiting if Telegram's install friction
turns out to matter more than the fidelity.

**Our own PWA for the speaker.** Tempting, since the learner side already is
one. The blocker is not notifications — web push has worked since iOS 16.4 for
home-screen web apps, and the EU removal was announced and then reversed.

The blocker is that **iOS Safari has no Background Sync**. If his upload fails
on patchy rural signal there is no OS-level queue to retry it; the workaround
is to flush on next open, which requires him to come back, which he will not do
because from his side it looked sent. WhatsApp and Telegram both have a native
outbound queue that retries for hours. That is not reproducible on iOS, and
silent loss of an answer is the one failure that would stop him bothering.

**Signal.** No official bot API. signal-cli is not something to hang this on.

**SMS/MMS.** Dead for audio. **RCS.** Google verification, Android only.

## Decided since

**WhatsApp is gone.** It was built and it worked, but carrying a second
transport meant a channel enum, a picker in admin, a webhook nobody called and
a set of columns serving a 24 hour window that does not exist here. One
transport is a smaller thing to reason about, and the WhatsApp adapter is in
the history (PR #59) if the trade-offs ever shift.


**The channel is a `channel` enum on `User` plus a `telegram_chat_id`**, which
is built. `QuestionTransport` is the only thing that reads it, so one speaker
can be on Telegram and another on WhatsApp with the queue unchanged.

`ProcessInbound`, `RecordAnswer` and the audio guarantee turned out to be
genuinely shared rather than WhatsApp-shaped — what differs between the two
transports is only who a sender is, how to fetch their audio, and what an
unknown sender means, all of which the message object answers. The nudge and the
24 hour window stayed behind in `Whatsapp::` where they belong.

One wrinkle worth knowing: `getUpdates` and `setWebhook` are mutually exclusive,
so local development wants a second bot rather than `deleteWebhook` against the
one production is using. `bin/rails telegram:poll` does the polling, through the
same path the webhook uses.

## Still not decided

- Payments. `send_to_speaker!` is the chokepoint a balance check hangs off.
- Whether to keep a call-in line in reserve. The audio argument against it has
  not changed, but it remains the only option that asks nothing at all of the
  speaker.
