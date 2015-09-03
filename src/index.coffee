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

# FIXME
# PROXY_CACHE_KEY = 'STREAM_PROXY_CACHE'
# CACHE_EXPIRE_TIME_MS = 1000 * 10 # 10 seconds

getCacheKey = (url, opts) ->
  JSON.stringify(opts) + '__z__' + url

deferredRequestStream = (url, opts) ->
  cachedPromise = null
  Rx.Observable.defer ->
    unless cachedPromise
      cachedPromise = request url, opts
    return cachedPromise

module.exports = class Proxy
  constructor: ->
    @cache = {}

    # FIXME
    # existingCache = window?[PROXY_CACHE_KEY]
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
    @cache = _.transform @cache, (cache, val, key) ->
      {stream, requestStreams, url, proxyOpts} = val

      cachedSubject = null
      requestStreams.onNext deferredRequestStream url, proxyOpts

      cache[key] = {stream, requestStreams, url, proxyOpts}
    , {}

  fetch: (url, opts = {}) =>
    proxyOpts = opts # FIXME
    request url, proxyOpts
    .then (res) =>
      unless opts.isCacheable
        @_invalidateCache()
      return res

  stream: (url, opts = {}) =>
    cacheKey = getCacheKey url, opts
    cached = @cache[cacheKey]

    if cached?
      return cached.stream

    proxyOpts = opts # FIXME

    requestStreams = new Rx.ReplaySubject(1)
    requestStreams.onNext deferredRequestStream url, proxyOpts
    stream = requestStreams.switch()

    @cache[cacheKey] = {stream, requestStreams, url, proxyOpts}
    return @cache[cacheKey].stream


    # FIXME
    # proxyOpts = if serverHeaders
    #   _.merge {
    #     headers:
    #       'cookie': serverHeaders['cookie']
    #       'user-agent': serverHeaders['user-agent']
    #       'accept-language': serverHeaders['accept-language']
    #       'x-forwarded-for': serverHeaders['x-forwarded-for']
    #   }, opts
    # else
    #   opts
