_ = require 'lodash'
Rx = require 'rx-lite'
URL = require 'url-parse'
request = require 'clay-request'

Promise = if window?
  window.Promise
else
  # TODO: remove once v8 is updated
  # Avoid webpack include
  bluebird = 'bluebird'
  require bluebird

SERIALIZATION_KEY = 'NETOX'
SERIALIZATION_EXPIRE_TIME_MS = 1000 * 10 # 10 seconds

module.exports = class Netox
  constructor: ({@headers} = {}) ->
    @headers ?= {}
    @serializationCache = new Rx.BehaviorSubject {}
    @timingListeners = []

    loadedSerialization = window?[SERIALIZATION_KEY]
    expires = loadedSerialization?.expires
    if expires? and \
    # Because of potential clock skew we check around the value
    Math.abs(Date.now() - expires) < SERIALIZATION_EXPIRE_TIME_MS
      pageCache = loadedSerialization?.cache or {}
      @cache = _.mapValues pageCache, (res, key) ->
        [optsString, url] = key.split '__z__'
        opts = JSON.parse optsString

        requestStreams = new Rx.ReplaySubject(1)
        requestStreams.onNext Rx.Observable.just res
        stream = requestStreams.switch()

        {stream, requestStreams, url, proxyOpts: opts}
    else
      @cache = {}

  _invalidateCache: =>
    @serializationCache.onNext {}
    @cache = _.transform @cache, (cache, val, key) =>
      {stream, requestStreams, url, proxyOpts} = val

      cachedSubject = null
      requestStreams.onNext @_deferredRequestStream url, proxyOpts, (res) =>
        nextCache = _.clone @serializationCache.getValue()
        nextCache[key] = res
        @serializationCache.onNext nextCache

      cache[key] = {stream, requestStreams, url, proxyOpts}
    , {}

  _mergeHeaders: (opts) =>
    # Only forward a subset of headers
    _.merge
      headers: _.pick @headers, [
        'cookie'
        'user-agent'
        'accept-language'
        'x-forwarded-for'
      ]
    , opts

  onTiming: (fn) =>
    @timingListeners.push fn

  _emitTiming: ({url, elapsed}) =>
    parsed = new URL(url)
    parsed.set 'query', null
    parsed.set 'hash', null
    _.map @timingListeners, (fn) ->
      fn {url: parsed.toString(), elapsed}

  _deferredRequestStream: (url, opts, onresult) =>
    cachedPromise = null
    Rx.Observable.defer =>
      unless cachedPromise?
        startTime = Date.now()
        cachedPromise = request url, opts
        .then (res) =>
          endTime = Date.now()
          elapsed = endTime - startTime
          if opts?.isTimed
            @_emitTiming {url, elapsed}
          onresult res
          return res
      return cachedPromise

  getSerializationStream: =>
    @serializationCache
    .map (cache) ->
      serialization = {
        cache: cache
        expires: Date.now() + SERIALIZATION_EXPIRE_TIME_MS
      }

      "window['#{SERIALIZATION_KEY}'] = #{JSON.stringify(serialization)};"

  fetch: (url, opts = {}) =>
    proxyOpts = @_mergeHeaders opts
    request url, proxyOpts
    .then (res) =>
      unless opts.isIdempotent
        @_invalidateCache()
      return res

  stream: (url, opts = {}) =>
    cacheKey = JSON.stringify(opts) + '__z__' + url
    cached = @cache[cacheKey]

    if cached?
      return cached.stream

    proxyOpts = @_mergeHeaders opts

    requestStreams = new Rx.ReplaySubject(1)
    requestStreams.onNext @_deferredRequestStream url, proxyOpts, (res) =>
      nextCache = _.clone @serializationCache.getValue()
      nextCache[cacheKey] = res
      @serializationCache.onNext nextCache
    stream = requestStreams.switch()

    @cache[cacheKey] = {stream, requestStreams, url, proxyOpts}
    return @cache[cacheKey].stream
