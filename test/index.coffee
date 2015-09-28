if window?
  require './polyfill'

_ = require 'lodash'
b = require 'b-assert'
zock = require 'zock'

Netox = require '../src'

describe 'Netox', ->
  it 'Simple GET request', ->
    zock
      .base 'http://x.com'
      .get '/x'
      .reply {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      netox.stream 'http://x.com/x'
      .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'

  it 'Simple POST request', ->
    zock
      .base 'http://x.com'
      .post '/x'
      .reply {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      netox.stream 'http://x.com/x', {method: 'POST'}
      .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'

  it 'Caches requests', ->
    requestCount = 0

    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
      .post '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      netox.stream 'http://x.com/x'
      .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        netox.stream 'http://x.com/x'
        .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 1
        netox.stream 'http://x.com/x', {method: 'POST'}
        .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 2
        netox.stream 'http://x.com/x', {method: 'POST'}
        .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 2

  it 'is lazy', ->
    requestCount = 0

    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      stream = netox.stream 'http://x.com/x'
      b requestCount, 0

      stream.take(1).toPromise()
      .then (res) ->
        b requestCount, 1
        b res?.y, 'z'

  it 'doesn\'t cache fetch requests', ->
    requestCount = 0
    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      netox.fetch 'http://x.com/x'
      .then (res) ->
        b res?.y, 'z'
        netox.fetch 'http://x.com/x'
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 2

  it 'invalidates cache after fetch request', ->
    requestCount = 0
    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      netox.stream 'http://x.com/x'
      .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 1
        netox.fetch 'http://x.com/x'
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 2
        netox.stream 'http://x.com/x'
        .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 3

  it 'pushes new data to streams on cache invalidation', ->
    requestCount = 0
    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z', count: requestCount}
      .post '/invalidate'
      .reply 204
    .withOverrides ->
      netox = new Netox()
      stream = netox.stream 'http://x.com/x'
      count = 0
      stream.subscribe (res) ->
        count += 1
        b count, res.count

      # rx streams consume late
      skipTicks = ->
        new Promise (resolve) ->
          setTimeout resolve, 1 # not zero because firefox fires too quickly

      stream.take(1).toPromise()
      .then ->
        netox.fetch 'http://x.com/invalidate', {method: 'POST'}
      .then skipTicks

      .then ->
        netox.fetch 'http://x.com/invalidate', {method: 'POST'}
      .then skipTicks
      .then ->
        netox.fetch 'http://x.com/invalidate', {method: 'POST'}
      .then skipTicks
      .then ->
        stream.take(1).toPromise()
      .then (res) ->
        b res.count, 4
        b count, 4

  it 'doesn\'t invalidate cache when fetch has isIdempotent flag', ->
    requestCount = 0
    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      netox.stream 'http://x.com/x'
      .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 1
        netox.fetch 'http://x.com/x', {isIdempotent: true}
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 2
        netox.stream 'http://x.com/x'
        .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        b requestCount, 2

  it 'passes serverHeaders with requests, while still caching', ->
    requestCount = 0

    zock
      .base 'http://x.com'
      .get '/x'
      .reply (req) ->
        requestCount += 1
        {y: 'z', headers: req.headers}
    .withOverrides ->
      netox = new Netox({
        headers:
          'cookie': '1'
          'user-agent': '2'
          'accept-language': '3'
          'x-forwarded-for': '4'
          'not-used': '5'
      })
      netox.stream 'http://x.com/x', {headers: {'user-x': 'y'}}
      .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        b res.headers['user-x'], 'y'
        b _.includes _.keys(res.headers), 'cookie'
        b res.headers['user-agent'], '2'
        b res.headers['accept-language'], '3'
        b res.headers['x-forwarded-for'], '4'
        b res.headers['not-used'], undefined
        b requestCount, 1
        netox.stream 'http://x.com/x', {headers: {'user-x': 'y'}}
        .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        b res.headers['user-x'], 'y'
        b res.headers['x-forwarded-for'], '4'
        b requestCount, 1
        netox.fetch 'http://x.com/x', {headers: {'user-x': 'y'}}
      .then (res) ->
        b res?.y, 'z'
        b res.headers['user-x'], 'y'
        b res.headers['x-forwarded-for'], '4'
        b requestCount, 2

  it 'serializes cache', ->
    zock
      .base 'http://x.com'
      .get '/x'
      .reply {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      netox.stream 'http://x.com/x', {x: '1'}
      .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'
        netox.getSerializationStream()
        .take(1).toPromise()
      .then (serialization) ->
        b _.includes serialization, 'window[\'NETOX\'] ='

  it 'invalidates serialization cache when invalidating cache', ->
    zock
      .base 'http://x.com'
      .get '/x'
      .reply {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      netox.stream 'http://x.com/x', {x: '1'}
      .take(1).toPromise()
      .then ->
        netox.fetch 'http://x.com/x'
      .then ->
        netox.getSerializationStream()
        .take(1).toPromise()
      .then (serialization) ->
        b _.includes serialization, '"cache":{}'

  it 'emits timing events', ->
    zock
      .base 'http://x.com'
      .get '/x'
      .reply {y: 'z'}
    .withOverrides ->
      netox = new Netox()
      timingPromise = new Promise (resolve, reject) ->
        netox.onTiming ({url, elapsed}) ->
          try
            b url, 'http://x.com/x'
            b elapsed >= 0 and elapsed < 5 # arbitrary bounds for test
            resolve null
          catch error
            reject error

      netox.stream 'http://x.com/x?y=x#xxx', {isTimed: true}
      .take(1).toPromise()
      .then (res) ->
        b res?.y, 'z'

      return timingPromise
