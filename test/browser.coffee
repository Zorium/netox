if window?
  require './polyfill'

b = require 'b-assert'
zock = require 'zock'

Netox = require '../src'

describe 'Netox', ->
  unless window?
    return

  it 'reads from serialized cache', ->
    requestCount = 0
    window['NETOX'] = {
      expires: Date.now() - 1000 # 1s past
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
      netox = new Netox()
      netox.stream 'http://x.com/x', {x: '1'}
      .take(1).toPromise()
      .then (res) ->
        delete window['NETOX']
        b res?.y, 'z'
        b requestCount, 0

  it 'doesnt use expired cache', ->
    requestCount = 0
    window['NETOX'] = {
      expires: Date.now() - 20 * 1000 # 20 sec past
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
      netox = new Netox()
      netox.stream 'http://x.com/x', {x: '1'}
      .take(1).toPromise()
      .then (res) ->
        delete window['NETOX']
        b res?.y, 'z'
        b requestCount, 1

  it 'doesnt use expired cache due to clock skew', ->
    requestCount = 0
    window['NETOX'] = {
      expires: Date.now() + 20 * 1000 # 20 sec future
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
      netox = new Netox()
      netox.stream 'http://x.com/x', {x: '1'}
      .take(1).toPromise()
      .then (res) ->
        delete window['NETOX']
        b res?.y, 'z'
        b requestCount, 1

  it 'doesnt use invalid cache (missing expires)', ->
    requestCount = 0
    window['NETOX'] = {
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
      netox = new Netox()
      netox.stream 'http://x.com/x', {x: '1'}
      .take(1).toPromise()
      .then (res) ->
        delete window['NETOX']
        b res?.y, 'z'
        b requestCount, 1
