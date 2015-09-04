# stream-proxy

depends on clay-request which depends on whatwg-fetch polyfill

```
Proxy = require 'stream-proxy'
proxy = new Proxy
  headers: {} # optional, lower-cased key-value defaults for server-side calls

# same signature as whatwg-fetch, returns an RxJS observable of clay-request response
proxy.stream 'http://x.com/x'
.subscribe (res) -> ...

# same signature as whatwg-fetch, re-fetches streams, returns clay-request response
proxy.fetch 'http://x.com/x', {method: 'POST'}
proxy.fetch 'http://x.com/x', {isIdempotent: true} # dont re-fetch streams
.then (res) -> ...

# put this in a server-side generated script tag
proxy.getSerializationStream()
.map (serialization) ->
  # window['STREAM_PROXY'] = {...};
```
