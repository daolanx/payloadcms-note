#!/bin/bash
# Common functions for docker scripts

# Parse -t/--tag argument, echoes the tag value (or empty if not provided)
parse_tag() {
  local options tag=""
  options=$(getopt -o t: --long tag: -- "$@")
  eval set -- "$options"

  while true; do
    case $1 in
      -t | --tag) shift; tag=$1; shift ;;
      --) shift; break ;;
      *) echo "Invalid option: $1" >&2; exit 1 ;;
    esac
  done

  echo "$tag"
}

# Load .env.local if exists
load_env() {
  if [ -f .env.local ]; then
    set -a
    . .env.local
    set +a
  fi
}
