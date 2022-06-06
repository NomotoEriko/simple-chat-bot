# AWS の lambda function として動かす場合のサンプルコード

require 'json'
require 'net/http'
require 'uri'
require 'base64'
require_relative 'flow'

SLACK_WEBHOOK_URL = URI.parse(ENV["SLACK_WEBHOOK_URL"])

def lambda_handler(event:, context:)
  qs = parse_qs(event)
  unless qs['token'] == ENV["SLACK_TOKEN"]
    return { statusCode: 200, body: 'ERROR: unauthorized' }
  end

  case qs['type']
  when 'url_verification'
    { statusCode: 200, body: JSON.dump({"challenge" => qs['challenge']}) }
  when 'event_callback'
    return { statusCode: 404, body: 'invalid message' } unless qs.dig('event', 'text').include?('hi')
    post_message(message(qs.dig('event', 'user')))
    { statusCode: 200, body: 'event_callback succeed' }
  when 'block_actions'
    post_message(message(qs.dig('user', 'id'), qs.dig('actions', 0, 'value')))
    { statusCode: 200, body: 'block_actions succeed' }
  end
end

def post_message(msg)
  Net::HTTP.post(
    SLACK_WEBHOOK_URL,
    JSON.dump(msg),
    { 'Content-type': 'application/json' }
  )
end

def parse_qs(event)
  body = event['body']
  body = Base64.decode64(body) if [true, 'true', 'True'].include?(event['isBase64Encoded'])
  body = URI::decode_www_form(body).to_h['payload'] if body.include?('payload')
  query = JSON.parse(body)
  query
end

def message(user, value=nil)
  responce_text, next_values = Flow.new(user, value).next_action

  blocks = [{
    "type": "section",
    "text": {
      "type": "plain_text",
      "text": responce_text,
      "emoji": true
    }
  }]
  if next_values.count > 0
    blocks.push(
      {
        "type": "actions",
        "elements": next_values.map do |(text, value)|
          {
            "type": "button",
            "text": {
              "type": "plain_text",
              "text": text,
              "emoji": true
            },
            "value": value,
            "action_id": value
          }
        end
      }
    )
  end
  { "blocks": blocks }
end
