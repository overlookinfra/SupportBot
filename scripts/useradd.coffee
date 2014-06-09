# Description:
#   motivational user adds
#
# Commands:
#   hubot useradd - returns motivational useradd text. 

module.exports = (robot) ->

  robot.respond /useradd/i, (msg) ->
    msg.send 'http://www.familylobby.com/common/tt10478273fltt.gif'
