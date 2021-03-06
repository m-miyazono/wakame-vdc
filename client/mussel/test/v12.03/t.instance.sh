#!/bin/bash

. ../../functions
. ./helper_shunit2


setUp() {
  xquery=
  state=
}

test_instance_help_stderr_to_devnull_success() {
  extract_args instance help
  res=$(run_cmd  ${MUSSEL_ARGS} 2>/dev/null)
  assertEquals "${res}" ""
}

test_instance_help_stderr_to_stdout_success() {
  extract_args instance help
  res=$(run_cmd  ${MUSSEL_ARGS} 2>&1)
  assertEquals "${res}" "$0 instance [help|index|show|create|destroy|reboot|stop|start]"
}

test_instance_state() {
  extract_args instance index --state=running
  assertEquals "${state}" "running"
}

test_instance_create() {
  extract_args instance create
  run_cmd ${MUSSEL_ARGS}
}

. ../shunit2
