" vimsmartcols
"
" vim global plugin for smart columns
" 
" v0.09
"
" Bo Waggoner
" vimsmartcols@gmail.com
" https://github.com/vimsmartcols/vimsmartcols
" Modified: 2012-04-04
" 
" This software is free.
"
" --------------------------------------

" Install:
" 1. put this file in directory ~/.vim/plugins
"    (creating it if necessary), or whichever plugin folder.
" 2. If desired, move these keymappings from smartcols.vim
"    to your .vimrc and/or change them.

:nmap > :call Shiftcolright()<CR>
:nmap < :call Shiftcolleft()<CR>
:nmap \| :call Aligncol()<CR>
:imap <S-Tab> <C-R>=Tabcolright()<CR>


"---------------------------------------
"
" TLDR:
" anything separated by two spaces or more is a "column"
"
" Normal mode:  >           pushes right to match column in row above
"               <           pushes left to match column in row above
"               |           attempts to align all columns to match row above
" Insert mode:  Shift-TAB   pushes right to match column in row above
"
"---------------------------------------
 
" Examples:
"
" >> Start with the following lines: we're in the middle of adding
" >> a second row.
"
" x = {  7,      8,      9,     10,     11,
"  12,  13,  14,  15,
"
" >> Move cursor to the 12 and press '>' to align 12 with next column.
"
" x = {  7,      8,      9,     10,     11,
"        12,  13,  14,  15,
"
" >> Go to end of line and press 'a' to enter insert mode.
" >> Press Shift-TAB twice to move to last column and type '16};'.
" 
" x = {  7,      8,      9,     10,     11,
"        12,  13,  14,  15,             16};
"
" >> Press ESC to exit insert mode, press 'b' to move to the beginning of
" 16, and press '<' to align it with the previous column.
"
" x = {  7,      8,      9,     10,     11,
"        12,  13,  14,  15,     16};
"
" >> Press '|' to auto-align all columns.
"
" x = {  7,      8,      9,     10,     11,
"        12,     13,     14,    15,     16};
"
"     





" -------------------------------------------
" Functions called internally
" -------------------------------------------


" Getcols -- given a string, identify and return the start index of all its
" columns. Change this to change the definition of a column.
" Return value should be a list of triples:
" [[start,end,contents],[start,end,contents],...]
function! Getcols(myline)
    let mycols  = []
    let index   = 0
    let colstartexpr = "\\s\\s\\S"
    let colendexpr   = "\\S\\s\\s"
    
    " if there's text at zero or one index, that's a column
    if len(a:myline) > 0 && a:myline[0] != " "
        call add(mycols,[0])
        let index = match(a:myline,colendexpr,0)
        if index < 0
            call add(mycols[0],len(a:myline)-1)
            call add(mycols[0],a:myline)
            return mycols
        else
            call add(mycols[0],index)
            call add(mycols[0],a:myline[ : index])
        endif
    elseif len(a:myline) > 1 && a:myline[1] != " "
        call add(mycols,[1])
        let index = match(a:myline,colendexpr,1)
        if index < 0
            call add(mycols[0],len(a:myline)-1)
            call add(mycols[0],a:myline[1 : len(a:myline)-1])
            return mycols
        else
            call add(mycols[0],index)
            call add(mycols[0],a:myline[1 : index])
            let index = index - 1
        endif
    endif

    " get all other columns
    while index >= 0
        let currcol = len(mycols)
        let index = matchend(a:myline,colstartexpr,index)
        if index >= 0
            let index = index-1
            call add(mycols,[index])
            let index = match(a:myline,colendexpr,index)
            if index < 0
                call add(mycols[currcol],len(a:myline)-1)
            else
                call add(mycols[currcol],index)
            endif
            call add(mycols[currcol],a:myline[mycols[currcol][0] : mycols[currcol][1]])
        endif
    endwhile

    return mycols
endfunction



" given current position and columns, get the start of the nearest col
" Going right: return 'i' when between end of i-1 and end of i
function! Getnearestrightcol(myxpos,mycols)
    let index = 0
    while index < len(a:mycols)
        if a:myxpos <= a:mycols[index][1]
            break
        endif
        let index = index+1
    endwhile
    if index >= len(a:mycols)
        let index = len(a:mycols)-1
    endif
    return index
endfunction


" given current position and columns, get the start of the nearest col
" Going left: return 'i' when between start of i and start of i+1
function! Getnearestleftcol(myxpos,mycols)
    let index = 0 
    if a:myxpos < a:mycols[0][0]
        return -1
    end
    while index < len(a:mycols)-1
        if a:myxpos < a:mycols[index+1][0]
            break
        endif
        let index = index+1
    endwhile
    return index
endfunction



" Infer from context where to shift me to
function! Getshiftrightpos(myxpos,mylinenum)
    let myline = getline(a:mylinenum)
    if a:mylinenum <= 1
        return -1
    endif
    let prevline = getline(a:mylinenum - 1)
    let prevcols = Getcols(prevline)
    let goalcol = Getnearestleftcol(a:myxpos,prevcols)
    if goalcol < 0 || goalcol >= len(prevcols)-1
        return -1
    endif
    return prevcols[goalcol+1][0]
endfunction

