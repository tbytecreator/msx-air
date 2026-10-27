import re

G = chr(0x17)  # arrow glyph


def build(segs):
    """segs: list of ('e', end_col, text) / ('s', start_col, text)"""
    out = ''
    for kind, col, text in segs:
        start = col - len(text) if kind == 'e' else col
        assert start >= len(out), (kind, col, text, out)
        out = out.ljust(start) + text
    return out


def E(col, text):
    return ('e', col, text)


def S(col, text):
    return ('s', col, text)


ESC = S(72, ' ESCape')


def q(text):
    """text -> list of db items; G becomes 17H"""
    items = []
    for i, part in enumerate(text.split(G)):
        if i:
            items.append('17H')
        if part:
            if "'" in part:
                items.append('"%s"' % part)
            else:
                items.append("'%s'" % part)
    return items


def dbline(items):
    return '                db ' + ','.join(items)


def dialog(label, rows, term='nul', sep='cr,lf'):
    """rows: list of strings (already built); '' = blank row"""
    lines = []
    for i, r in enumerate(rows):
        items = q(r)
        last = i == len(rows) - 1
        if last:
            items += term.split(',')
        else:
            items += sep.split(',')
        if r == '' and not last:
            items = sep.split(',')
        lines.append(items)
    out = []
    for i, items in enumerate(lines):
        pre = (label + ':').ljust(16) if i == 0 else ' ' * 16
        out.append(pre + 'db ' + ','.join(items))
    return '\n'.join(out)


def one(label, text, term='nul'):
    return (label + ':').ljust(16) + 'db ' + ','.join(q(text) + term.split(','))


def msg(label, col, text, term='nul'):
    return one(label, ' ' * col + text, term)


def hl(text):
    assert len(text) <= 80, (len(text), text)
    return text.ljust(80)


L = []
a = L.append

# ---- key tables -------------------------------------------------------
def table(label, keys):
    out = []
    for i, (k, c) in enumerate(keys):
        pre = (label + ':').ljust(16) if i == 0 else ' ' * 16
        out.append(pre + 'db ' + k + ' ' * max(1, 24 - len(k)) + ';' + c)
    out.append(' ' * 16 + 'db 0')
    return '\n'.join(out)


def keys(s):
    out = []
    for x in s.split():
        if x == 'esc':
            out.append(('ESC', 'ESCape'))
        elif x in ('DOWN', 'UP', 'RIGHT', 'LEFT'):
            out.append((x, 'cursor key'))
        elif x == '255':
            out.append(('255', 'Function key'))
        else:
            out.append(("'%s'" % x, ''))
    return out


