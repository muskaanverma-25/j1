#!/bin/bash

if [[ $(curl localhost:3000/sessions/show --fail --connect-timeout 3 --retry 0 -s -o /dev/null -w %{http_code}) == 401 ]]; then true; else false; fi;