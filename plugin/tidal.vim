if exists("g:loaded_tidal") || &cp || v:version < 700
  finish
endif
let g:loaded_tidal = 1
let s:parent_path = fnamemodify(expand("<sfile>"), ":p:h:s?/plugin??")

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Default config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Attempts to find a tidal boot file in this or any parent directory.
function s:FindTidalBoot()
  for name in ["BootTidal.hs", "Tidal.ghci", "boot.tidal"]
    let tidal_boot_file = findfile(name, ".".';')
    if !empty(tidal_boot_file)
      return tidal_boot_file
    endif
  endfor
endfunction

" Attempts to find a supercollider startup file in this or any parent dir.
function s:FindScBoot()
  for name in ["boot.sc", "boot.scd"]
    let sc_boot_file = findfile(name, ".".';')
    if !empty(sc_boot_file)
      return sc_boot_file
    endif
  endfor
endfunction

if !exists("g:tidal_target")
    let g:tidal_target = "tmux"
endif

if !exists("g:tidal_paste_file")
  let g:tidal_paste_file = tempname()
endif

if !exists("g:tidal_default_config")
  let g:tidal_default_config = { "socket_name": "default", "target_pane": ":0.1" }
endif

if !exists("g:tidal_preserve_curpos")
  let g:tidal_preserve_curpos = 1
endif

if !exists("g:tidal_flash_duration")
  let g:tidal_flash_duration = 150
endif

if !exists("g:tidal_ghci")
  let g:tidal_ghci = "ghci"
endif

if !exists("g:tidal_boot_fallback")
  let g:tidal_boot_fallback = s:parent_path . "/Tidal.ghci"
endif

if !exists("g:tidal_boot")
  let g:tidal_boot = s:FindTidalBoot()
  if empty(g:tidal_boot)
    let g:tidal_boot = g:tidal_boot_fallback
  endif
endif

if !exists("g:tidal_superdirt_enable")
  " Allow vim-tidal to automatically start SuperDirt. Disabled by default.
  let g:tidal_superdirt_enable = 0
endif

if !exists("g:tidal_sclang")
  let g:tidal_sclang = "sclang"
endif

" Allow vim-tidal to automatically start supercollider. Disabled by default.
if !exists("g:tidal_sc_enable")
  let g:tidal_sc_enable = 0
endif

if !exists("g:tidal_sc_boot_fallback")
  let g:tidal_sc_boot_fallback = s:parent_path . "/boot.sc"
endif

if !exists("g:tidal_sc_boot")
  let g:tidal_sc_boot = s:FindScBoot()
  if empty(g:tidal_sc_boot)
    let g:tidal_sc_boot = g:tidal_sc_boot_fallback
  endif
endif

if !exists("g:tidal_sc_boot_cmd")
  " A command that can be run from the terminal to start supercollider.
  " The default assumes `SuperDirt` is installed.
  let g:tidal_sc_boot_cmd = g:tidal_sclang . " " . g:tidal_sc_boot
endif

if filereadable(s:parent_path . "/.dirt-samples")
  let &l:dictionary .= ',' . s:parent_path . "/.dirt-samples"
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tmux
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:TmuxSend(config, text)
  execute "VimuxRunCommand('" . a:text . "')")
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Terminal
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:tidal_term_ghci = -1
let s:tidal_term_sc = -1

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:SID()
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun

function! s:WritePasteFile(text)
  " could check exists("*writefile")
  call system("cat > " . g:tidal_paste_file, a:text)
endfunction

function! s:_EscapeText(text)
  if exists("&filetype")
    let custom_escape = "_EscapeText_" . substitute(&filetype, "[.]", "_", "g")
    if exists("*" . custom_escape)
      let result = call(custom_escape, [a:text])
    end
  end

  " use a:text if the ftplugin didn't kick in
  if !exists("result")
    let result = a:text
  end

  " return an array, regardless
  if type(result) == type("")
    return [result]
  else
    return result
  end
endfunction

function! s:TidalGetConfig()
  if !exists("b:tidal_config")
    if exists("g:tidal_default_config")
      let b:tidal_config = g:tidal_default_config
    else
      execute 'VimuxRunCommand("tidal")'
    end
  end
endfunction

function! s:TidalFlashVisualSelection()
  " Redraw to show current visual selection, and sleep
  redraw
  execute "sleep " . g:tidal_flash_duration . " m"
  " Then leave visual mode
  silent exe "normal! vv"
endfunction

