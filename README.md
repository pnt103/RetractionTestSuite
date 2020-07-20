# RetractionTestSuite
Script(s) used to create a comprehensive suite of fast retraction distance/speed tests for 3D printing

The files here are used to build a comprehensive set of 42 test files to
determine best retraction distance and retraction speed for an FDM
printer/filament combination.

I designed source files in Fusion 360, exported them as STLs, and sliced them
in Cura 4.3.0, creating two sets of source files: 7 distance test g-code files 
and 14 speed test g-code files.

A couple of awk(1) scripts manipulate the g-code files.  The first 
takes any of the seven basic distance-testing files and edits each section to 
provide the correct sequence of retraction distances, with the nominated 
retraction speed throughout, creating a total of 28 test files: 4 distance 
ranges, and seven speeds for each.  The second takes any of the set of 14 
sources for the fixed distances and edits each section to have the designated 
retraction speed.

Each output file consists of a base to ensure bed adhesion, and two slim pillars
20mm apart.  The pillars are vertically divided into labelled 5mm sections to make
it clear where parameters change. They are angular, partly to print faster, but
mainly to ensure the travel moves start and end in the same places.  

Each takes about 20 minutes to print, not including time for preheating, 
homing, or auto-bed-levelling, and uses just over 0.5m of filament.  You'd
normally start by choosing a likely retraction distance range and plausible
retraction speed, and run one distance test.  That may be sufficient, but you
might perhaps refine that, and then perhaps run a retraction speed test.  You
should have previously calibrated your printers E steps, and ideally have run a
temperature test for the filament you're testing.

For each of the files to test retraction distances, one pillar is labelled with
the retraction distances used for each section, and the base is labelled with
the retraction speed used, which is the same for the whole file.

For each of the files to test retraction speeds, one of the pillars is labelled
with the retraction speed used for each section, and the base is labelled with
the retraction distance used, which is the same for the whole file.  

For Bowden tube extruders, there are distance files with distances from 0mm to
10mm retraction in 2mm steps, and for finer resolution, files with distances
from 3mm to 8mm in 1mm steps.  

For direct extruders, or simply for finer resolution, there are
distance files with distances from 0mm to 2.0mm retraction in 0.25/0.5mm steps,
and 2.0mm to 5.0mm in 0.5mm steps.  

Each of those types is present with seven retraction speeds: 15mm/s, 20mm/s,
25mm/s, 30mm/s, 35mm/s, 40mm/s, and 50mm/s.

There are 14 speed-test files with retraction speeds from 15mm/s to 50mm/s,
each file at a constant retraction distance: 0.25mm, 0.5mm, 0.75mm, 1.0mm,
1.5mm, 2.0mm, 2.5mm, 3.0mm, 4mm, 5mm, 6mm, 7mm, 8mm, and 10mm.
