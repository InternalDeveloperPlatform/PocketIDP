#!/usr/bin/env bash
set -exo pipefail

./0_install.sh
./1_demo.sh
./2_cleanup.sh
