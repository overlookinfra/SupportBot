# Description:
#   Displays a random halloween gif from tumblr
#
# Dependencies:
#   "tumblrbot": "0.1.0"
#
# Configuration:
#   HUBOT_TUMBLR_API_KEY - A Tumblr OAuth Consumer Key will work fine
#   HUBOT_MORE_HALLOWEEN - Show halloween whenever anyone mentions it (default: false)
#
# Commands:
#   hubot halloween - Show a halloween gif
#
# Author:
#   revhazroot

tumblr = require 'tumblrbot'
HALLOWEEN = "http://hallowsween.tumblr.com/"

module.exports = (robot) ->
  func = if process.env.HUBOT_MORE_HALLOWEEN then 'hear' else 'respond'
  robot[func](/halloween/i, (msg) ->
    tumblr.photos(HALLOWEEN).random (post) ->
      msg.send post.photos[0].original_size.url
  )
