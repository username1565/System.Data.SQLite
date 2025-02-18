###############################################################################
#
# updateFileInfo.tcl -- File Metadata Updating Tool
#
# WARNING: This tool requires the Fossil binary to exist somewhere along the
#          PATH.
#
# Written by Joe Mistachkin.
# Released to the public domain, use at your own risk!
#
###############################################################################

proc readFile { fileName } {
  set file_id [open $fileName RDONLY]
  fconfigure $file_id -encoding binary -translation binary
  set result [read $file_id]
  close $file_id
  return $result
}

proc writeFile { fileName data } {
  set file_id [open $fileName {WRONLY CREAT TRUNC}]
  fconfigure $file_id -encoding binary -translation binary
  puts -nonewline $file_id $data
  close $file_id
  return ""
}

proc getFileSize { fileName } {
  #
  # NOTE: Return the number of mebibytes in the file with two digits after the
  #       decimal.
  #
  return [format %.2f [expr {[file size $fileName] / 1048576.0}]]
}

proc getFileHash { fileName } {
  #
  # NOTE: Return the SHA1 hash of the file, making use of Fossil via [exec] to
  #       actually calculate it.
  #
  return [string trim [lindex [regexp -inline -nocase -- {[0-9A-F]{40} } \
      [exec fossil sha1sum $fileName]] 0]]
}

#
# NOTE: Grab the fully qualified directory name of the directory containing
#       this script file.
#
set path [file normalize [file dirname [info script]]]

#
# NOTE: *WARNING* This assumes that the root of the source check-out is one
#       directory above the directory containing this script.
#
set root [file normalize [file dirname $path]]

#
# NOTE: Grab the name of the file to be updated from the command line, if
#       available; otherwise, use the defaults (i.e. "../www/downloads*.wiki").
#
if {[info exists argv] && [llength $argv] > 0} then {
  set updateFileNames [lindex $argv 0]
}

if {![info exists updateFileNames] || \
    [llength $updateFileNames] == 0} then {
  set updateFileNames [list \
      [file join $root www downloads.wiki] \
      [file join $root www downloads-unsup.wiki]]
}

#
# NOTE: Grab the directory containing the files referenced in the data of the
#       file to be updated from the command line, if available; otherwise, use
#       the default (i.e. "./Output").
#
if {[info exists argv] && [llength $argv] > 1} then {
  set outputDirectory [lindex $argv 1]
}

if {![info exists outputDirectory] || \
    [string length $outputDirectory] == 0} then {
  set outputDirectory [file join $path Output]
}

#
# NOTE: Setup the regular expression patterns with the necessary captures.
#       These patterns are mostly non-greedy; however, at the end we need to
#       match exactly 40 hexadecimal characters.  In theory, in Tcl, this can
#       have an undefined result due to the mixing of greedy and non-greedy
#       quantifiers; however, in practice, this seems to work properly.  Also,
#       these patterns assume a particular structure for the [HTML] file to be
#       updated.
#
set pattern1 {<a\
    href="[^"]*?/([^"]*?\.(?:exe|zip|nupkg))">.*?\((\d+?\.\d+?) MiB\).*?sha1:\
    ([0-9A-F]{40})}

set pattern2 {<a\
    href="[^"]*?/package/[^"]*?/\d+\.\d+\.\d+\.\d+">(.*?)</a>.*?\((\d+?\.\d+?)\
    MiB\).*?sha1: ([0-9A-F]{40})}

set pattern3 {href="/downloads/([^"]*?)"}
set pattern4 {\(sha1: ([0-9A-F]{40})\)}
set pattern5 {\((\d+?\.\d+?) MiB\)}