a(';English hot-key characters for the function keys\n')
a(';Function key 2\n')
a(table('F2KAR', keys('l r g s w t m p o d v 255')))
a('\n;Function key 3\n')
a(table('f3Kar', keys('f w d b p c e l s h 255')))
a('\n;Function key 4\n')
a(table('F4KAR', keys('a f s l g p t 255')))
a('\n;Function key 5\n')
a(table('f5Kar', keys('b e u c w m p t l s i 255')))
a('\n;F2/Tab\n')
a(table('tabKar', keys('esc m s l')))
a('\n;F2/MemMap\n')
a(table('memKar', keys('esc m v')))
a('\n;F2/Save settings\n')
a(table('insKar', keys('esc e t f l')))
a('\n;F3/Column\n')
a(table('kolKar', keys('esc n')))
a('\n;F3/Disk directory\n')
a(table('inhKar', keys('esc DOWN UP RIGHT LEFT d l b w m c s')))
a('\n;F3/Page\n')
a(table('pageKar', keys('esc p r a n s b')))
a('\n;F3/Help\n')
a(table('hlpKar', keys('esc t m')))
a('\n;F2/Printer settings\n')
a(table('PRTKAR', keys('esc s t b l 1 2 m a d e n h o f c r g k i')))
a('\n;Screen settings\n')
a(table('scrKar', keys('esc s c b z t l m e a r h k n f')))
a('\n;F4/Go To\n')
a(table('goKar', keys('esc l t b s e')))
a('\n;F2/Paragraph settings\n')
a(table('ALIKAR', keys('esc j h i c')))
a('\n;F5/Indent\n')
a(table('indKar', [('ESC', 'ESCape'), ("'n'", 'Number of positions'), ('left', ''), ('right', '')]))
a('''
                ;Video-RAM addresses of on-screen texts/values

VRMREG          equ 18                  ;Line number
VRMKOL          equ 30                  ;Column number
VRMPAG          equ 41                  ;Page number
VRMTF7          equ 46                  ;'F7:Help' (help label)

                ;Cursor positions of on-screen texts / values

XYFNK           equ 3101H               ;F2/X etc
XZOEK           equ 15                  ;Search-text field

                ;On-screen texts

if              DEMO

TINTRO:         db cr
                db 9,9,9,'  MSX2 Word Processor - Editor',cr,lf
                db 9,9,9,9,'by M.J. Vriend',cr,lf
                db 9,9,9,9,'(c) 1992 Jos-Tel',cr,lf
                db 9,9,'   Demonstration version - copying allowed',cr,lf,lf,nul
TGETNAME:
TGETCODE:
TACCESS:
TGEBR:
else
TINTRO:         db cr
                db 9,9,9,'  MSX2 Word Processor - Editor',cr,lf
                db 9,9,9,9,'by M.J. Vriend',cr,lf
                db 9,9,9,9,'(c) 1992 Jos-Tel',cr,lf
                db 9,9,9,'   Copying  NOT  allowed',cr,lf,lf,nul

TGETNAME:       db tab,tab,'Request your code from Jos-Tel!!',cr,lf,lf
                db tab,tab,'User name: ',nul
TGETCODE:       db cr,lf,tab,tab,'User code: ',nul
TACCESS:        db cr,lf,tab,tab,'Access code: ',nul
TGEBR:          db cr,lf,tab,'User: ',nul
endif

                ;Information ticker text

KRTSTART:       db "              M.J. Vriend's TED "

if              DEMO
                db 'demonstration '
endif
                db 'version #2.65 (17 November 1992) '
                db 'copyright (C) 1992 Jos-Tel Aktie M.S. '
                db 'The proceeds of TED benefit '
                db 'the Dutch Multiple Sclerosis Foundation. '
if              DEMO
                db 'Order the new TED #2.65 from Jos-Tel. '
endif
                db 'For more information call the Jos-Tel databank 05149-1837, '
                db '24 hours a day online. Or write to Jos de Boer, Kampenspaed 4, 8721 GL  WARNS.'
KRTEND:         db '                '
TNOKRT:         db "MJV's TED v#2.6]"
TF7:            db 'F7:Help '
''')

status = ('Insert:ON'.ljust(13) + 'Line:' + ' ' * 7 + 'Col.:' + ' ' * 6 + 'Page:' + ' ' * 5)
assert len(status) == 46, len(status)
status2 = "F7:Help [MJV's TED v#2.6]  0.00:00"
assert len(status + status2) == 80
a("TSTATUS:        db '%s'\n                db \"%s\"" % (status, status2))

H = [
 ' F1/6=PgDn/PgUp  F2=Settings  F3=System  F4=Commands  F5=Block_functions',
 ' Left/Right-mar. paraGraph Set/Wipe-Tab Memmap Printer-Driver sOrt saVe' ,
 ' Free Wipe Directory coLumn Page Colour Backup Extension Screen Help',
 ' Again-Find  Go_to  Print  Save/Load_text  0..9-mark  sTop',
 ' Begin End Undefine Copy Wipe Move Print sorT Indent Load Save',
]
def bar(text, esc=True):
    tail = ' ESCape '
    if not esc:
        return text.ljust(80)
    return text.ljust(80 - len(tail)) + tail
