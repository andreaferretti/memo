version       = "0.4.0"
author        = "wiffel"
description   = "Memoize Nim functions"
license       = "Apache2"
skipFiles     = @["test", "test.nim"]

requires "nim >= 0.17.3"

task test, "run memo tests":
  --hints: off
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "."
  --run
  --define:memoDebug
  setCommand "c", "test.nim"

task tests, "run memo tests":
  setCommand "test"