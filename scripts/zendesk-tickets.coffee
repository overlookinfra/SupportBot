# Show unsolved Zendesk tickets.
#
# You need to set the following variables:
#   HUBOT_ZENDESK_USER=
#   HUBOT_ZENDESK_PASSWORD=
#   HUBOT_ZENDESK_SUBDOMAIN=
#
# Optional:
#   HUBOT_ZENDESK_USER_ID_(.*)=
#   HUBOT_ZENDESK_RELEASE_BUILD_URL=
#
# show [me] [<limit> [of]] [<assignee>'s|my] [<tag>] tickets [for <release>] [about <query>] -- Shows unsolved Zendesk tickets.

_     = require "underscore"
_s    = require "underscore.string"
async = require "async"

class Status
  @SOLVED: 3

class TicketQuery
  ASK_REGEX = ///
    show\s            # Start's with 'show'
    (me)?\s*          # Optional 'me'
    (\d+|\d+\sof)?\s* # 'N of' -- 'of' is optional but ambiguous unless assignee is named
    (\S+'s|my)?\s*    # Assignee's name or 'my'
    (\S+)?\s*         # Optional tag
    tickets\s*        # 'tickets'
    (for\s\S+)?\s*    # Optional 'for <release>'
    (about\s.+)?      # Optional 'about <query>'
  ///i

  @respond: (robot) ->
    robot.respond ASK_REGEX, (msg) ->
      new TicketQuery(msg).run()

  constructor: (@msg) ->
    [@me, @limit, @assignee, @tag, @build, @query] = @msg.match[1..]
    @limit = parseInt @limit.replace(" of", "") if @limit?
    @assignee = @assignee.replace("@", "").replace("'s", "") if @assignee?
    @build = @build.replace("for ", "") if @build?
    @query = @query.replace("about ", "") if @query?

  run: ->
    # First resolve parameters
    @resolve (err) =>
      return @msg.send err if err?
      @get_tickets (tickets) =>
        @receive tickets

  # Resolve fields asynchronously
  resolve: (cb) ->
    # Have to lift the @resolve_* functions into this context so they behave
    # like methods of this.
    async.parallel {
        build: ((cb) => @resolve_release_build cb),
        assignee_id: ((cb) => @resolve_assignee_id cb)
      },
      (err, results) =>
        return cb err if err?
        @build = results.build if results.build?
        @assignee_id = results.assignee_id if results.assignee_id?
        cb err, results

  resolve_release_build: (cb) ->
    return cb() unless @build? and @build is "release"
    @msg.http(process.env["HUBOT_ZENDESK_RELEASE_BUILD_URL"])
        .get() (err, res, body) ->
          cb err, body

  resolve_assignee_id: (cb) ->
    return cb() unless @assignee?
    # Try to find the user id in the environment
    name = if @assignee is "my" then @msg.message.user.name else @assignee
    name = name.toLowerCase()
    id_from_env = process.env["HUBOT_ZENDESK_USER_ID_#{name.replace(/\s/g, '_').toUpperCase()}"]
    return cb null, id_from_env if id_from_env?

    # Search the first organization we find for a username resembling the mentioned assignee.
    @get_json '/organizations', {}, (orgs) =>
      return cb "Could not find your Zendesk organization" if _.isEmpty orgs
      @get_json "/organizations/#{orgs[0].id}/users", {}, (users) =>
        user = _.find users, (u) -> _s.include u.name.toLowerCase(), name
        if user?
          cb null, user.id
        else
          cb "Could not find a Zendesk user in your organization whose name begins with '#{name}'"

  params: ->
    unless @ps?
      @ps = {}
      for condition, i in @conditions()
        for key, val of condition
          if key is "values"
            for value, value_i in val
              @ps["sets[1][conditions][#{i+1}][value][#{value_i}]"] = value
          else
            @ps["sets[1][conditions][#{i+1}][#{key}]"] = val
    @ps

  conditions: -> _.compact [
    { source: 'status_id', operator: 'less_than', values: [Status.SOLVED] },
    { source: 'assignee_id', operator: 'is', values: [@assignee_id] } if @assignee?,
    { source: 'current_tags', operator: 'includes',  values: [@tag] } if @tag?,
    { source: 'description_includes_word', operator: 'is',  values: [@query] } if @query?
  ]

  get_json: (path, params={}, success) ->
    [user, pass] = [process.env.HUBOT_ZENDESK_USER, process.env.HUBOT_ZENDESK_PASSWORD]
    authorization = "Basic " + new Buffer("#{user}:#{pass}").toString("base64")

    @msg.http("https://#{process.env.HUBOT_ZENDESK_SUBDOMAIN}.zendesk.com#{path}")
        .headers(Authorization: authorization, Accept: "application/json")
        .query(params)
        .get() (err, res, body) =>
          return @msg.send "Zendesk says: #{err}" if err?
          success JSON.parse body

  # Gets as many pages of tickets as possible, then calls receive.
  get_tickets: (cb, pages_received=[]) ->
    params = @params()
    params.page = pages_received.length + 1
    @get_json '/rules/search', params, (page) =>
      if page.count is 0
        # There are no more results to get.
        for {count, tickets} in pages_received
          page.count += count
          page.tickets = page.tickets.concat tickets
        cb page
      else
        # Save this page and get the rest.
        pages_received.push page
        @get_tickets cb, pages_received

  receive: (data) ->
    tickets = data.tickets

    if @build?
      tickets = _.filter tickets, (t) => _s.include t.recipient, @build

    tickets = _.first tickets, @limit if @limit?
    return @msg.send "No tickets found." if _.isEmpty tickets

    for ticket in tickets
      url = "http://#{process.env.HUBOT_ZENDESK_SUBDOMAIN}.zendesk.com/tickets/#{ticket.nice_id}"
      @msg.send "[#{ticket.nice_id}] #{ticket.subject} - #{url}"

module.exports = TicketQuery.respond

