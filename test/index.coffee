assert = require 'assert'

example = require '../src'

describe 'example', ->
  it 'compares equals', ->
    res = example.compare 'a', 'a'
    assert.equal res, true

  it 'compares non-equals', ->
    res = example.compare 'b', 'a'
    assert.equal res, false