a(one('THULP0', bar(H[0], False)))
a(one('THULP2', bar(H[1]), term='').rstrip(','))
a(one('THULP3', bar(H[2]), term='').rstrip(','))
a(one('THULP4', bar(H[3]), term='').rstrip(','))
a(one('THULP5', bar(H[4]), term='').rstrip(','))
a('')
a(one('TAAN', 'ON '))
a(one('TUIT', 'OFF'))
a(msg('TREGNR', 24, 'Go to line number: '))
a(msg('TLINKS', 24, 'Left margin: '))
a(msg('TRECHTS', 24, 'Right margin: '))
a(msg('TSELECTIE', 24, 'Selection - Filename: '))
a(one('TPAD', ' Path:    '))
a(one('TINH', ' <%s %s>  Load  Block  Charset  Settings  Mail-Merge  Wipe  Directory  ESCape' % (G, G)))
a(one('TVRIJ', '-Free on A:       k.'))
a(one('TVOLUME', ' Diskname: '))
a(msg('TSAVEN', 16, 'Save current text to disk? (y/n) '))
a('tabCHR:         db tab,nul')
a("tDirChr:        db ' d',tab,nul")
a('')
a(msg('TVLDERR', 16, '*** Field falls outside the record'))
a(msg('TNOPB', 16, '*** No buffer present'))
a(msg('TNEXTPG', 16, '*** Insert next page'))
a(one('TDRUK', ' *** - Press a key... '))
a('')
a(msg('TMOMENT', 32, '*** One moment... *** '))
a(msg('TMEER', 32, 'Any more? (y/n) '))
a(msg('TZEKER', 24, 'Are you sure? (y/n) '))
a('')
a(dialog('TMEMMAP', [build([E(42, 'use of the MM:'), ESC]), build([E(42, 'use of Vram: ')])]))
a(msg('TKEUZE', 32, 'Make your choice: '))
a(dialog('TtabCH', [
    build([E(41, 'use tab characters in Memory:'), ESC]),
    build([E(41, 'Save tab characters to disk:')]),
    build([E(41, 'Load tab characters from disk:')])]))
a('xTabIns         equ 43\n')
a(dialog('tAlinea', [build([E(11, 'Justify:'), E(26, 'Hyphenate:'), E(49, 'hyphen Char:'), E(64, 'Indent:'), ESC])]))
a('xUitvul         equ 13\nxAfbreek        equ 28\nxStreep         equ 51\nxInspr          equ 66\n')
a(dialog('tIndent', [
    build([E(52, 'Number of positions to shift:'), ESC]), '',
    build([S(24, 'press <%s or %s> to start' % (G, G))])]))
a('\nxAantPos        equ 54\n')
a(dialog('TSORT', [
    build([E(20, 'Record length:'), S(25, 'line(s)'), ESC]), '',
    build([E(28, 'sort on A: field:'), E(46, 'column:')]),
    build([E(28, 'B: field:'), E(46, 'column:')]),
    build([E(28, 'C: field:'), E(46, 'column:')])]))
a(dialog('TKOLOM', [build([E(40, 'Number of columns:'), ESC])], term='lf,nul'))
a(msg('TKOLPOS', 22, 'column position ', term='nul').replace("db ' ", "db cr,lf,' ", 1))
a(dialog('tPage', [
    build([S(24, 'Place page-stop'), ESC]),
    build([S(24, 'Remove current page-stop')]),
    build([S(24, 'remove All page-stops')]), '',
    build([E(52, 'page-Number indication: ')]),
    build([E(52, 'page-Stop indication line: ')]),
    build([E(52, 'page-Boundary indication line: ')])]))
a(dialog('tGoto', [
    build([S(18, 'Go to:'), S(24, 'Top of text'), S(48, 'Start of block'), ESC]),
    build([S(24, 'Bottom of text'), S(48, 'End of block')]),
    build([S(24, 'Line number'), S(48, 'mark 0..9')])]))
a(dialog('TKLEUR', [
    build([S(36, 'Blue'), S(43, 'Red'), S(49, 'Green'), ESC]),
    build([E(35, 'Text background:')]),
    build([E(35, 'Text foreground:')]),
    build([E(35, 'Cursor background:')]),
    build([E(35, 'Cursor foreground:')])]))
a(dialog('TEXT', [build([E(44, 'Default extension: ')])]))
a(dialog('TBACKUP', [
    build([E(44, 'Create Backup:'), ESC]), '',
    build([E(44, 'Automatic saving:')]),
    build([E(44, 'number of keyStrokes:')])]))
a(dialog('TSCHERM', [
    build([E(32, 'cursor Colours:'), E(60, 'Edit mode:'), ESC]),
    build([E(32, 'Block cursor:'), E(60, 'Auto-indent:')]),
    build([E(32, 'command bar on Screen:'), E(60, 'key Repeat:')]),
    build([E(32, 'leading Zeros in clock:'), E(60, 'blinKing cursor:')]),
    build([E(32, 'Ticker:'), E(60, 'cursor blink time oN:')]),
    build([E(32, 'Large letters in help menu:'), E(60, 'cursor blink time oFf:')]),
    '',
    'Msx char. set: ',
    'cHaracter set: '], term='nul', sep='cr,lf'))
a(dialog('TDRIVER', [build([E(43, 'Use driver:'), S(72, ' Return')])]))
a(dialog('TGETDRV', [build([E(31, 'Type a character: '), ESC])]))
a(dialog('TPRTINS', [
    build([E(15, 'Setup string:'), ESC]),
    build([E(15, 'Top margin:'), E(45, 'first page Number:'), E(74, 'header maRgin:')]),
    build([E(15, 'Bottom margin:'), E(45, 'Header line position:'), E(74, 'footer marGin:')]),
    build([E(15, 'page Length:'), E(45, 'fOoter line position:'), E(74, 'Formfeed:')]),
    build([E(74, 'Continuous printing:')]),
    build([S(1, '1:header and 2:footer line    ($p=page number)')]),
    '', '', '',
    build([E(15, 'Mail-merge:'), E(38, 'Initial record:'), E(74, 'merge marKer:')]),
    build([E(15, 'file nAme:')]),
    build([E(15, 'recorD end:')]),
    build([E(15, 'field End:')])]))
a(dialog('TPSTAT', [build([E(22, 'Current line:'), S(22, ' 1'), E(44, 'Last line:'), S(44, ' ')])]).replace(',cr,lf,nul', ',nul'))
a(one('TKAART', 'Current record:'))
a(msg('TPBEGON', 24, '*** Printing started... ***'))
a(dialog('TMEM', [build([S(16, 'Memory  kilobytes')]), build([E(25, 'total:')]), build([E(26, 'free: ')])]))
a(dialog('TAFBR', [build([S(4, 'move with arrows: <%s %s>  hyphenate: Return  wrap: Space' % (G, G)), ESC])]))
a(dialog('TWIS', [build([S(24, 'wipe  Text'), ESC]), build([S(24, 'clear Printer buffer')])]))
a(dialog('TCPHULP', [build([S(24, 'copy help to the Text'), ESC]), build([S(24, 'copy help to the Menu')])]))
a(msg('TTOETS', 24, '*** Press a key... *** '))
a('')
for lab, col, t in [
    ('TRECERR', 8, '*** End of record not found'),
    ('TREGLEN', 16, '*** Line too long'),
    ('TONDERB', 16, '*** Interrupted'),
    ('TMEMVOL', 16, '*** Memory full'),
    ('TTOMANY', 8, '*** Filename error or disk directory full'),
    ('TDISKVOL', 16, '*** Disk full'),
    ('TPROT', 8, '*** Disk write protected'),
    ('TNODISK', 4, '*** No (good) disk present'),
    ('TDSKERR', 16, '*** Disk error'),
    ('TVERERR', 16, '*** Not a TED 2.6 file'),
    ('TKARERR', 16, '*** Character set not found'),
    ('TNOTFND', 16, '*** Not found'),
    ('tPageTabFull', 16, '*** Page table full'),
    ('tStkErr', 16, '*** Not enough stack memory')]:
    a(msg(lab, col, t))
a(one('TPROB', ' ***  -  Retry? (y/n) '))
a(msg('TVERVANG', 32, 'Replace? (y/n) '))
a(msg('TSAVNAM', 25, 'Save - Name: '))
a(msg('TLOADNAM', 25, 'Load - Name: '))
a(dialog('TSAVINS', [
    build([S(8, 'save and load settings with Every text:'), ESC]), '',
    build([S(8, 'save current settings in Ted')]),
    build([S(8, 'save current settings in a File')]),
    build([S(8, 'Load settings from a file')])]))
a(dialog('TZOEK', [' Search   for:', ' Replace with:']))
a(dialog('TZOEK2', [
    ' F1:   NO  Case-sensitive search',
    ' F2:   Forward search',
    ' F3:   Conditional replace', '',
    build([S(1, 'Choose F1, F2 or F3, Return to start'), ESC])]))
a(one('TWEL', 'YES '))
a(one('TACHTER', ' Backward search'))
a(one('TONV', ' Unconditional replace'))

open('/tmp/ted/en_block.mac', 'w').write('\n'.join(L) + '\n')
