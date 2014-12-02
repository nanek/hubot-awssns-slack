# Description:
#   Announce AWS SNS notifications to a slack room.
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   None
#
# Notes:
#   To use:
#     Setup http://hostname/hubot/awssns-slack/%23ROOMNAME as
#     your SNS notification endpoint.
#
#   http://docs.aws.amazon.com/sns/latest/dg/SendMessageToHttp.html
#
https = require 'https'
url   = require 'url'
bodyParser = require 'body-parser'

module.exports = (robot) ->

  # AWS SNS does not set the proper content-type header for JSON.
  # Therefore we have to parse the body ourselves.
  # https://forums.aws.amazon.com/message.jspa?messageID=418160
  #
  middleware = bodyParser.json type: 'text/plain'

  robot.router.post '/hubot/awssns-slack/:room', middleware, (req, res) ->
    room = req.params.room

    data = req.body

    # Example post data
    #
    # {
    #   "Type" : "Notification",
    #   "MessageId" : "22b80b92-fdea-4c2c-8f9d-bdfb0c7bf324",
    #   "TopicArn" : "arn:aws:sns:us-east-1:123456789012:MyTopic",
    #   "Subject" : "My First Message",
    #   "Message" : "Hello world!",
    #   "Timestamp" : "2012-05-02T00:54:06.655Z",
    #   "SignatureVersion" : "1",
    #   "Signature" : "EXAMPLEw6JRNwm1LFQL4ICB0bnXrdB8ClRMTQFGBqwLpGbM78tJ4etTwC5zU7O3tS6tGpey3ejedNdOJ+1fkIp9F2/LmNVKb5aFlYq+9rk9ZiPph5YlLmWsDcyC5T+Sy9/umic5S0UQc2PEtgdpVBahwNOdMW4JPwk0kAJJztnc=",
    #   "SigningCertURL" : "https://sns.us-east-1.amazonaws.com/SimpleNotificationService-f3ecfb7224c7233fe7bb5f59f96de52f.pem",
    #   "UnsubscribeURL" : "https://sns.us-east-1.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:us-east-1:123456789012:MyTopic:c9135db0-26c4-47ec-8998-413945fb5a96"
    # }
    #

    # Confirm the Subscription.
    if data.Type is 'SubscriptionConfirmation'
      confirmURL = url.parse data.SubscribeURL
      https.get confirmURL, (response) ->
        str = ''
        response.on 'data', (chunk) ->
          str += chunk
        response.on 'end', ->
          console.log str

    else
      topicName = data.TopicArn?.split(":").slice(-1)
      isAlert   = data.Subject?.match /ALARM/
      color     = if isAlert then "danger" else "good"
      prefix    = if isAlert then "Alert" else "Back to Normal"
      emoji     = if isAlert then ":warning:" else ":thumbsup:"

      fields = [
        title: data.Subject
        value: data.Message
        short: false
      ]

      fallback = "#{data.Subject}"

      robot.emit 'slack-attachment',
        message:
          room:       room
          username:   topicName
          icon_emoji: emoji
        content:
          text:     ''
          color:    color
          pretext:  ''
          fallback: fallback
          fields:   fields

    # Send back an empty response
    res.writeHead 204, { 'Content-Length': 0 }
    res.end()
