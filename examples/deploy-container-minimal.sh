#!/usr/bin/env bash

exec "${BASH_SOURCE[0]%/*}/deploy-container.sh" --minimal-config "$@"
