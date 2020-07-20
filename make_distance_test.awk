#!/bin/nawk -f
#
# This script manipulates Marlin-compatible G-code files for a 3D printer.
# See below for argument requirements.
#
# The input files must be compatible with each other and with this script.
# That means a base part consisting of exactly 7 (was 10) layers, and with an
# area encompassing the pillars, which must consist of several sections each
# consisting of exactly 25 layers, and with each pillar suitably positioned
# over the compatible base.
#
# This script assumes the code was sliced in Cura and includes comments of the
# form ";LAYER:X" at the start of every layer, counting from Layer 0.
# It's not fast, about 4 seconds per output file.
#
# Finally, this version outputs to stdout, not to a file, while informational
# messages (not part of the file) go to stderr.
# This works because stderr is normally /dev/fd/2 (real Unix, Irix, Solaris).
#
# Ver. 1.0   Pete Turnbull, 19-Oct-2019
#      1.1   Pete Turnbull, 08-Nov-2019  allow intervals of 0.25mm then 0.5mm

BEGIN {
    if (ARGC != 7) { 
    	# arguments 1-6 are required; this file's name is ARGV[0]
    	print "This script manipulates Marlin-compatible G-code files for a 3D printer."     	     
    	print "It generates a fixed-speed test tower with multiple retraction distances."    	     
    	print "It requires the following  -SIX-  command line arguments:" 		     	     
    	print "  one input file containing G-code for the base section of a print,"	     	     
	    print "    (which must contain exactly 7 layers)"				     	     
    	print "  one input file containing G-code for two labelled pillars,"		     	     
	    print "    (with enough 25-layer sections for the towers, starting at \";LAYER:7\")"	     
    	print "  the required retraction speed in mm/s,"					     	     
    	print "  the initial retraction distance,"					     	     
    	print "  the number of different retraction sections in the towers, and"	     	     
   	    print "  the retraction distance increment between tower sections."		     	     
       	exit										     	     
	}										     	     

     basefile = ARGV[1]
    towerfile = ARGV[2]
       rspeed = ARGV[3]
    startdist = ARGV[4]
        steps = ARGV[5]
     interval = ARGV[6]
         ARGC = 3   	    	# pretend the non-file arguments aren't there

   baselayers = 7   	    	# was 10 originally
   sectlayers = 25
     maxlayer = baselayers + sectlayers*steps
   # maxlayer = baselayers+1	# use these for testing
   # maxlayer = 9999	    	# use these for testing

        ftype = "DistTest_"
    	range = substr(towerfile, match(towerfile, "[0-9]+\.?[0-9]?\-[0-9]+\.?[0-9]?"), RLENGTH)
        ofile = ftype range "mm_at_" rspeed "mmps.gcode"
       stderr = "/dev/fd/2"

       Evalue = 0
        lastE = 0
    lastbaseE = 0   	    	# last value used in the base we actually print
    endmarker = "M140 S0"   	# first line of Cura's end-of-print code
         done = 0
      section = -1  	    	# not started printing the actual towers
      CFBDone = 0   	    	# correction for base extrusion has been made
         CFBE = 0   	    	# correction value for base extrusion

      CONVFMT = "%.5f"	    	# to avoid rounding in prints to file (POSIX)
         OFMT = "%.5f"	    	# to avoid rounding in prints to file (UNIX)
    	  dbg = 0   	    	# debug flag, controls printing of messages

    if (getline > 0) {
    	print "Making G-code file for a retraction distance test file like:" > stderr
	    print "  " ofile > stderr
	    print

    	# read lines until we get to one beginning ";Edited by 'fix_travels' "
    	while (getline > 0 && $0 !~ "Edited by 'fix_travels'")  print; 
	    print	    	    	# the ";Edited" line

    	# remember G-code has stupid DOS line endings (CRLF: \r\n)
	    printf ";Retraction Distance Test G-code permuted by PNT/awk script\r\n"
    	printf ";    with %d distances from %smm retraction\r\n;    in ", steps, range
    	if (interval == 0.25) { printf "0.25/0.5mm increments" }
    	else                  { printf "%1.2gmm increments", interval }
	    printf " at %dmm/s\r\n", rspeed
	    ("date" | getline) ; close "date" ; print ";    " $0
    } else
    	exit 1   	    	# we didn't even get one line
  }

################################################################################
# This prints the final bits of G-code needed to make the printer safe by
# moving the hotend/nozzle away from the print and turning off heaters.
# NOTE: this moves to X=0 Y=225mm, for an Ender 3.
################################################################################

function printendcode() {
    debug(1, "section " section ", steps " steps)
    # should do a Cura-style final retraction here, but instead 
    # increase the "Final retraction" a few lines below
    print ";end code: present the print and make the printer safe"
    print "M140 S0            ; Turn off bed heating"
    print "M141 S0            ; Turn off chamber heating"
    print "M107               ; Turn off print cooling fan"
    print "G91                ; Relative positioning"
    print "G1 E-5 F" rspeed*60 "       ; Final retraction"
    print "G1 E-2 Z0.2 F2400  ; Retract more and raise Z"
    print "G1 X5 Y5 F3000     ; Wipe out nozzle"
    print "G1 Z10             ; Raise Z more"
    print "G90                ; Absolute positioning"
    print ""
    print "G1 X0 Y225         ; Present print"
    print "M106 S0            ; Turn-off fan (set speed to 0)"
    print "M104 S0            ; Set hotend temperature to 0, no wait"
    print "M140 S0            ; Set bed temperature to 0, no wait"
    print ""
    print "M84 X Y E          ; Disable all steppers except Z"
    print ""
    print "M82                ; Absolute extrusion mode"
    print ";End of Gcode"
}

