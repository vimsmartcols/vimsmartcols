" vimsmartcols
"
" vim global plugin for smart columns
" 
" v0.19
"
" Bo Waggoner
" vimsmartcols@gmail.com
" https://github.com/vimsmartcols/vimsmartcols
" Modified: 2012-06-17
" 
" This software is free.
"
" --------------------------------------

" Install:
" 1. put this file in directory ~/.vim/plugins
"    (creating it if necessary), or whichever plugin folder.
" 2. Change the following settings and keymappings to suit
"    your preference, if you want.

" the minimum number of spaces separating columns
let g:smartcolsep = 2

" when aligning, allow skipping this many rows
let g:smartcolskip = 1


:nmap <C-l>      :call Movecol(1)<CR>
:nmap <C-h>      :call Movecol(-1)<CR>
:nmap <S-l>      :call Indentcol(1)<CR>
:nmap <S-h>      :call Indentcol(-1)<CR>
:nmap <TAB>      :call Indentcol(&tabstop)<CR>
:nmap <S-TAB>    :call Indentcol(-&tabstop)<CR>
:nmap >          :call Matchcol(1)<CR>
:nmap <          :call Matchcol(-1)<CR>

:imap <S-TAB>    <C-R>=Matchcol(1)<CR>


"---------------------------------------
"
" Summary
" Anything separated by g:smartcolsep spaces or more is a 'column'.
" Columns span vertically as many lines as they are continued unbroken,
" subject to the following:
"   -- a column can skip over at most g:smartcolskip lines total.
"   -- not included in the above, the function Canskirow() details when
"      a row may be skipped for free. (Example: comment lines in C/C++.)
"   -- overriding the above, a column cannot span past an unskippable
"      row as defined in Cannotskiprow(). (Example: { or } in C/C++).
"
" Normal mode:  Ctrl-l      moves cursor one column to the right
"               Ctrl-h      moves cursor one column to the left
"               Shift-l     push entire column right
"               Shift-h     push entire column left
"               Tab         push entire column right one tabstop length
"               Shift-Tab   push entire column left one tabstop length
"               >           push current position right to match columns nearby
"               <           push current position left to match columns nearby
"
" Insert mode:  Shift-Tab   pushes current position right to match columns nearby
"
"---------------------------------------
" 
" Example (movement):
"   let  x  =  17
" Put cursor on beginning of line and press Ctrl-l. This moves one column to
" the right.Now cursor is on 'l' in let. Press Ctrl-l again; now on 'x'.
" Press Ctrl-h; now on 'l' again.
" 
" Example (pushing columns):
"   let  x  =  17
"   let  y  =  22
" Put cursor on either '=' and press Shift-l. This pushes the entire column
" right one space. Result:
"   let  x   =  17
"   let  y   =  22
" Pressing Shift-h will push it back to the left.
"
" Example (matching columns):
"   let  x         =  17
"   let y =  22
" Put cursor on '=' in second line and press >. This pushs the equals sign
" to the nearest surrounding column on the right. Result:
"   let  x         =  17
"   let y          =  22
" 
" Example (insert mode):
"   let  x         = 17
"   let  y
" Put cursor on 'y' and press a to enter insert mode. Now press Shift-Tab;
" this moves the cursor rightward to the nearest surrounding column. Type =.
"   let  x         = 17
"   let  y         =
"
"----------------------------------------


" Move cursor 'direction' columns (positive is right, negative is left).
" If asked to move to an extreme, goes to the first or last character.
function Movecol(direction)
    let l:mylinenum = line(".")
    let l:myxpos    = col(".")-1
    let l:mytext    = getline(l:mylinenum)
    let l:mycols    = Getcols(l:mytext)
    let l:currcol   = Getcurrentcol(l:myxpos,l:mycols)
    let l:goalcol   = l:currcol + a:direction
    " If moving left, and not already at leftmost position in col, count that as a move
    if a:direction < 0 && l:mycols[l:currcol][0] < l:myxpos
        let l:goalcol = l:goalcol + 1
    endif
    if l:goalcol < 0
        let l:goalpos = 0
    elseif l:goalcol >= len(l:mycols)
        let l:goalpos = len(l:mytext) - 1
    else
        let l:goalpos = l:mycols[l:goalcol][0]
    endif
    call cursor(l:mylinenum,l:goalpos+1)
endfunction

