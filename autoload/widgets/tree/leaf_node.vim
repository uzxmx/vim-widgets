let s:node = {}

function! widgets#tree#leaf_node#new(...)
  return extend(call(function('widgets#tree#node#new'), a:000), s:node)
endfunction

function! s:node.isLeaf()
  return 1
endfunction

function! s:node.open()
  let self._open = 1
endfunction
