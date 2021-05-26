let s:options = {
      \   'global': 1,
      \   'winPos': 'left',
      \   'winWidth': 31,
      \   'showLineNumbers': 0,
      \   'highlightCursorLine': 1,
      \   'arrowExpandable': '▸',
      \   'arrowCollapsible': '▾',
      \ }

let s:keyMaps = {
      \ 'q': { 'action': 'close' },
      \ 'o': { 'action': 'openNode' },
      \ '<enter>': { 'action': 'openNode' },
      \ 'x': { 'action': 'closeParentNode' },
      \ 'p': { 'action': 'goToParentNode' },
      \ }

let s:tree = {}
let s:trees = []

function! widgets#tree#new(name, ...)
  let tree = widgets#tree#getTree(a:name)
  if !empty(tree)
    echoerr "A tree with name " . a:name . " already exists."
  endif

  let tree = copy(s:tree)
  let tree.name = a:name
  call add(s:trees, tree)

  let tree.options = a:0 > 0 ? a:1 : {}
  call extend(tree.options, s:options, "keep")

  let tree.keyMaps = a:0 > 1 ? a:2 : {}
  call extend(tree.keyMaps, s:keyMaps, "keep")

  return tree
endfunction

function! s:callTreeMethod(name, method)
  return 'widgets#tree#getTree' . '("' . a:name . '").' . a:method . '()'
endfunction

function! s:callFuncForKey(name, key)
  let tree = widgets#tree#getTree(a:name)

  if !has_key(tree.keyMaps, a:key)
    return
  endif

  let map = tree.keyMaps[a:key]
  if empty(map)
    return
  endif

  let args = [tree]
  if !empty(map.args)
    call extend(args, map.args)
  endif
  call call(map.func, args)
endfunction

function! widgets#tree#getTree(name)
  for i in s:trees | if i.name == a:name | return i | endif | endfor
endfunction

function! s:tree.close()
  if !self.isOpen() | return | endif

  if winnr('$') != 1
    " Use the window ID to identify the currently active window or fall
    " back on the buffer ID if win_getid/win_gotoid are not available, in
    " which case we'll focus an arbitrary window showing the buffer.
    let l:useWinId = exists('*win_getid') && exists('*win_gotoid')

    if winnr() ==# self.getWinNum()
      call widgets#utils#exec('wincmd p', 1)
      let l:activeBufOrWin = l:useWinId ? win_getid() : bufnr('')
      call widgets#utils#exec('wincmd p', 1)
    else
      let l:activeBufOrWin = l:useWinId ? win_getid() : bufnr('')
    endif

    call widgets#utils#exec(self.getWinNum() . ' wincmd w', 1)
    call widgets#utils#exec('close', 0)
    if l:useWinId
      call widgets#utils#exec('call win_gotoid(' . l:activeBufOrWin . ')', 0)
    else
      call widgets#utils#exec(bufwinnr(l:activeBufOrWin) . ' wincmd w', 0)
    endif
  else
    close
  endif
endfunction

function! s:tree.findCurrentNode()
  let targetLine = line('.')

  let nodes = [self._rootNode]
  let currentLine = 1
  let i = 0
  while !empty(nodes)
    let node = nodes[i]
    if currentLine == targetLine
      return node
    endif
    let currentLine += 1
    call remove(nodes, i)
    if !node.isLeaf() && node.isOpen() && !node.isEmpty()
      call extend(nodes, reverse(copy(node.getChildNodes())))
      let i = len(nodes) - 1
    else
      let i -= 1
    endif
  endwhile
endfunction

function! s:tree.focus(node)
  let node = a:node
  while has_key(node, '_parent')
    call node._parent.open()
    let node = node._parent
  endwhile
  call self.render()
  call s:move_cursor_to_node(a:node)
endfunction

function! s:tree.openNode()
  let node = self.findCurrentNode()
  if !empty(node)
    if node.isLeaf()
      call self.options.openLeafNode(self, node)
    else
      if !node.childNodesLoaded()
        call self.options.getChildNodes(node)
      endif
      call node.open()
      call self.render()
    endif
  endif
endfunction

function! s:tree.closeParentNode()
  let node = self.findCurrentNode()
  if !empty(node) && has_key(node, '_parent')
    call node._parent.close()
    call self.render()
    call s:move_cursor_to_node(node._parent)
  endif
endfunction

function s:move_cursor_to_node(node)
  call cursor(a:node._lineno, 1)
  normal! ^2l
endfunction

function! s:tree.goToParentNode()
  let node = self.findCurrentNode()
  if !empty(node) && has_key(node, '_parent')
    call s:move_cursor_to_node(node._parent)
  endif
endfunction

function! s:tree.getWinNum()
  let options = self.options
  if options.global
    let varname = 'g:widgetsTreeBufName'
  else
    let varname = 't:widgetsTreeBufName'
  endif

  if exists(varname)
    return bufwinnr(eval(varname))
  else
    return -1
  endif
endfunction

function! s:tree.isOpen()
  return self.getWinNum() != -1
endfunction

