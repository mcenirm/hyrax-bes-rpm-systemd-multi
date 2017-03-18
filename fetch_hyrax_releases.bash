#!/bin/bash

set -e
set -u

. "$( dirname "$0" )/settings.conf"

mkdir -p -- "$HYRAX_RELEASES_DIR"

for url_path in "$HYRAX_RPMS_PREFIX/" "$HYRAX_WEBAPP_PREFIX/$HYRAX_WEBAPP_DIST" ; do
  url=${HYRAX_BASE_URL}${url_path}
  wget \
      --no-verbose \
      --mirror \
      -nH -np \
      --cut-dirs=1 \
      --reject-regex '\?C=.;O=.$' \
      -P "$HYRAX_RELEASES_DIR" \
      "$url"
done
