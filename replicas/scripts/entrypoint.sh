#!/bin/sh

# Broker Options: important!
# The local-uri setting places the unix domain socket in rundir 
#   if FLUX_URI is not set, tools know where to connect.
#   -Slog-stderr-level= can be set to 7 for larger debug level
#   or exposed as a variable
brokerOptions="-Scron.directory=/etc/flux/system/cron.d \
  -Stbon.fanout=256 \
  -Srundir=/run/flux \
  -Sstatedir=${STATE_DIRECTORY:-/var/lib/flux} \
  -Slocal-uri=local:///run/flux/local \
  -Slog-stderr-level=6 \
  -Slog-stderr-mode=local"

# quorum settings influence how the instance treats missing ranks
#   by default all ranks must be online before work is run, but
#   we want it to be OK to run when a few are down
# These are currently removed because we want the main rank to
# wait for all the others, and then they clean up nicely
#  -Sbroker.quorum=0 \
#  -Sbroker.quorum-timeout=none \

# This should be added to keep running as a service
#  -Sbroker.rc2_none \

# Get the container's IP address
CONTAINER_IP=$(hostname -i | awk '{print $1}')

# Perform reverse DNS and explicitly extract the string after "name ="
FULL_HOSTNAME=$(nslookup $CONTAINER_IP | awk '/name =/ {print $4}')

# Strip the trailing network domain to get just the node name (e.g., replicas-node-1)
thisHost=$(echo $FULL_HOSTNAME | cut -d'.' -f1)

echo $thisHost

# Export this hostname to coincide with the name provided by Docker
export FLUX_FAKE_HOSTNAME=$thisHost

# Physically change the container's kernel hostname
sudo hostname "$thisHost"

# Update the static hostname file
printf '%s\n' "$thisHost" | sudo tee /etc/hostname > /dev/null

cd ${workdir}
printf "\n👋 Hello, I'm ${thisHost}\n"
printf "The main host is ${mainHost}\n\n"
printf "🔍️ Here is what I found in the working directory, ${workdir}\n"
ls ${workdir}

# --cores=IDS Assign cores with IDS to each rank in R, so we  assign 1-N to 0
printf "\n📦 Resources\n"
sudo cat /etc/flux/system/R

printf "\n🦊 Independent Minister of Privilege\n"
cat /etc/flux/imp/conf.d/imp.toml

# The curve cert is generated on container build
# We assume the munge.key is the same also since we use the same base container!
# located at /etc/munge/munge.key

# Give broker time to start before workers
if [ ${thisHost} != "${mainHost}" ]; then
    printf "\n😪 Sleeping to give broker time to start...\n"
    sleep 15
    FLUX_FAKE_HOSTNAME=$thisHost flux start -o --config /etc/flux/config ${brokerOptions} sleep inf
else
    echo "Extra arguments are: $@"
    printf "flux start -o --config /etc/flux/config ${brokerOptions} sleep inf\n"
    FLUX_FAKE_HOSTNAME=$thisHost flux start -o --config /etc/flux/config ${brokerOptions} sleep inf
fi