function! s:TidalSendOp(type, ...) abort
  call s:TidalGetConfig()

  let sel_save = &selection
  let &selection = "inclusive"
  let rv = getreg('"')
  let rt = getregtype('"')

  if a:0  " Invoked from Visual mode, use '< and '> marks.
    silent exe "normal! `<" . a:type . '`>y'
  elseif a:type == 'line'
    silent exe "normal! '[V']y"
  elseif a:type == 'block'
    silent exe "normal! `[\<C-V>`]\y"
  else
    silent exe "normal! `[v`]y"
  endif

  call setreg('"', @", 'V')
  call s:TidalSend(@")

  " Flash selection
  if a:type == 'line'
    silent exe "normal! '[V']"
    call s:TidalFlashVisualSelection()
  endif

  let &selection = sel_save
  call setreg('"', rv, rt)

  call s:TidalRestoreCurPos()
endfunction

function! s:TidalSendRange() range abort
  call s:TidalGetConfig()

  let rv = getreg('"')
  let rt = getregtype('"')
  silent execute a:firstline . ',' . a:lastline . 'yank'
  call s:TidalSend(@")
  call setreg('"', rv, rt)
endfunction

function! s:TidalSendLines(count) abort
  call s:TidalGetConfig()

  let rv = getreg('"')
  let rt = getregtype('"')

  silent execute "normal! " . a:count . "yy"

  call s:TidalSend(@")
  call setreg('"', rv, rt)

  " Flash lines
  silent execute "normal! V"
  if a:count > 1
    silent execute "normal! " . (a:count - 1) . "\<Down>"
  endif
  call s:TidalFlashVisualSelection()
endfunction

function! s:TidalStoreCurPos()
  if g:tidal_preserve_curpos == 1
    if exists("*getcurpos")
      let s:cur = getcurpos()
    else
      let s:cur = getpos('.')
    endif
  endif
endfunction

function! s:TidalRestoreCurPos()
  if g:tidal_preserve_curpos == 1
    call setpos('.', s:cur)
  endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:TidalSend(text)
  call s:TidalGetConfig()
  let pieces = s:_EscapeText(a:text)
  execute "VimuxRunCommand('" . pieces . "')"
"  for piece in pieces
"  endfor
endfunction

function! s:TidalConfig() abort
  call inputsave()
  execute 'VimuxRunCommand("tidal")'
  call inputrestore()
endfunction

function! s:TidalHush()
  execute 'VimuxRunCommand("hush")'
endfunction

function! s:TidalSilence(stream)
  silent execute 'VimuxRunCommand(' . a:stream . ' $ silence)'
endfunction

function! s:TidalPlay(stream)
  let res = search('^\s*d' . a:stream)
  if res > 0
    silent execute "normal! vip:TidalSend\<cr>"
    silent execute "normal! vip"
    call s:TidalFlashVisualSelection()
  else
    echo "d" . a:stream . " was not found"
  endif
endfunction

function! s:TidalGenerateCompletions(path)
  let l:exe = s:parent_path . "/bin/generate-completions"
  let l:output_path = s:parent_path . "/.dirt-samples"

  if !empty(a:path)
    let l:sample_path = a:path
  else
    if has('macunix')
      let l:sample_path = "~/Library/Application Support/SuperCollider/downloaded-quarks/Dirt-Samples"
    elseif has('unix')
      let l:sample_path = "~/.local/share/SuperCollider/downloaded-quarks/Dirt-Samples"
    endif
  endif
  " generate completion file
  silent execute '!' . l:exe shellescape(expand(l:sample_path)) shellescape(expand(l:output_path))
  echo "Generated dictionary of dirt-samples"
  " setup completion
  let &l:dictionary .= ',' . l:output_path
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Setup key bindings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

command -bar -nargs=0 TidalConfig call s:TidalConfig()
command -range -bar -nargs=0 TidalSend <line1>,<line2>call s:TidalSendRange()
command -nargs=+ TidalSend1 call s:TidalSend(<q-args>)

command! -nargs=0 TidalHush call s:TidalHush()
command! -nargs=1 TidalSilence call s:TidalSilence(<args>)
command! -nargs=1 TidalPlay call s:TidalPlay(<args>)
command! -nargs=? TidalGenerateCompletions call s:TidalGenerateCompletions(<q-args>)

noremap <SID>Operator :<c-u>call <SID>TidalStoreCurPos()<cr>:set opfunc=<SID>TidalSendOp<cr>g@

noremap <unique> <script> <silent> <Plug>TidalRegionSend :<c-u>call <SID>TidalSendOp(visualmode(), 1)<cr>
noremap <unique> <script> <silent> <Plug>TidalLineSend :<c-u>call <SID>TidalSendLines(v:count1)<cr>
noremap <unique> <script> <silent> <Plug>TidalMotionSend <SID>Operator
noremap <unique> <script> <silent> <Plug>TidalParagraphSend <SID>Operatorip
noremap <unique> <script> <silent> <Plug>TidalConfig :<c-u>TidalConfig<cr>