################################################################################
# This is only used for debugging.
# One day I'll fix this to allow for CR without LF, for layer printing.  Maybe.
################################################################################
function debug(flag, mssge) {
    if (flag <= dbg)    print mssge > stderr
}

################################################################################
# First, read in the file for the base part:
# this should be comments, startup code, and <baselayers> layers (of 0.2mm).
# Write it out verbatim, but stop after <baselayers> (usually 7, was 10) layers.
# (Cura will call this layer 7 (or 10) because it starts at layer 0).
# Stop if we get to layer 7, or to the endcode where Cura turns things off.
################################################################################

NR == FNR {
    if (FILENAME != ARGV[1]) exit 1
    else {
	# this is the first file, the basefile
	# are we done with the base file?
	if (done > 0) next
	if ($0 ~ ";LAYER:"baselayers || $0 ~ endmarker) { done = 1 ; next }
	# if the last thing on the line is an extrusion value, test/save it
	if ($NF ~ /^E[-]?[0123456789\.]+/) {
	    # extract the value of Exxxxx forcing it to be accurate and numeric
	    Evalue = substr($NF,2)+0
	    # and if it's a retraction, correct it:
	    # Note retracts/reprimes should always be a line of the form
	    #   "G1 F<4-digit mm/min> E<decimal>"
	    if ($0 ~ /^G1 F[0123456789]+ E[-]?[0123456789\.]+/) {
	    	debug(2, "Extrude-only line, E = " Evalue " (" $NF ")")
		if (Evalue < lastE) {
		    Evalue = lastE - startdist
		    $3 = "E" Evalue "\r"
	    	} else {
		}
		$2 = "F" rspeed*60
	    }
	    lastE = Evalue
	}
    	print
	next	# don't go further down into the pillars section code
    }
}

################################################################################
# Next, read through the file for the pillars sections,
# skipping over anything that is part of it's base.  But do record the last E 
# value in the base we *don't* print so we can calculate the difference between
# the one we *did* print and the one before our towers.
# Read section by section, tracking layer (and hence section) numbers
# and write out lines verbatim, remembering any extrusion value, except that:
# - use CFBE to correct E values for difference between bases
# - if they contain a retraction: change the speed and distance
# - if they are the first extruding line after a retraction: change the speed
# Different bases will have used different amounts of filament so it's necessary
# to correct for that with CFBE.
################################################################################

# The first time we get here, lastE is the final extrusion in the base we used
lastbaseE == 0	{ 
    lastbaseE = lastE
    done = 0
    debug(1, "\nlastbase is " lastbaseE)
    debug(1, "  startdist is " startdist)
    debug(1, "")
    }

/^;SETTING_3 /	    	    	    { print }

(done == 1) , / "End of Gcode" /    { next }

$0 ~ "^;LAYER:"baselayers"\r$" , ($0 ~ "^;LAYER:"maxlayer || done == 1) {
    if ($0 ~ endmarker) { 
    	if (section == steps ) {
	    done = 1
	    printendcode()
	    next
    	} else { print "Oopsie!  Ran out of code a bit early" > stderr ; exit 2 }
    }
    # for each new layer, check which section we're in
    if ($0 ~ "^;LAYER:") {
    	current = substr($1, 8)+0
    	section = int((current-baselayers)/25)+1 # LAYER:7 starts section 1
    	debug(1, $0)
	if (section > steps) {
    	    # we're done, but apparently not run out of G-code, so:
    	    done = 1
	    printendcode()
	    next
    	}
    }
    # correct lines with extrusions (but we can ignore endcode; it's different)
    if ($NF ~ /^E[-]?[0123456789\.]+/) {
	Evalue = substr($NF, 2)+0 
	if (CFBDone == 0) { 	    	# this must be the 1st tower extrusion
	    CFBE = lastbaseE-lastE  	# this makes an additive correction
	    lastE += CFBE   	    	# correct this too, but only once
	    CFBDone = 1	    	    	# correction is in place
	    debug(3, "CFBE = " CFBE ", lastE is now " lastE)
	}
	Evalue += CFBE
	# if this extrusion is a retraction, correct it: 
    	if ($0 ~ /^G1 F[0123456789]+ E[-]?[0123456789\.]+/) {
	    debug(2, "Extrude-only line, E = " Evalue " (" $NF ")")
    	    if (Evalue < lastE) {
	    	debug(3, "  Retraction: lastE was " lastE ", Evalue " Evalue)
		rdist = (section-1)*interval
		# but only use 0.25mm intervals between 0.0mm and 1.0mm
		if (section > 5 && interval == 0.25) {
		    # 5 sections at 0.25mm increment, then 2 at 0.5mm
		    rdist = (section + section-6) * interval
		}
		debug(3, "  section = " section ", interval = " interval ", Evalue now " lastE - startdist - rdist)
    		Evalue = lastE - startdist - rdist
		$3 = "E" Evalue "\r"
    	    } else {
	    	debug(3, "  re-prime: " Evalue)
	    }
    	    $2 = "F" rspeed*60
    	}
    	lastE = Evalue
    }
    print							      
}