function! s:tree.open()
  let options = self.options
  let varname = options.global ? 'g:widgetsTreeBufName' : 't:widgetsTreeBufName'

  let l:splitLocation = options.winPos ==# 'left' ? 'topleft ' : 'botright '
  let l:splitSize = options.winWidth

  if exists(varname)
    silent! execute l:splitLocation . 'vertical ' . l:splitSize . ' split'
    silent! execute 'buffer ' . eval(varname)
  else
    let bufName = s:nextBufferName()
    exec 'let ' .  varname . ' = ' . '"' . bufName . '"'
    silent! execute l:splitLocation . 'vertical ' . l:splitSize . ' new'
    silent! execute 'edit ' . bufName
    let self._rootNode = self.options.getRootNode(self)
    call self.render()
    silent! execute 'vertical resize '. l:splitSize
  endif

  setlocal winfixwidth
  call self.setBufOptions()
endfunction

function! s:tree.findNodeByPath(path, ...)
  let path_idx = 0
  let path_len = len(a:path)

  if a:0 > 0
    let nodes = reverse(copy(self.getChildNodes(a:1)))
  else
    let nodes = [self._rootNode]
  endif
  let i = len(nodes) - 1
  let positions = []
  while !empty(nodes) && path_idx < path_len
    let node = remove(nodes, i)
    let i -= 1
    if node.getName() == a:path[path_idx]
      if path_idx + 1 < path_len
        if !node.isLeaf() && !self.isNodeEmpty(node)
          call add(positions, i)
          let path_idx += 1
          call extend(nodes, reverse(copy(self.getChildNodes(node))))
          let i = len(nodes) - 1
        endif
      else
        return node
      endif
    endif

    if path_idx > 0 && positions[path_idx - 1] == i
      let path_idx -= 1
      call remove(positions, path_idx)
    endif
  endwhile
endfunction

function! s:tree.setBufOptions()
  let options = self.options

  " Options for a non-file/control buffer.
  setlocal bufhidden=hide
  setlocal buftype=nofile
  setlocal noswapfile

  " Options for controlling buffer/window appearance.
  setlocal foldcolumn=0
  setlocal foldmethod=manual
  setlocal nobuflisted
  setlocal nofoldenable
  setlocal nolist
  setlocal nospell
  setlocal nowrap

  if options.showLineNumbers
    setlocal number
  else
    setlocal nonumber
    if v:version >= 703
      setlocal norelativenumber
    endif
  endif

  iabc <buffer>

  if options.highlightCursorLine
    setlocal cursorline
  endif

  " call self._setupStatusline()
  call s:bindKeys(self.name, self.keyMaps)

  setlocal filetype=widgets_tree
endfunction

function s:tree.render()
  setlocal noreadonly modifiable

  " Remember the top line of the buffer and the current line so we can
  " restore the view exactly how it was
  let curLine = line('.')
  let curCol = col('.')
  let topLine = line('w0')

  " Delete all lines in the buffer (being careful not to clobber a register)
  silent 1,$delete _

  let line = 1
  let nodes = [self._rootNode]
  let i = 0
  while !empty(nodes)
    let node = nodes[i]
    if node.isLeaf()
      let icon = ''
    else
      let icon = node.isOpen() ? self.options.arrowCollapsible : self.options.arrowExpandable
      if !empty(icon)
        let icon .= ' '
      endif
    endif
    call setline(line, repeat('  ', node.getDepth()) . icon . node.getName())
    let node._lineno = line
    let line += 1
    call remove(nodes, i)
    if !node.isLeaf() && node.isOpen() && !node.isEmpty()
      call extend(nodes, reverse(copy(node.getChildNodes())))
      let i = len(nodes) - 1
    else
      let i -= 1
    endif
  endwhile

  " Restore the view
  let old_scrolloff=&scrolloff
  let &scrolloff=0
  call cursor(topLine, 1)
  normal! zt
  call cursor(curLine, curCol)
  let &scrolloff = old_scrolloff

  setlocal noreadonly nomodifiable
endfunction

function s:bindKeys(name, keyMaps)
  for key in keys(a:keyMaps)
    let i = a:keyMaps[key]
    if has_key(i, 'action')
      exec 'nnoremap <buffer> <silent> '. key . ' :call ' . s:callTreeMethod(a:name, i.action) . '<cr>'
    elseif has_key(i, 'func')
      exec 'nnoremap <buffer> <silent> '. key . ' :call <SID>callFuncForKey("'. a:name . '", "' . key . '")<cr>'
    else
      echoerr 'Unsupported key binding for key ' . key . ': ' . string(i)
    endif
  endfor
endfunction

function! s:nextBufferName()
  if !exists('s:nextBufferNumber')
    let s:nextBufferNumber = 1
  else
    let s:nextBufferNumber += 1
  endif

  return 'widgets_tree_' . s:nextBufferNumber
endfunction

function! s:tree.isNodeEmpty(node)
  if !a:node.childNodesLoaded()
    call self.options.getChildNodes(a:node)
  endif
  return a:node.isEmpty()
endfunction

function! s:tree.getChildNodes(node)
  if !a:node.childNodesLoaded()
    call self.options.getChildNodes(a:node)
  endif
  return a:node.getChildNodes()
endfunction

function! s:tree.getRootNode()
  return self._rootNode
endfunction