foreach updateFileName $updateFileNames {
  #
  # NOTE: Grab all the data from the file to be updated.
  #
  set data [readFile $updateFileName]

  #
  # NOTE: Initialize the total number of changes made to zero.
  #
  set count 0

  #
  # NOTE: Process each regular expression pattern against the page text.
  #
  foreach pattern [list $pattern1 $pattern2] {
    #
    # NOTE: Process each match in the data and capture the file name, size,
    #       and hash.
    #
    foreach {dummy fileName fileSize fileHash} \
        [regexp -all -inline -nocase -- $pattern $data] {
      #
      # NOTE: Get the fully qualified file name based on the configured
      #       directory.
      #
      set fullFileName [file join $outputDirectory [file tail $fileName]]

      #
      # NOTE: If the file does not exist, issue a warning and skip it.
      #
      if {![file exists $fullFileName]} then {
        puts stdout "WARNING: File \"$fullFileName\" does not exist, skipped."
        continue
      }

      #
      # NOTE: Replace the captured size and hash with ones calculated from the
      #       actual file name.  This will only replace the first instance of
      #       each (literal) match.  Since we are processing the matches in the
      #       exact order they appear in the data AND we are only replacing one
      #       literal instance per match AND the size sub-pattern is nothing
      #       like the hash sub-pattern, this should be 100% reliable.  In
      #       order to avoid superfluous matches of the file size or hash, the
      #       starting index is set to a position just beyond the matching file
      #       name.
      #
      set start [string first $fileName $data]

      if {$start == -1} then {
        puts stdout "WARNING: Position for \"$fileName\" not found, skipped."
        continue
      }

      incr start [string length $fileName]

      #
      # NOTE: Calculate the new file size and compare it to the old one.  If it
      #       has not changed, do nothing.
      #
      set newFileSize [getFileSize $fullFileName]

      if {$fileSize ne $newFileSize} then {
        incr count [regsub -nocase -start $start -- "***=$fileSize" $data \
            $newFileSize data]

        incr start [string length $fileSize]
      }

      #
      # NOTE: Calculate the new file hash and compare it to the old one.  If it
      #       has not changed, do nothing.
      #
      set newFileHash [getFileHash $fullFileName]

      if {$fileHash ne $newFileHash} then {
        incr count [regsub -nocase -start $start -- "***=$fileHash" $data \
            $newFileHash data]

        incr start [string length $fileHash]
      }
    }
  }

  #
  # NOTE: Attempt to verify that each file name now has the correct SHA1 hash
  #       associated with it on the page.
  #
  foreach {dummy3 fileName} [regexp -all -inline -nocase -- $pattern3 $data] \
          {dummy4 fileHash} [regexp -all -inline -nocase -- $pattern4 $data] \
          {dummy5 fileSize} [regexp -all -inline -nocase -- $pattern5 $data] {
    #
    # NOTE: Get the fully qualified file name based on the configured
    #       directory.
    #
    set fullFileName [file join $outputDirectory [file tail $fileName]]

    #
    # NOTE: If the file does not exist, issue a warning and skip it.
    #
    if {![file exists $fullFileName]} then {
      puts stdout "WARNING: File \"$fullFileName\" does not exist, skipped."
      continue
    }

    #
    # NOTE: Make sure the file hash from the [modified] data matches the
    #       calculated hash for the file.  If not, fail.
    #
    set fullFileHash [getFileHash $fullFileName]

    if {$fileHash ne $fullFileHash} then {
      puts stdout "ERROR: SHA1 hash mismatch for\
          file \"$fullFileName\", have \"$fileHash\" (from data),\
          need \"$fullFileHash\" (calculated)."
    }

    set fullFileSize [getFileSize $fullFileName]

    if {$fileSize ne $fullFileSize} then {
      puts stdout "ERROR: Byte size mismatch for\
          file \"$fullFileName\", have \"$fileSize\" (from data),\
          need \"$fullFileSize\" (calculated)."
    }
  }

  #
  # NOTE: Write the [modified] data to the file to be updated.
  #
  if {$count > 0} then {
    writeFile $updateFileName $data
  } else {
    puts stdout "WARNING: No changes, update of \"$updateFileName\" skipped."
  }
}
