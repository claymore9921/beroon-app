#!/bin/sh
set -e

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  ./bin/beroon eval "Beroon.Release.migrate()"
fi

exec "$@"
