# frozen_string_literal: true

# Raised by a transport's client when the other end would not cooperate.
#
# Both `Whatsapp::Client::Error` and `Telegram::Client::Error` descend from
# this, so the channel-agnostic services can rescue one thing. A question whose
# delivery raises stays `waiting` and goes out on the next attempt rather than
# wedging the queue.
class TransportError < StandardError; end