" If 'direction' > 0: repeat operation 'IndentRight' 'direction' times.
" 'IndentRight': find current column and all matching columns above and below;
"                move them one space to the right.
" Analogous if 'direction' < 0. But stop each row if you run into text on the left.
function Indentcol(direction)
    let l:dir       = a:direction
    let l:mylinenum = line(".")
    let l:myxpos    = col(".")-1
    let l:finalxpos = l:myxpos
    let l:currpos   = l:myxpos
    if a:direction > 0
        let l:dx = 1
    elseif a:direction < 0
        let l:dx = -1
    else
        return 0
    endif
    while l:dir != 0
        let l:rows  = Getrowswithcol(l:mylinenum,l:currpos)
        for l:r in l:rows
            call Trytoindent(l:r,l:currpos,l:dx)
        endfor
        if l:finalxpos == l:currpos
            " if indentation is successful, they will still be equal next
            " loop; else, stop trying from now on
            let l:result = Trytoindent(l:mylinenum,l:currpos,l:dx)
            let l:finalxpos = l:finalxpos + l:result
        endif
        let l:currpos = l:currpos + l:dx
        let l:dir = l:dir - l:dx
    endwhile
    call cursor(l:mylinenum,l:finalxpos+1)
endfunction

" If 'direction' > 0: repeat operation 'ShiftRight' 'direction' times.
" 'ShiftRight': list all nearby columns, pick closest one that is on the right.
"               (If none, give up.) Add spaces to move cursor to that x-position.
" Analogous if 'direction' < 0.
function Matchcol(direction)
    let l:dir       = a:direction
    let l:mylinenum = line(".")
    let l:myxpos    = col(".")-1
    if a:direction > 0
        let l:dx = 1
    elseif a:direction < 0
        let l:dx = -1
    else
        return ""
    endif
    let l:nearcols = Getnearbycols(l:mylinenum,l:myxpos)
    while l:dir != 0
        let l:nextx = Getnextxpos(l:nearcols,l:myxpos,l:dx)
        if l:nextx < 0
            break
        endif
        let l:diff = l:nextx - l:myxpos
        let l:result = Trytoindent(l:mylinenum,l:myxpos,l:diff)
        let l:myxpos = l:myxpos + l:result
        if l:result != l:diff
            break   " unable to make full progress
        endif
        let l:dir = l:dir - l:dx
    endwhile
    call cursor(l:mylinenum,l:myxpos+1)
    return ""
endfunction




" -------------------------------------------
" Functions called internally
" -------------------------------------------


" Getcols -- given a string, identify and return the start index of all its
" columns. Change this to change the definition of a column.
" Return value should be a list of triples:
" [[start,end,contents],[start,end,contents],...]
function Getcols(myline)
    let mycols  = []
    let index   = 0
    let colstartexpr = repeat("\\s",g:smartcolsep) . "\\S"
    let colendexpr   = "\\S" . repeat("\\s",g:smartcolsep)
    
    " first check indices 0, 1, ..., smartcolsep-1
    let pos = 0
    while pos < g:smartcolsep && pos < len(a:myline)
        if a:myline[pos] != ' '
            call add(mycols,[pos])
            let index = match(a:myline,colendexpr,0)
            if index < 0
                call add(mycols[0],len(a:myline)-1)
                call add(mycols[0],a:myline[pos : ])
                return mycols
            else
                call add(mycols[0],index)
                call add(mycols[0],a:myline[pos : index])
            endif
            break
        endif
        let pos = pos + 1
    endwhile
    
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


" Return the current column we are in. Return -1 if to the left of all cols.
function Getcurrentcol(xpos,mycols)
    let l:answer = 0
    " find first column that's strictly right of xpos
    while l:answer < len(a:mycols) && a:mycols[l:answer][0] <= a:xpos
        let l:answer = l:answer + 1
    endwhile
    return l:answer-1
endfunction


