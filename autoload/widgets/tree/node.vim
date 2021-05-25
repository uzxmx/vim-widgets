let s:node = {}

function! widgets#tree#node#new(name, ...)
  let node = copy(s:node)
  let node._name = a:name
  if a:0 > 0
    let node._data = a:1
  endif
  return node
endfunction

function! s:node.getDepth()
  return self._depth
endfunction

function! s:node.getName()
  return self._name
endfunction

function! s:node.getData()
  return self._data
endfunction
