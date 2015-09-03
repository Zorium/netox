if window?
  require './polyfill'

assert = require 'assert'
zock = require 'zock'

Proxy = require '../src'

describe 'Proxy', ->
  it 'Simple GET request', ->
    zock
      .base 'http://x.com'
      .get '/x'
      .reply {y: 'z'}
    .withOverrides ->
      proxy = new Proxy()
      proxy.stream 'http://x.com/x'
      .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'

  it 'Simple POST request', ->
    zock
      .base 'http://x.com'
      .post '/x'
      .reply {y: 'z'}
    .withOverrides ->
      proxy = new Proxy()
      proxy.stream 'http://x.com/x', {method: 'POST'}
      .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'

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
      proxy = new Proxy()
      proxy.stream 'http://x.com/x'
      .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'
        proxy.stream 'http://x.com/x'
        .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 1
        proxy.stream 'http://x.com/x', {method: 'POST'}
        .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 2
        proxy.stream 'http://x.com/x', {method: 'POST'}
        .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 2

  it 'is lazy', ->
    requestCount = 0

    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      proxy = new Proxy()
      stream = proxy.stream 'http://x.com/x'
      assert.equal requestCount, 0

      stream.take(1).toPromise()
      .then (res) ->
        assert.equal requestCount, 1
        assert.equal res?.y, 'z'

  it 'doesn\'t cache fetch requests', ->
    requestCount = 0
    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      proxy = new Proxy()
      proxy.fetch 'http://x.com/x'
      .then (res) ->
        assert.equal res?.y, 'z'
        proxy.fetch 'http://x.com/x'
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 2

  it 'invalidates cache after fetch request', ->
    requestCount = 0
    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      proxy = new Proxy()
      proxy.stream 'http://x.com/x'
      .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 1
        proxy.fetch 'http://x.com/x'
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 2
        proxy.stream 'http://x.com/x'
        .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 3

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
      proxy = new Proxy()
      stream = proxy.stream 'http://x.com/x'
      count = 0
      stream.subscribe (res) ->
        count += 1
        assert.equal count, res.count

      # rx streams consume late
      skipTicks = ->
        new Promise (resolve) ->
          setTimeout resolve, 1 # not zero because firefox fires too quickly

      stream.take(1).toPromise()
      .then ->
        proxy.fetch 'http://x.com/invalidate', {method: 'POST'}
      .then skipTicks

      .then ->
        proxy.fetch 'http://x.com/invalidate', {method: 'POST'}
      .then skipTicks
      .then ->
        proxy.fetch 'http://x.com/invalidate', {method: 'POST'}
      .then skipTicks
      .then ->
        stream.take(1).toPromise()
      .then (res) ->
        assert.equal res.count, 4
        assert.equal count, 4

  it 'doesn\'t invalidate cache when fetch has isCacheable flag', ->
    requestCount = 0
    zock
      .base 'http://x.com'
      .get '/x'
      .reply ->
        requestCount += 1
        {y: 'z'}
    .withOverrides ->
      proxy = new Proxy()
      proxy.stream 'http://x.com/x'
      .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 1
        proxy.fetch 'http://x.com/x', {isCacheable: true}
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 2
        proxy.stream 'http://x.com/x'
        .take(1).toPromise()
      .then (res) ->
        assert.equal res?.y, 'z'
        assert.equal requestCount, 2
