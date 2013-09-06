# Description:
#   Quickly start a hangout
#
# Commands:
#   hubot hangout - returns URL for quick hangout. 

module.exports = (robot) ->

  robot.respond /hangout/i, (msg) ->
    msg.send 'http://plus.google.com/hangouts/_'