" Getnearbycols -- return an array of rows: result[i] = [rownumber, cols]
"   where cols is the result of Getcols(getline(rownumber)).
function Getnearbycols(linenum,xpos)
    let l:rows = []
    let l:tryrow = a:linenum - 1
    let l:numskips = 0
    while l:tryrow >= 1 && l:numskips <= g:smartcolskip && !Cannotskiprow(l:tryrow)
        let l:cols = Getcols(getline(l:tryrow))
        call add(l:rows,[l:tryrow,l:cols])
        let l:currcol = Getcurrentcol(a:xpos,l:cols)
        if l:currcol < 0 || l:cols[l:currcol][0] != a:xpos
            if !Canskiprow(l:tryrow)
                let l:numskips = l:numskips + 1
            endif
        endif
        let l:tryrow = l:tryrow - 1
    endwhile
    let l:numskips = 0
    let l:tryrow = a:linenum + 1
    while l:tryrow <= line("$") && l:numskips <= g:smartcolskip && !Cannotskiprow(l:tryrow)
        let l:cols = Getcols(getline(l:tryrow))
        call add(l:rows,[l:tryrow,l:cols])
        let l:currcol = Getcurrentcol(a:xpos,l:cols)
        if l:currcol < 0 || l:cols[l:currcol][0] != a:xpos
            if !Canskiprow(l:tryrow)
                let l:numskips = l:numskips + 1
            endif
        endif
        let l:tryrow = l:tryrow + 1
    endwhile
    return l:rows
endfunction


" Getnextxpos -- given a list of rows, each with column info, find
" the position of the next column in the given direction 
function Getnextxpos(rowcols,xpos,dir)
    let l:best = -1
    for l:r in a:rowcols
        for l:col in l:r[1]
            if a:dir > 0
                if l:col[0] > a:xpos
                    if l:best == -1 || l:col[0] < l:best
                        let l:best = l:col[0]
                        break
                    endif
                endif
            else
                if l:col[0] < a:xpos
                    if l:col[0] > l:best
                        let l:best = l:col[0]
                    endif
                endif
            endif
        endfor
    endfor
    return l:best
endfunction


" Getrowswithcol -- get the nearby rows that have a column at xpos.
function Getrowswithcol(linenum,xpos)
    let l:rows = []
    let l:rowcols = Getnearbycols(a:linenum,a:xpos)
    for l:r in l:rowcols
        let l:cols = l:r[1]
        let l:mycol = Getcurrentcol(a:xpos,l:cols)
        if l:mycol >= 0 && l:cols[l:mycol][0] == a:xpos
            call add(l:rows,l:r[0])
        endif
    endfor
    return l:rows
endfunction


" Cannotskiprow -- contains exceptions to allowable skips.
function Cannotskiprow(row)
    if &ft == "c" || &ft == "cpp"
        if !empty(matchstr(getline(a:row),"{"))
            return 1
        elseif !empty(matchstr(getline(a:row),"}"))
            return 1
        endif
    endif
    return 0
endfunction


" Canskiprow -- contains exceptions to the skipping rule; e.g.
function Canskiprow(row)
    if &ft == "c" || &ft == "cpp"
        " If the line contains nothing or only a comment, we're allowed to skip it
        let l:str = getline(a:row)
        let l:ind = 0
        while l:ind < len(l:str) && (l:str[l:ind] == " " || l:str[l:ind] == "\t")
            let l:ind = l:ind+1
        endwhile
        if l:ind == len(l:str) || (l:ind+1 < len(l:str) && l:str[l:ind : l:ind+1] == "//")
            return 1
        endif
    endif
    return 0
endfunction


" Trytoindent -- tries to add/remove spaces to a row at xpos
" return number of spaces added (so if we remove 2, return -2).
function Trytoindent(linenum,xpos,dir)
    let l:text = getline(a:linenum)
    if a:dir > 0
        if a:xpos == 0
            call setline(a:linenum,repeat(' ',a:dir) . l:text)
        else
            call setline(a:linenum,l:text[ : a:xpos-1] . repeat(' ',a:dir) . l:text[a:xpos : ])
        endif
        return a:dir
    elseif a:dir < 0
        let l:diff = 0
        while a:xpos - l:diff > 0
            if l:text[a:xpos-l:diff-1] != ' ' && l:text[a:xpos-l:diff-1] != '\t'
                break
            endif
            let l:diff = l:diff + 1
        endwhile
        " after shifting, gap before us should be g:smartcolsep
        let l:amount = -a:dir
        if l:amount > a:xpos
            let l:amount = a:xpos
        endif
        if l:diff < a:xpos
            if l:amount > l:diff - g:smartcolsep
                let l:amount = l:diff - g:smartcolsep
                if l:amount <= 0
                    return 0
                endif
            endif
        endif
        let l:index = a:xpos - l:amount
        if l:index == 0
            call setline(a:linenum, l:text[a:xpos : ])
        else
            call setline(a:linenum, l:text[ : l:index-1] . l:text[a:xpos : ])
        endif
        return -l:amount
    endif
    return 0
endfunction


