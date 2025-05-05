#!/bin/bash

/usr/bin/curl -d "Inicio de sesion local de : [$PAM_USER] desde la $PAM_TTY a las [$(date)]" -X POST "http://<ntfy_server>/<ntfy-topic>"

exit 0
