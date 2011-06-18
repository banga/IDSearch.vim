" Plugin: IDsearch
" 
" Author: Shrey Banga
" 
" Description: 
" Supplement to id-utils. Searches ID files for a given word and
" previews the results. Results can be opened by pressing <CR>, t or T
" 
" Usage:
" Install id-utils and generate ID file with mkid.
" Map the g:IDSearchCurrentWord() and g:IDSearchCustom() to suitable keys
" eg:
"   map <C-F> :call g:IDSearchCurrentWord()<CR>
"   map <C-G> :call g:IDSearchCustom()<CR>
" 
" Note:
" This is my first attempt at writing a vim script. I used NERDTree's
" source to learn how to do certain things. It's a fantastic plugin
" for file exploration and more. Highly recommended for learning vim
" scripting.
"
" GUI:
" This creates a buffer for the search results ("Search" buffer)
" When the user moves the cursor in the search buffer, the preview window is
" updated with the contents of the current file.


"
"FUNCTION: Sets default global value if a value hasn't been set
"
function! s:setGlobalDefault(var, value)
	if !exists(a:var)
		exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
		return 1
	endif
	return 0
endfunction

"
"FUNCTION: Initialize script
"
function! s:initIDSearch()
	if !executable('gid')
		echo "Could not find 'gid'. Make sure you have id-utils installed and in search path"
		return 0
	endif

	if !exists("s:IDSearchInited")
		let s:IDSearchBufName = "IDSearchBuffer"
		let s:next_search_buffer_number = 1

		"Set global defaults if not already set
		call s:setGlobalDefault('g:IDSearch_search_window_height', 5)
		call s:setGlobalDefault('g:IDSearch_KEY_show_original', 'h')

		let s:IDSearchInited = 1
	endif

	return 1
endfunction

"
"FUNCTION: returns a new unique buffer name
"
function! s:nextSearchBufferName()
    let name = s:IDSearchBufName . s:next_search_buffer_number
    let s:next_search_buffer_number += 1
    return name
endfunction

"
"FUNCTION: returns number of the search window if it exists, or -1
"
function! s:getSearchWinNum()
    if exists("t:IDSearchBufName")
        return bufwinnr(t:IDSearchBufName)
    else
        return -1
    endif
endfunction

"
"FUNCTION: returns 0 if window is not open, non-zero otherwise
"
function! s:isSearchWinOpen()
	return s:getSearchWinNum() != -1
endfunction

"
"FUNCTION: stores current file name and line number from the buffer
"
function! s:getCurSearchResult()
	let line = getline(".")
	let terms = split(line,":")

	if len(terms) >= 2
		let s:curResultFileName = terms[0]
		let s:curResultLineNum = terms[1]
	else
		let s:curResultFileName = "" 
		let s:curResultLineNum = ""
	endif
endfunction


"
"FUNCTION: opens the current file in the preview window 
"
function! s:previewFile()
	call s:getCurSearchResult()

	if filereadable(s:curResultFileName)
		exec 'pedit +'.s:curResultLineNum.' '.s:curResultFileName
		silent! wincmd p
		setlocal cursorline
		silent! wincmd p
	endif
endfunction

"
"FUNCTION: opens the current file for editing in the same window that started
"the search
"
function! s:openFile()
	call s:getCurSearchResult()

	silent! exec "pclose"
	silent! exec t:callingWinNum."wincmd w"
	silent! exec "edit +".s:curResultLineNum." ".s:curResultFileName
endfunction

"
"FUNCTION: opens the current file for editing in a new tab
"PARAM: silent: if true, tab is opened without taking focus away from the
"search results window
"
function! s:openFileInTab(silent)
	call s:getCurSearchResult()

	if a:silent
		let lastTabNum = tabpagenr()
	else
		silent! exec "pclose"
	endif
	silent! exec "tabedit +".s:curResultLineNum." ".s:curResultFileName
	if a:silent
		exec "tabnext ".lastTabNum
	endif
endfunction

"
"FUNCTION: shows the file which originated the search
"
function! s:showOriginalFile()
	silent! exec t:callingWinNum."wincmd w"
	silent! exec "buffer ".t:callingWinBufNum
	silent! call winrestview(t:callingWinView)
endfunction

"
"FUNCTION: called whenever the user moves the cursor. Previews the file
"currently under the cursor
"
function! s:onCursorMoved()
	let moved = 0
	let t:curResultRow = line(".")
	if exists("t:prevResultRow")
		if t:curResultRow != t:prevResultRow
			let moved = 1
			let t:prevResultRow = t:curResultRow
		endif
	else
		let t:prevResultRow = t:curResultRow
		let moved = 1
	endif

	if moved
		call s:previewFile()
	endif
endfunction

"
"FUNCTION: sets up autocommands and mappings
"
function! s:setMappings()
	"Preview files
	autocmd CursorMoved <buffer> nested call s:onCursorMoved()
	
	"Open file in same window when Enter is pressed
	noremap <silent> <buffer> <CR> :call <SID>openFile()<CR>

	"Open file in new tab when t is pressed
	noremap <silent> <buffer> t :call <SID>openFileInTab(0)<CR>

	"Open file in new tab silently when T is pressed
	noremap <silent> <buffer> T :call <SID>openFileInTab(1)<CR>

	"Close results window and go to original file when H is pressed
	silent! exec 'noremap <silent> ' . g:IDSearch_KEY_show_original .' :call <SID>showOriginalFile()<CR>'

	"Close results window when x is pressed
	noremap <silent> <buffer> x :close<CR>:pclose<CR>

	"Close preview window when p is pressed
	noremap <silent> <buffer> p :pclose<CR>
endfunction


"
"FUNCTION: sets the status line to indicate the word being searched
"
function! s:setupSearchStatusline()
	let &l:statusline="Searching for '".s:word."'"
endfunction

"
"FUNCTION: highlights the file name and line number
"
function s:setupSyntaxHighlighting()
	syn match Directory "^[^:]*"
	syn match Special /:[0-9]\+:/hs=s+1,he=e-1
endfunction

"
"FUNCTION: creates the search window if not already created and initializes
"all local settings to make the buffer look like a search results window
"
function! s:createSearchWin()
	let t:cwd = getcwd() 
	let t:callingWinNum = winnr()
	let t:callingWinBufNum = winbufnr(0)
	let t:callingWinView = winsaveview()
	let splitLocation = "botright "
    let splitSize = g:IDSearch_search_window_height

    if !exists('t:IDSearchBufName')
        let t:IDSearchBufName = s:nextSearchBufferName()
        silent! exec splitLocation . splitSize . ' new'
        silent! exec "edit " . t:IDSearchBufName

		call s:setMappings()
    else
		if s:isSearchWinOpen()
			silent! exec s:getSearchWinNum() . "wincmd w" 
		else
        	silent! exec splitLocation . splitSize . ' split'
        	silent! exec "buffer " . t:IDSearchBufName
		endif
    endif

    setlocal winfixheight

    "throwaway buffer options
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal nowrap
    setlocal foldcolumn=0
    setlocal nobuflisted
    setlocal nospell
    setlocal nu

    iabc <buffer>
    setlocal cursorline

	setlocal modifiable
	silent %delete _

	silent exec "lcd " + t:cwd
    call s:setupSearchStatusline()

    if has("syntax") && exists("g:syntax_on")
        call s:setupSyntaxHighlighting()
    endif
endfunction

"
"FUNCTION: searches for the pattern in s:word and displays the results in the
"window. Currently uses pattern matching to detect common errors.
"
function! s:Search()
	if !s:initIDSearch()
		return
	endif

	let old_s = @s
	let @s = system("gid ".s:word)
	if v:shell_error != 0
		echo "ERROR: ".@s
	else
		if len(@s) == 0
			echo "No results for '".s:word."'"
		else
			call s:createSearchWin()
			silent! put s 
			silent! 1 delete _ 
			setlocal nomodifiable
			call s:previewFile()
		endif
	endif
	let @s = old_s
endfunction

"
"FUNCTION: searches the current word under the cursor 
"
function! g:IDSearchCurrentWord()
	let s:word = expand("<cword>")
	call s:Search()
endfunction

"
"FUNCTION: prompts the user for the search pattern
"
function! g:IDSearchCustom()
	let s:word = input("Search for:",expand("<cword>"),"var")
	call s:Search()
endfunction
