""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:not_prefixable_keywords = [ "import", "data", "instance", "class", "{-#", "type", "case", "do", "let", "default", "foreign", "--"]

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Mappings
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if !exists("g:tidal_no_mappings") || !g:tidal_no_mappings
  if !hasmapto('<Plug>TidalConfig', 'n')
    nmap <buffer> <localleader>c <Plug>TidalConfig
  endif

  if !hasmapto('<Plug>TidalRegionSend', 'x')
    xmap <buffer> <localleader>s  <Plug>TidalRegionSend
    xmap <buffer> <c-e> <Plug>TidalRegionSend
  endif

  if !hasmapto('<Plug>TidalLineSend', 'n')
    nmap <buffer> <localleader>s  <Plug>TidalLineSend
  endif

  if !hasmapto('<Plug>TidalParagraphSend', 'n')
    nmap <buffer> <localleader>ss <Plug>TidalParagraphSend
    nmap <buffer> <c-e> <Plug>TidalParagraphSend
  endif

  imap <buffer> <c-e> <Esc><Plug>TidalParagraphSend<Esc>i<Right>

  nnoremap <buffer> <localleader>h :TidalHush<cr>
  nnoremap <buffer> <c-h> :TidalHush<cr>
  let i = 1
  while i <= 9
    execute 'nnoremap <buffer> <localleader>'.i.'  :TidalSilence '.i.'<cr>'
    execute 'nnoremap <buffer> <c-'.i.'>  :TidalSilence '.i.'<cr>'
    execute 'nnoremap <buffer> <localleader>s'.i.' :TidalPlay '.i.'<cr>'
    let i += 1
  endwhile
endif
