# Introduction

A docker-helper bash script.

d6 = the letter d from docker with 6 characters total in the word docker.

# How to install

Put d6.sh in `~/.local/bin` (and add that to your path if you haven't already done so).

In any project that you use docker, add a file `.d6.sh` into the main directory, or wherever you have your docker-compose.yml file. The location of the .d6.sh file isn't overly important. Put it wherever you plan to run d6.sh. 

## .d6.sh contents

List the names of each container. (Use `container_name` in docker-compose.yml to name your containers.)

Here is an example of a simple, one-container endpoint I created recently.

There are some default variables at the bottom. Uncomment the ones you wish to use.

```bash
#!/bin/bash

# Can get list from: docker ps --format {{.Names}}
# You don't have to specify the whole name, but sometimes this leads to duplicate
# finds when filtering.
#
# Must use container_name in docker-compose.yaml
NAMES=(
	"rest_mock_endpoint" 	# 0
)

# Defaults
#SHELL=/bin/bash # Sometimes only /bin/sh is available
#LOGS_FILE="/tmp/logs.txt"
DEBUG=false # true or false
```

# How to use

usage() isn't overly informative. For now, just look at the case/esac blocks for actions that aren't mentioned below.

## list

Gives you a list of all images, containers and the internal name-mapping used by d6.sh.

```
$ d6.sh list

-- IMAGES --------
REPOSITORY           TAG       IMAGE ID       CREATED       SIZE
rest_mock_endpoint   latest    6ccd453a3999   13 days ago   1.12GB
-- CONTAINERS -----
CONTAINER ID   IMAGE                       COMMAND                  CREATED          STATUS          PORTS                    NAMES
74888d7ca0e5   rest_mock_endpoint:latest   "python manage.py ru…"   18 minutes ago   Up 18 minutes   0.0.0.0:8000->8000/tcp   rest_mock_endpoint
-- NAMES ----------
	0 -> 74888d7ca0e5 -> rest_mock_endpoint
```

## tty

Lets you shell-in to a running container by typing a single digit.

The example below is for a single container site; but the real power of this occurs when you have multiple containers running simultanously.

```
$ d6.sh tty
	0 -> 74888d7ca0e5 -> rest_mock_endpoint
Choose an integer value:
0
Shelling into [rest_mock_endpoint].
/usr/local/bin/docker exec -it 74888d7ca0e5 /bin/bash
root@rest_mock_endpoint:/app#
```

# rm, rmi

The nice thing about rm or rmi is that it automatically stops the container if running first. With rmi, it knows to remove the container first. This greatly simplifies tearing down docker containers and/or images when you are figuring out a docker-compose.yml implementation.

# build

Assuming you have a build.sh script in the same directory, d6.sh will stop, rm, and rmi all the things, then run the build.sh script. What's that look like?

```bash
#!/bin/bash
set -xe

COMPOSE_FILE="./docker-compose.yaml"
COMPOSE_FILE_DEV="./docker-compose.dev.yaml"
PROJECT_NAME=rest_mock_endpoint

set +xe
	docker ps -q
	if [[ $? != 0 ]]; then
		echo "Is Docker Desktop running?"
		exit 1
	fi
set -xe

# Local dev
export SERVER_TYPE=dev

docker-compose -p $PROJECT_NAME -f $COMPOSE_FILE -f $COMPOSE_FILE_DEV build
docker-compose -p $PROJECT_NAME -f $COMPOSE_FILE -f $COMPOSE_FILE_DEV up --detach
```