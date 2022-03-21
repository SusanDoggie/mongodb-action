#!/bin/sh
set -e

MONGO_VERSION=$1
MONGO_REPLICA_SET=$2
MONGO_PORT=$3
MONGO_DATABASE=$4
MONGO_USERNAME=$5
MONGO_PASSWORD=$6

echo "  - port [$MONGO_PORT]"
echo "  - version [$MONGO_VERSION]"
echo "  - database [$MONGO_DATABASE]"
echo "  - replSet [$MONGO_REPLICA_SET]"

if [ -z "$MONGODB_REPLICA_SET" ]; then

  echo ::group::Starting MongoDB service

  docker run -d --name mongodb \
    -p ${MONGO_PORT}:27017 \
    -e MONGO_INITDB_DATABASE=${MONGO_DATABASE} \
    -e MONGO_INITDB_ROOT_USERNAME=${MONGO_USERNAME} \
    -e MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD} \
    mongo:${MONGO_VERSION}

  echo ::endgroup::

  return
fi

echo ::group::Starting MongoDB service

docker run -d --name mongodb \
  -p ${MONGO_PORT}:27017 \
  mongo:${MONGO_VERSION} --replSet ${MONGO_REPLICA_SET}

docker inspect --format="{{if .Config.Healthcheck}}{{print .State.Health.Status}}{{end}}" mongodb

until docker exec --tty mongodb mongo 'admin' --eval 'quit(0)'; do sleep 1; done

docker exec --tty mongodb mongo --eval "
  rs.initiate({
    _id: '${MONGO_REPLICA_SET}',
    members: [{
       _id: 0,
      host: 'localhost'
    }]
  })
"

docker exec --tty mongodb mongo admin --eval "
  db.createUser({
    user: '${MONGO_USERNAME}',
    pwd: '${MONGO_PASSWORD}',
    roles:[{
      role: 'root',
      db: 'admin'
    }]
  })
"

echo ::endgroup::
