#!/bin/bash

# Define the paths to format.
PATHS_TO_FORMAT="lib test packages/tsukuyomi_list"

# Run dart format and capture the output.
dart format --set-exit-if-changed $PATHS_TO_FORMAT
exit_code=$?

# If the exit code is non-zero, it means files were changed.
if [ $exit_code -ne 0 ]; then
  echo -e "\n----------------------------------------------------------------"
  echo -e "ERROR: Code formatting issues found and were auto-fixed."
  echo -e "Please stage the changes (e.g., git add .) and re-commit."
  echo -e "To run the formatter manually, use: dart format $PATHS_TO_FORMAT"
  echo -e "----------------------------------------------------------------"
  exit $exit_code
fi

exit 0
