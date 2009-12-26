#!/bin/sh
#
#  $Id$
#
#  If $PC_SET_VALIDATED is set, then update validated.dat
#  Otherwise, don't do anything.
#  This script is used by auto-test and pc_auto-test.
#
if [ $PC_SET_VALIDATED ]; then
  cd $PENCIL_HOME/misc/validation;
  svn up;
  echo "`date` (previously validated revision: `cat validated.dat`)" \
    >> `uname -n`.autotest;
  svn ci -m "AUTOMATIC update by auto-test on `uname -n` by $USER";
fi
