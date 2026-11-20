#!/bin/bash
# Run SQL on the OLD server, hopping via the new server's migration key.
B64=$(cat "$1" | base64)
./new_ssh.exp "echo $B64 | base64 -d > /tmp/q.sql; K=/home/sklive/.ssh/migrate_old; sudo scp -i \$K -o StrictHostKeyChecking=accept-new /tmp/q.sql ubuntu@51.222.81.97:/tmp/q.sql >/dev/null; sudo ssh -i \$K -o StrictHostKeyChecking=accept-new ubuntu@51.222.81.97 'sudo docker cp /tmp/q.sql supabase-db-mnq3vesx0syflb0m0bot3oa2:/tmp/q.sql >/dev/null && sudo docker exec supabase-db-mnq3vesx0syflb0m0bot3oa2 psql -U postgres -d postgres -f /tmp/q.sql'"
