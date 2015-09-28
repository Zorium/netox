# netox

depends on clay-request which depends on whatwg-fetch polyfill

```
Netox = require 'netox'
netox = new Netox
  headers: {} # optional, lower-cased key-value defaults for server-side calls

# same signature as whatwg-fetch, returns an RxJS observable of clay-request response
netox.stream 'http://x.com/x'
.subscribe (res) -> ...

# same signature as whatwg-fetch, re-fetches streams, returns clay-request response
netox.fetch 'http://x.com/x', {method: 'POST'}
netox.fetch 'http://x.com/x', {isIdempotent: true} # dont re-fetch streams
.then (res) -> ...

# put this in a server-side generated script tag
netox.getSerializationStream()
.map (serialization) ->
  # window['NETOX'] = {...};

# send analytics events with timing info
netox.stream 'http://x.com/x', {isTimed: true}
netox.onTiming ({url, elapsed}) ->
  # hyperplane.emit 'timing', {fields: {url, value: elapsed}}
```