" Infer from context where to shift me to
function! Getshiftleftpos(myxpos,mylinenum)
    let myline = getline(a:mylinenum)
    if a:mylinenum <= 1 || a:myxpos <= 0
        return -1
    endif
    let prevline = getline(a:mylinenum - 1)
    let prevcols = Getcols(prevline)
    let goalcol = Getnearestleftcol(a:myxpos-1,prevcols)
    if goalcol < 0
        return -1
    endif
    let mycols = Getcols(myline)
    let newpos = prevcols[goalcol][0]
    let nexttomyleft = Getnearestrightcol(a:myxpos,mycols)
    if nexttomyleft >= 1
        let nexttomyleft = mycols[nexttomyleft-1][1]
        if newpos < nexttomyleft+1
            let newpos = nexttomyleft+1
        endif
    endif
    return newpos
endfunction


" actually do the shifting
function! Doshiftright(newxpos,oldxpos,mytext)
    let mycols = Getcols(a:mytext)
    let gap = a:newxpos - a:oldxpos
    if a:oldxpos <= 0
        return repeat(' ',gap) . a:mytext
    else
        return a:mytext[ : a:oldxpos-1] . repeat(' ',gap) . a:mytext[a:oldxpos : ]
    endif
endfunction

" actually do the shifting
function! Doshiftleft(newxpos,oldxpos,mytext)
    let mycols = Getcols(a:mytext)
    let setto = a:newxpos
    if setto == 0
        return a:mytext[a:oldxpos : ]
    else
        return a:mytext[ : setto-1] . a:mytext[a:oldxpos : ]
    endif
endfunction


" try to match my row to the given column
function! Trymatchto(mytext,matchcols)
    let mycols = Getcols(a:mytext)
    let ocols = a:matchcols
    
    " attempt to throw out irrelevent early items in matchcols
    while len(ocols) >= 1 && ocols[1][0] <= mycols[0][0]
        call remove(ocols,0)
    endwhile

    " if left column is in-between, move it right if they'll still line up
    if len(ocols) == len(mycols)+1 && ocols[1][0] > mycols[0][0]
        call remove(ocols,0)
    endif
    
    " loop through and align them
    let newtext = ""
    let index = 0
    let at = 0
    while index < len(mycols) && index < len(ocols)
        let gap = ocols[index][0] - at
        if gap > 0
            let newtext = newtext . repeat(' ',gap)
            let at = at + gap
        endif
        let newtext = newtext . mycols[index][2]
        let at = at + len(mycols[index][2])
        let index = index + 1
    endwhile
    
    " add back in anything left over
    if index < len(mycols)
        let newtext = newtext . a:mytext[mycols[index-1][1]+1 : ]
    end

    return newtext
endfunction



" =============================================
" Normal Mode Commands (column manipulation)
" =============================================


" normal mode, shift a column to the right: >
" Shiftcolright
function! Shiftcolright()
    let mylinenum = line(".")
    let myxpos    = col(".")-1
    let mytext    = getline(mylinenum)
    let mycols    = Getcols(mytext)
    let mycolnum  = Getnearestrightcol(myxpos,mycols)     " move to start of column we're in
    if mycolnum < 0
        return
    endif
    let newxpos = Getshiftrightpos(myxpos,mylinenum)  " figure out from context where to shift to
    if newxpos < 0
        return
    endif
    let newtext = Doshiftright(newxpos,mycols[mycolnum][0],mytext) " do shift with text, or column num (let them write)
    call setline(mylinenum,newtext)
    call cursor(mylinenum,newxpos+1)
endfunction

function! Shiftcolleft()
    let mylinenum = line(".")
    let myxpos    = col(".")-1
    let mytext    = getline(mylinenum)
    let mycols    = Getcols(mytext)
    let mycolnum  = Getnearestleftcol(myxpos,mycols)     " move to start of column we're in
    if mycolnum < 0
        return
    endif
    let newxpos = Getshiftleftpos(myxpos,mylinenum)  " figure out from context where to shift to
    if newxpos < 0
        return
    endif
    let newtext = Doshiftleft(newxpos,mycols[mycolnum][0],mytext) " do shift with text, or column num (let them write)
    call setline(mylinenum,newtext)
    call cursor(mylinenum,newxpos+1)
endfunction


function! Aligncol()
    let mylinenum = line(".")
    if mylinenum <= 1
        return
    endif
    let myxpos = col(".")-1
    let mytext = getline(mylinenum)
    let mycols = Getcols(mytext)
    let mycolnum = Getnearestleftcol(myxpos,mycols)
    let mycoloffset = myxpos - mycols[mycolnum][0]
    let matchcols = Getcols(getline(mylinenum-1))
    let newtext = Trymatchto(mytext,matchcols)
    let mycols = Getcols(newtext)
    
    call setline(mylinenum,newtext)
    call cursor(mylinenum,mycols[mycolnum][0] + mycoloffset + 1)
endfunction






" =============================================
" Insert Mode Commands (column manipulation)
" =============================================


function! Tabcolright()
    let mylinenum = line(".")
    let myxpos    = col(".")-1
    let mytext    = getline(mylinenum)
    let newxpos = Getshiftrightpos(myxpos,mylinenum)  " figure out from context where to shift to
    if newxpos < 0
        return ""
    endif
    let newtext = Doshiftright(newxpos,myxpos,mytext) " do shift with text, or column num (let them write)
    call setline(mylinenum,newtext)
    call cursor(mylinenum,newxpos+1)
    return ""
endfunction

   



