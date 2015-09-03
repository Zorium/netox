_ = require 'lodash'
Rx = require 'rx-lite'
request = require 'clay-request'

Promise = if window?
  window.Promise
else
  # TODO: remove once v8 is updated
  # Avoid webpack include
  bluebird = 'bluebird'
  require bluebird

PROXY_SERIALIZATION_KEY = 'STREAM_PROXY'
# CACHE_EXPIRE_TIME_MS = 1000 * 10 # 10 seconds

deferredRequestStream = (url, opts, onresult) ->
  cachedPromise = null
  Rx.Observable.defer ->
    unless cachedPromise
      cachedPromise = request url, opts
      .then (res) ->
        onresult res
        return res
    return cachedPromise

module.exports = class Proxy
  constructor: ({@headers} = {}) ->
    @headers ?= {}
    @serializationCache = {}

    pageCache = window?[PROXY_SERIALIZATION_KEY]?.cache or {}
    @cache = _.mapValues pageCache, (res, key) ->
      [optsString, url] = key.split '__z__'
      opts = JSON.parse optsString

      requestStreams = new Rx.ReplaySubject(1)
      requestStreams.onNext Rx.Observable.just res
      stream = requestStreams.switch()

      {stream, requestStreams, url, proxyOpts: opts}

    # FIXME
    # existingCache = window?[PROXY_SERIALIZATION_KEY]
    # isCacheValid = existingCache? and \
    #   Date.now() < existingCache._expireTime and \
    #   # Because client clock may be incorrect and set way in the past
    #   Date.now() > existingCache._expireTime - CACHE_EXPIRE_TIME_MS
    # proxyCache = if isCacheValid
    #   new Rx.BehaviorSubject(existingCache)
    # else
    #   new Rx.BehaviorSubject({
    #     _expireTime: Date.now() + CACHE_EXPIRE_TIME_MS
    #   })

  _invalidateCache: =>
    @serializationCache = {}
    @cache = _.transform @cache, (cache, val, key) =>
      {stream, requestStreams, url, proxyOpts} = val

      cachedSubject = null
      requestStreams.onNext deferredRequestStream url, proxyOpts, (res) =>
        @serializationCache[key] = res

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

  serialize: =>
    serialization = {
      cache: @serializationCache
    }

    "window['#{PROXY_SERIALIZATION_KEY}'] = #{JSON.stringify(serialization)};"

  fetch: (url, opts = {}) =>
    proxyOpts = @_mergeHeaders opts
    request url, proxyOpts
    .then (res) =>
      unless opts.isCacheable
        @_invalidateCache()
      return res

  stream: (url, opts = {}) =>
    cacheKey = JSON.stringify(opts) + '__z__' + url
    cached = @cache[cacheKey]

    if cached?
      return cached.stream

    proxyOpts = @_mergeHeaders opts

    requestStreams = new Rx.ReplaySubject(1)
    requestStreams.onNext deferredRequestStream url, proxyOpts, (res) =>
      @serializationCache[cacheKey] = res
    stream = requestStreams.switch()

    @cache[cacheKey] = {stream, requestStreams, url, proxyOpts}
    return @cache[cacheKey].stream
