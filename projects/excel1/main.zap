# Microsoft Excel 1.00 run on the Mac written in Zap, in a window (the mouse and keys are the Mac's),
# its 68000 code interpreted: `zap run projects/excel1/main.zap` from the repository root. The reference the
# recompiled program (projects/excel1/recomp/excel.zap, written by projects/excel1/recomp.zap) is checked against,
# the two ending in the same machine state (--state). Run from the repository root after
# projects/excel1/prepare.zap; projects/excel1/driver/driver.zap lists the options. Excel's About box, from the
# Apple menu, against the screenshot kept with the disks:
#
#   zap run projects/excel1/main.zap --idle 90 --input "down 10 20; move 30 30; up 30 30"
#       --expect "projects/excel1/disks/extras/Microsoft Excel v1.00_0 about box.png"

import driver

driver.runExcel([])
