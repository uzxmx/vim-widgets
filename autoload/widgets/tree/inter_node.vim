let s:node = {}

function! widgets#tree#inter_node#new(...)
  return extend(call(function('widgets#tree#node#new'), a:000), s:node)
endfunction

function! widgets#tree#inter_node#newRoot(name)
  let node = widgets#tree#inter_node#new(a:name)
  let node._depth = 0
  return node
endfunction

function! s:node.isLeaf()
  return 0
endfunction

function! s:node.isOpen()
  return get(self, '_open', 0)
endfunction

function! s:node.open()
  let self._open = 1
endfunction

function! s:node.close()
  let self._open = 0
endfunction

function! s:node.childNodesLoaded()
  return has_key(self, '_isEmpty')
endfunction

function! s:node.isEmpty()
  return self._isEmpty
endfunction

function! s:node.setChildNodes(childNodes)
  for child in a:childNodes
    let child._depth = self._depth + 1
    let child._parent = self
  endfor
  let self._childNodes = a:childNodes
  let self._isEmpty = empty(a:childNodes)
endfunction

function! s:node.getChildNodes()
  return self._childNodes
endfunction
