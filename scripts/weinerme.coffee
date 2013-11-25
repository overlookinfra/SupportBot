# Description:
#   Displays a random weiner from mydailyweiner.tumblr.com
#
# Dependencies:
#   "tumblrbot": "0.1.0"
#
# Configuration:
#   HUBOT_TUMBLR_API_KEY - A Tumblr OAuth Consumer Key will work fine
#   HUBOT_MORE_WEINER - Show pizza whenever anyone mentions it (default: false)
#
# Commands:
#   hubot weiner - Shows a weiner
#
# Author:
#   deadops

tumblr = require 'tumblrbot'
WEINER = "mydailyweiner.tumblr.com"

module.exports = (robot) ->
  func = if process.env.HUBOT_MORE_WEINER then 'hear' else 'respond'
  robot[func](/weine+r+/i, (msg) ->
    tumblr.photos(WEINER).random (post) ->
      msg.send post.photos[0].original_size.url
  )
