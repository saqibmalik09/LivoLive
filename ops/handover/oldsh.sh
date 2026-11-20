#!/bin/bash
# Run a shell script on the OLD server, hopping via the new server's migration key.
# Base64 avoids three layers of quote mangling (expect -> ssh -> ssh).
B64=$(base64 < "$1" | tr -d '\n')
./new_ssh.exp "echo $B64 | base64 -d > /tmp/r.sh; K=/home/sklive/.ssh/migrate_old; sudo scp -i \$K -o StrictHostKeyChecking=accept-new /tmp/r.sh ubuntu@51.222.81.97:/tmp/r.sh >/dev/null; sudo ssh -i \$K -o StrictHostKeyChecking=accept-new ubuntu@51.222.81.97 'sudo bash /tmp/r.sh'"
