" commentary.vim - Comment stuff out
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.2
" GetLatestVimScripts: 3695 1 :AutoInstall: commentary.vim

if exists("g:loaded_commentary") || &cp || v:version < 700
  finish
endif
let g:loaded_commentary = 1

function! s:surroundings() abort
  " Turns out that for the purposes of programming, the variable scope
  " limiters can be treated just like dictionaries.
  return split(get(b:, 'commentary_format', substitute(substitute(
        \ &commentstring, '\S\zs%s',' %s','') ,'%s\ze\S', '%s ', '')), '%s', 1)
endfunction

function! s:go(type,...) abort
  if a:0
    let [lnum1, lnum2] = [a:type, a:1]
  else
    let [lnum1, lnum2] = [line("'["), line("']")]
  endif

  let [l, r] = s:surroundings()
  let uncomment = 2
  for lnum in range(lnum1,lnum2)
    " Seems like the only thing this regex does is to grab the whole line
    " while omitting any trailing whitespace. In other words, this is
    " equivalent to grabbing the entire line and then trimming any whitespace.
    let line = matchstr(getline(lnum),'\S.*\s\@<!')
    " By 'default', we'll try to uncomment lines. HOWEVER, if at any point
    " there is a line that doesn't start with 'l' or doesn't end with the 'r',
    " then we'll comment. Said another way, we only uncomment lines that start
    " AND end with 'l' and 'r' because those are valid comments.
    if line != '' && (stridx(line,l) || line[strlen(line)-strlen(r) : -1] != r)
      let uncomment = 0
    endif
  endfor

  for lnum in range(lnum1,lnum2)
    let line = getline(lnum)
    " I think this has something to do with the nesting of comments.
    if strlen(r) > 2 && l.r !~# '\\'
      let line = substitute(line,
            \'\M'.r[0:-2].'\zs\d\*\ze'.r[-1:-1].'\|'.l[0].'\zs\d\*\ze'.l[1:-1],
            \'\=substitute(submatch(0)+1-uncomment,"^0$\\|^-\\d*$","","")','g')
    endif
    " With all that work above, this part is actually pretty simple. If we're
    " uncommenting lines then we remove the 'l' and 'r' comment strings from
    " the beginning and end of the line.
    if uncomment
      let line = substitute(line,'\S.*\s\@<!','\=submatch(0)[strlen(l):-strlen(r)-1]','')
    " The concept for this one is also not that bad, all it's doing is
    " commenting the lines! But how it does this is a bit more complicated.
    " This first part: ^\%('.matchstr(getline(lnum1),'^\s*').'\|\s*\) tries to
    " align the comments based on the amount of white space in the first line
    " whenever possible. The \%(...\) makes it so this pattern isn't counted
    " as a subexpression.

    " '.*\S\@<=' is another pattern like the '.*\s\@<!' regex. It actually
    " seems to be the exact same in function i.e it ignores trailing
    " whitespace. I still don't exactly understand these atoms but I'm fairly
    " sure this is what they're doing. So after getting this string we just
    " prepend and append 'l' and 'r' to the line and now our line if
    " commented!
    else
      let line = substitute(line,'^\%('.matchstr(getline(lnum1),'^\s*').'\|\s*\)\zs.*\S\@<=','\=l.submatch(0).r','')
    endif
    call setline(lnum,line)
  endfor
  let modelines = &modelines
  try
    set modelines=0
    silent doautocmd User CommentaryPost
  finally
    let &modelines = modelines
  endtry
endfunction

" Defines the text object for comments. What it does is set this pair 'lnums'
" to have the starting end ending line number of the object. Then at the end,
" we just line-wise visual select between those lines. Done!
function! s:textobject(inner) abort
  let [l, r] = s:surroundings()
  " lnums[0] and lnums[1] start off +1 and -2 rows from the current cursor
  " position because it just works out nicely for the algorithm. That's it.
  " More specifically he does it so there is a sort of built in check for
  " whether this text object exists (see the if conditional at the end of this
  " function). It may seem like we'll check the same lines multiple times but
  " that won't happen. lnums[0] will check the lines line('.') - 1 and down
  " while lnums[1] will check lines line('.') and up.
  let lnums = [line('.')+1, line('.')-2]
  for [index, dir, bound, line] in [[0, -1, 1, ''], [1, 1, line('$'), '']]
  " for [index, dir, bound, line] in [[0, -1, 1, l], [1, 1, line('$'), l]]
    while lnums[index] != bound && line ==# '' || !(stridx(line,l) || line[strlen(line)-strlen(r) : -1] != r)
    " while lnums[index] != bound && !(stridx(line,l) || line[strlen(line)-strlen(r) : -1] != r)
      let lnums[index] += dir
      let line = matchstr(getline(lnums[index]+dir),'\S.*\s\@<!')
    endwhile
  endfor
  while (a:inner || lnums[1] != line('$')) && empty(getline(lnums[0]))
    let lnums[0] += 1
  endwhile
  while a:inner && empty(getline(lnums[1]))
    let lnums[1] -= 1
  endwhile
  if lnums[0] <= lnums[1]
    execute 'normal! 'lnums[0].'GV'.lnums[1].'G'
  endif
endfunction

xnoremap <silent> <Plug>Commentary     :<C-U>call <SID>go(line("'<"),line("'>"))<CR>
nnoremap <silent> <Plug>Commentary     :<C-U>set opfunc=<SID>go<CR>g@
nnoremap <silent> <Plug>CommentaryLine :<C-U>set opfunc=<SID>go<Bar>exe 'norm! 'v:count1.'g@_'<CR>
onoremap <silent> <Plug>Commentary        :<C-U>call <SID>textobject(0)<CR>
nnoremap <silent> <Plug>ChangeCommentary c:<C-U>call <SID>textobject(1)<CR>
nmap <silent> <Plug>CommentaryUndo <Plug>Commentary<Plug>Commentary
command! -range -bar Commentary call s:go(<line1>,<line2>)

if !hasmapto('<Plug>Commentary') || maparg('gc','n') ==# ''
  xmap gc  <Plug>Commentary
  nmap gc  <Plug>Commentary
  omap gc  <Plug>Commentary
  nmap gcc <Plug>CommentaryLine
  nmap cgc <Plug>ChangeCommentary
  nmap gcu <Plug>Commentary<Plug>Commentary
endif

if maparg('\\','n') ==# '' && maparg('\','n') ==# '' && get(g:, 'commentary_map_backslash', 1)
  xmap \\  <Plug>Commentary:echomsg '\\ is deprecated. Use gc'<CR>
  nmap \\  :echomsg '\\ is deprecated. Use gc'<CR><Plug>Commentary
  nmap \\\ <Plug>CommentaryLine:echomsg '\\ is deprecated. Use gc'<CR>
  nmap \\u <Plug>CommentaryUndo:echomsg '\\ is deprecated. Use gc'<CR>
endif

" vim:set et sw=2:
