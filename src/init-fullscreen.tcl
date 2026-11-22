# O ImGui carrega este arquivo no primeiro quadro, depois dos scripts de startup.
set imgui_dir $::env(OPENMSX_USER_DATA)
set imgui_file [file join $imgui_dir imgui.ini]
file mkdir $imgui_dir
set imgui_content ""
if {[file exists $imgui_file]} {
    set input [open $imgui_file r]
    try {
        set imgui_content [read $input]
    } finally {
        close $input
    }
}

set in_openmsx_section false
set imgui_section ""
set lines {}
foreach line [split $imgui_content "\n"] {
    if {[string index $line 0] eq "\["} {
        set in_openmsx_section [regexp {^\[openmsx\]\[([^\]]+)\]} $line -> imgui_section]
    } elseif {$in_openmsx_section && [regexp {^(show|open|showQuickSetupEditor|showScreenshot|showRecord|showControl|showRegisters|showSlots|showStack|showFlags|showXYFlags|showSelect|showConfig|showLog|showConfigure|mainMenuBarUndocked|statusBarVisible)=} $line -> key]} {
        set line "$key=0"
    } elseif {$in_openmsx_section && $imgui_section eq "debugger" &&
              [regexp {^(disassemblyViewers|bitmapViewers|tileViewers|spriteViewers|smsVdpTileViewers|smsVdpSpriteViewers|smsVdpRegsViewers|hexEditor\..*|debuggableBitmap\..*)=} $line -> key]} {
        set line "$key=0"
    } elseif {$in_openmsx_section && [string match "mainMenuBarFade=*" $line]} {
        set line "mainMenuBarFade=1"
    }
    lappend lines $line
}

# Essas opções têm valor padrão visível mesmo sem imgui.ini anterior.
lappend lines {[openmsx][machine]} {showQuickSetupEditor=0} \
    {[openmsx][reverse bar]} {show=0} \
    {[openmsx][OSD icons]} {show=0}
set output [file tempfile tmp_file [file join $imgui_dir .imgui-XXXXXX]]
try {
    puts $output [join $lines "\n"]
    close $output
    file rename -force -- $tmp_file $imgui_file
} finally {
    if {[file exists $tmp_file]} {
        file delete -- $tmp_file
    }
}

set fullscreen on
