#!/bin/sh
set -e

DOCKER_NETWORK=$1
MONGO_VERSION=$2
MONGO_HOST=$3
MONGO_PORT=$4
MONGO_USERNAME=$5
MONGO_PASSWORD=$6
MONGO_DATABASE=$7
MONGO_REPLICA_SET=$8

echo "  - network [${DOCKER_NETWORK}]"
echo "  - host [${MONGO_HOST}]"
echo "  - port [${MONGO_PORT}]"
echo "  - version [${MONGO_VERSION}]"
echo "  - database [${MONGO_DATABASE}]"
echo "  - replSet [${MONGO_REPLICA_SET}]"

if [ -z "${MONGO_REPLICA_SET}" ]; then

  echo ::group::Starting MongoDB service

  echo "starting mongodb..."

  docker run -d --name mongodb \
    --network ${DOCKER_NETWORK} \
    --hostname ${MONGO_HOST} \
    -p ${MONGO_PORT}:27017 \
    -e MONGO_INITDB_DATABASE=${MONGO_DATABASE} \
    -e MONGO_INITDB_ROOT_USERNAME=${MONGO_USERNAME} \
    -e MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD} \
    mongo:${MONGO_VERSION}

  echo ::endgroup::

  return
fi

echo ::group::Starting MongoDB service

echo "starting single node mongodb..."

docker run -d --name mongodb \
  --network ${DOCKER_NETWORK} \
  --hostname ${MONGO_HOST} \
  -p ${MONGO_PORT}:27017 \
  mongo:${MONGO_VERSION} --replSet ${MONGO_REPLICA_SET}
  
echo "waiting mongodb start..."

docker inspect --format="{{if .Config.Healthcheck}}{{print .State.Health.Status}}{{end}}" mongodb

sleep 1
TIMER=0

until docker exec --tty mongodb mongosh 'admin' --eval 'quit(0)'; do
  sleep 1
  echo "."
  TIMER=$((TIMER + 1))

  if [[ $TIMER -eq 20 ]]; then
    echo "MongoDB did not initialize within 20 seconds. Exiting."
    exit 2
  fi
done

echo "mongodb started."

docker exec --tty mongodb mongosh --eval "
  rs.initiate({
    _id: '${MONGO_REPLICA_SET}',
    members: [{
      _id: 0,
      host: '${MONGO_HOST}:${MONGO_PORT}'
    }]
  })
"

sleep 1

docker exec --tty mongodb mongosh admin --eval "
  db.createUser({
    user: '${MONGO_USERNAME}',
    pwd: '${MONGO_PASSWORD}',
    roles:[{
      role: 'root',
      db: 'admin'
    }]
  })
"

docker exec --tty mongodb mongosh --eval "
  rs.status()
"
echo ::endgroup::
