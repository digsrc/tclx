#
# bldmanhelp.tcl --
#
#  Build help files from the manual pages.  This uses a table of manual
# pages, sections. Brief entries are extracted from the name line.
# This is not installed as part of Extended Tcl, its just used during the
# build phase.
#
# This program is very specific to extracting manual files from John
# Ousterhout's Tcl and Tk man pages.  Its not general.
#
# The command line is:
#
#   bldmanhelp.tcl docdir maninfo helpdir
#
# Where:
#    o docdir is the directory containing the manual pages.
#    o maninfo is the path to a file that when sources returns a list of
#      entries describing manual pages to convert.  Each entry is a list
#      of manual file and the path of the help file to generate.
#    o helpdir is the directory to create the help files in.
#    o brief is the brief file to create.
#------------------------------------------------------------------------------
# Copyright 1992-1993 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# $Id: bldtkhelp.tcl,v 1.3 1993/06/17 05:25:41 markd Exp markd $
#------------------------------------------------------------------------------
#

#-----------------------------------------------------------------------------
# Process the name section.  This is used to generate a '@brief: entry.

proc ProcessNameSection {manFH outFH} {
    set line [gets $manFH]
    case [lindex $line 0] {
        {.HS .BS .BE .VS .VE} {
            set line [gets $manFH]
        }
    }
    set brief [string trim [crange $line [string first - $line]+1 end]]
    puts $outFH "'@brief: $brief"
}

#-----------------------------------------------------------------------------
# Copy the named manual page source to the target, recursively including
# .so files.  Remove macros usages that don't work good in a help file.

proc CopyManPage {manPage outFH} {
    global skipSection

    set stat [catch {
        open $manPage
    } fh]
    if {$stat != 0} {
        puts stderr "can't open \"$manPage\" $fh"
        return
    }
    while {[gets $fh line] >= 0} {
        case [lindex $line 0] {
            {.so} {
                CopyManPage [lindex $line 1] $outFH
            }
            {.SH} {
                set skipSection 0
                case [lindex $line 1] {
                    {NAME} {
                        ProcessNameSection $fh $outFH
                    }
                    {SYNOPSIS} {}
                    default {
                        puts $outFH $line
                    }
                }
            }
            {.HS .BS .BE .VS .VE} {
            }
            default {
                if !$skipSection {
                    puts $outFH $line
                }
            }
        }
    }
    close $fh
}

#-----------------------------------------------------------------------------
# Process a manual file and copy it to the temporary file.  Assumes current
# dir is the directory containing the manual files.

proc ProcessManFile {ent tmpFH} {
    global skipSection
    set skipSection 0
    puts $tmpFH "'@help: [lindex $ent 1]"
    CopyManPage [lindex $ent 0] $tmpFH
    puts $tmpFH "'@endhelp"
}

#-----------------------------------------------------------------------------
# Procedure to create a temporary file containing the file constructed
# for input to buildhelp.
#

proc GenInputFile {docDir manInfoTbl tmpFile} {

   set tmpFH [open $tmpFile w]
   set cwd [pwd]
   cd $docDir

   foreach ent $manInfoTbl {
       puts stdout "    preprocessing $ent"
       ProcessManFile $ent $tmpFH
   }
   cd $cwd
}

#-----------------------------------------------------------------------------
# Main program for building help from manual files.  Sets up a fake command
# line and sources buildhelp.tcl once a tmp input file has been constructed.

if {[llength $argv] != 4} {
    error "wrong # args: bldmanhelp docdir maninfo helpdir brief"
}

set tmpFile "bldmanhelp.tmp"

set docDir [lindex $argv 0]
set manInfoTbl [source [lindex $argv 1]]
set helpDir [lindex $argv 2]
set brief [lindex $argv 3]

puts stdout "Begin preprocessing UCB manual files"
GenInputFile $docDir $manInfoTbl $tmpFile

set argv "-b $brief $helpDir $tmpFile"
source ../tclsrc/buildhelp.tcl

unlink $tmpFile
