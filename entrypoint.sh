#!/bin/bash

# Switch to non-root user
exec su-exec libpostaluser "$@"