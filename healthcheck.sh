#!/bin/bash

set -uexo pipefail

nc -z 127.0.0.1 80    # Web
#nc -z 127.0.0.1 9200  # Elastic

