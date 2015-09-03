if window?
  require './polyfill'

b = require 'b-assert'
zock = require 'zock'

Proxy = require '../src'

describe 'Proxy', ->
  unless window?
    return

  it 'reads from serialized cache', ->
    requestCount = 0
    window['STREAM_PROXY'] = {
      cache:
        '{\"x\":\"1\"}__z__http://x.com/x': {'y': 'z'}
    }

    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      proxy = new Proxy()
      proxy.stream 'http://x.com/x', {x: '1'}
      .take(1).toPromise()
      .then (res) ->
        delete window['STREAM_PROXY']
        b res?.y, 'z'
        b requestCount, 0
