#!/bin/bash

# Get the NAMES from the local project file
if [[ ! -f "./.d6.sh" ]]; then
	echo "No local .d6.sh file found"
	exit 1
fi
source ./.d6.sh

# Running variables
ACTION=$1
CHOSEN_NO=$2
DOCKER=/usr/bin/docker
if [[ ! -f $DOCKER ]]; then
	# Mac's do things a little different
    DOCKER=/usr/local/bin/docker
fi

# Defaults
if [[ "$SHELL" == "" ]]; then
	SHELL=/bin/bash # Sometimes only /bin/sh is available
fi
if [[ "$LOGS_FILE" == "" ]]; then
	LOGS_FILE="/tmp/logs.txt"
fi
if [[ "$DEBUG" == "" ]]; then
	DEBUG=false # true or false
fi

usage() {
	echo
	echo "Usage:"
	echo "	  d6.sh <action> [name no]"
	echo
	echo "[name no] is 0, 1, 2, etc. based upon the image names for this project listed in the script."
}

build() {
	source build.sh
}

# For use in creating a list for the user to choose
choose_name() {
	list_names
	echo "Choose an integer value: "
	read chosen
	if $DEBUG; then
		echo "You chose [$chosen]"
	fi

	# Set $1 $2 $3 $4 . . .
	# (Actually, I don't think this works inside a function)
	# set -- "$1" "$chosen"

	CHOSEN_NO=$chosen
}

# Gets a container id based upon passed integer value.
# Considers running containers only
get_running_container_id() {
	FILTER="name=$1"
	# ID="$DOCKER ps --no-trunc -qf '$FILTER' -f 'status=running'"
	ID="$DOCKER ps -qf '$FILTER' -f 'status=running'"
	#echo "For FILTER [$FILTER]: $ID"
	ID=$(eval "$ID")
	if [[ "$ID" != "" ]]; then
		echo "$ID"
	else
		false
	fi
}

# Regardless of running or not
get_container_id() {
	FILTER="name=$1"
	# ID="$DOCKER ps --no-trunc -qf '$FILTER' -a"
	ID="$DOCKER ps -qf '$FILTER' -a"
	ID=$(eval "$ID")
	if [[ "$ID" != "" ]]; then
		echo "$ID"
	else
		false
	fi
}

prune() {
	# Light cleanup of dangling cruft
	$DOCKER system prune -f
	$DOCKER system prune -f --volumes
}

running_container_action() {
	if $DEBUG; then
		echo "running_container_action ACTION [$ACTION] CHOSEN_NO [$CHOSEN_NO] fn(\$1) [$1] fn(\$2) [$2]"
	fi

	case "$ACTION" in
	tty | shell)
		# Can only tty to a specified name number.
		if [[ "$CHOSEN_NO" == "" ]]; then
			echo "You must specify which container number"
			exit 1
		fi

		if [[ "$CHOSEN_NO" == "$2" ]]; then
			echo "Shelling into [${NAMES[$2]}]."
			#USER="--user=root"
			USER=""
			CMD="$DOCKER exec -it $USER $1 $SHELL"
			echo $CMD
			eval $CMD
			exit 0
		fi
		;;
	pause | unpause)
		if [[ "$CHOSEN_NO" == "" ]]; then
			echo "You must specify which container number"
			exit 1
		fi

		if [[ "$CHOSEN_NO" == "$2" ]]; then
			echo "About to $ACTION container [${NAMES[$2]}]."
			CMD="$DOCKER $ACTION $1"
			echo $CMD
			eval $CMD
			exit 0
		fi
		;;
	stop | stopall | rmi | destroy | rebuild)
		# Anything running in this group of actions must be stopped first.
		if [[ "$CHOSEN_NO" == "" || "$CHOSEN_NO" == "$2" ]]; then
			CMD="$DOCKER stop $1"
			echo $CMD
			eval $CMD
		fi
		;;
	stats)
		# Like the linux top command
		if [[ "$CHOSEN_NO" == "$2" ]]; then
			CMD="$DOCKER stats $1"
			echo $CMD
			eval $CMD
		fi
		;;
	inspect)
		# Can only inspect a specified name number.
		if [[ "$CHOSEN_NO" == "" ]]; then
			echo "You must specify which container number"
			exit 1
		fi

		if [[ "$CHOSEN_NO" == "$2" ]]; then
			CMD="$DOCKER inspect $1"
			echo $CMD
			eval $CMD
		fi
		;;
	logs)
		# Can only get logs if they specified a single container.
		if [[ "$CHOSEN_NO" == "" ]]; then
			echo "You must specify which container number"
			exit 1
		fi

		if [[ "$CHOSEN_NO" == "$2" ]]; then
			# CMD="$DOCKER logs $1 2>&1 | tee $LOGS_FILE"
			CMD="$DOCKER logs $1 > $LOGS_FILE 2>&1"
			#echo $CMD
			eval $CMD
			echo ""
			echo "Logs for [${NAMES[$2]}] sent to [$LOGS_FILE]"
			echo "To follow: docker logs -f --tail 100 $1"
			echo "To edit:   vim $LOGS_FILE"
			exit 0
		fi
		;;
	build)
		# If even one of the names has a running container, get out quick
		echo
		echo "Already running: [$1]"
		echo "	  for name: [${NAMES[$2]}]."
		echo
		echo "Stop all containers before doing a build."
		echo
		exit 1
		;;
	*)
		echo "Unknown running container action [$ACTION]"
		#exit 1
		;;
	esac
}

existing_container_action() {
	if $DEBUG; then
		echo "existing_container_action ACTION [$ACTION] \$1 [$1] \$2 [$2]"
	fi

	# Assume anything getting to this point has been stopped
	case "$ACTION" in
	start)
		if [[ "$CHOSEN_NO" == "$2" ]]; then
			echo "Starting $1 . . ."
			eval "$DOCKER start $1"
		fi
		;;
	rmall)
		eval "$DOCKER rm $1"
		;;
	rm)
		if [[ "$CHOSEN_NO" == "$2" ]]; then
			eval "$DOCKER rm $1"
		fi
		;;

	rmi | destroy)
		if [[ "$CHOSEN_NO" == "$2" ]]; then
			# Remove the container
			CMD="$DOCKER rm $1"
			echo $CMD
			eval $CMD
			# Remove the image
			echo "This option no longer exists because image names are no longer used"
			exit 1;
			#CMD="$DOCKER rmi ${NAMES[$1]}"
			#echo $CMD
			#eval $CMD
		fi
		;;

	build | rebuild)
		if [[ "$CHOSEN_NO" == "" || "$CHOSEN_NO" == "$2" ]]; then
			eval "$DOCKER rm $1"
		fi
		ACTION=build # reassigns
		;;
	esac
}

list_names() {
	for ((i = 0; i < ${#NAMES[@]}; i++)); do
		container=${project_containers[$i]}
		if [[ "$container" == "" ]]; then
			container="????????????"
		fi
		echo -e "\t${i} -> $container -> ${NAMES[$i]}"
	done
}

# ----------- Start code --------------------------------------------------

# HERE: Get list of all project containers, stopped or otherwise
CMD="docker ps -a --format \"table {{.Names}}\t{{.ID}}\t{{.Image}}\t{{.State}}\" | awk -F'\t' 'NR>1 {print \$1,\$2,\$3,\$4}'"
#echo $CMD
awkArr=($(eval "$CMD"))

running_containers=()
project_containers=()
image_names=()
orig_names=("${NAMES[@]}")                  # copy the array in another one
unset NAMES									# reset to get new order

for (( i=0; i<${#awkArr[@]}; i+=4 ))
do
    # See if we have a match
    for (( j=0; j<${#orig_names[@]}; j++ ))
    do
        name="${awkArr[$i]}"
        if [[ "$name" == "${orig_names[$j]}" ]]; then
            container="${awkArr[$i+1]}"
            image="${awkArr[$i+2]}"
            state="${awkArr[$i+3]}"

			# Always add to project_containers and image_names
			project_containers+=("$container")
			image_names+=("$image")
			NAMES+=("$name")

			# Sometimes containers are running. Add blank when not.
			if [[ "$state" == "running" ]]; then
				running_containers+=("$container")
			else
				running_containers+=("")
			fi

			if $DEBUG; then
            	echo "  Name: ${awkArr[$i]}"
            	echo "  Container: ${awkArr[$i+1]}"
            	echo "  Image: ${awkArr[$i+2]}"
            	echo "  State: ${awkArr[$i+3]}"
			fi
        fi
    done
done

# Containerless and non-docker commands
case "$ACTION" in
'')
	usage
	exit 1
	;;
list)
	# list shows a bunch of stuff amalgamated. It's only useful for smaller projects.

	SPECIFIC=$2

	echo
	if [[ "$SPECIFIC" == "images" || "$SPECIFIC" == "" ]]; then
		echo "-- IMAGES --------"
		$DOCKER image ls
	fi
	if [[ "$SPECIFIC" == "containers" || "$SPECIFIC" == "" ]]; then
		echo "-- CONTAINERS -----"
		# Same as docker ps
		$DOCKER container ls
	fi
	if [[ "$SPECIFIC" == "names" || "$SPECIFIC" == "" ]]; then
		# This lists the names in the order of this script
		echo "-- NAMES ----------"
		list_names
	fi
	exit 0
	;;
ps)
	# Various short-hand ps commands

	case "$2" in
	id|short)
		$DOCKER ps --format 'table {{.ID}}' -a
		;;
	images|Images)
		$DOCKER ps --format 'table {{.ID}}\t{{.Image}}' -a
		;;
	mounts|Mounts)
		$DOCKER ps --format 'table {{.ID}}\t{{.Mounts}}' -a
		;;
	names|Names|status|Status)
		$DOCKER ps --format 'table {{.ID}}\t{{.Names}}\t{{.RunningFor}}\t{{.Status}}' -a
		;;
	ports|Ports)
	    # This can get rather long and noisy, so just show the Ports and nuthin' else
		$DOCKER ps --format 'table {{.Names}}\t{{.Ports}}' -a
		;;
	*)
		# I find the status to be the preferred representation
		$DOCKER ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}' -a
		;;
	esac
	exit 0
	;;
tty|pause|unpause|logs|stop|rm|rmi|inspect)
	# If they didn't specify a name number, we can prompt them.
	if [[ "$2" == "" ]]; then
		choose_name
	fi
	;;
prune)
	# Light cleanup of dangling cruft
	prune
	;;
cqlsh)
	# Specialized feature to start watching UI changes realtime
	container=$(get_container_id "ingestion-scylla")
	CMD="$DOCKER exec -it $container cqlsh"
	echo $CMD
	eval $CMD
	exit 0
	;;
nuke)
	for ((i = 0; i < ${#NAMES[@]}; i++)); do
		name=${NAMES[$i]}
		running=${running_containers[$i]}
		container=${project_containers[$i]}
		image=${image_names[$i]}

		# stop all the things
		if [[ "$running" != "" ]]; then
			echo "Stopping container [$running] for $name . . . "
			$DOCKER stop $running
		fi

		# rm all the things
		if [[ "$container" != "" ]]; then
			echo "Removing container [$container] for $name . . . "
			$DOCKER rm $container
		fi

		# rmi all the things
		if [[ "$image" != "" ]]; then
			echo "Removing image [$image] for $name . . . "
			$DOCKER rmi $image
		fi
	done

	# Light cleanup of dangling cruft
	prune
	exit 0
	;;	
esac

# Perform actions on any running containers
for ((i = 0; i < ${#running_containers[@]}; i++)); do
	container=${running_containers[$i]}

	# Skip any blanks
	if [[ "$container" != "" ]]; then
		if $DEBUG; then
			echo "running container [$container]"
		fi
		running_container_action "$container" "$i"
	fi
done
if [[ ${#running_containers[@]} == 0 ]]; then
	echo "Note: There were no running named containers"
fi

# Perform actions on any existing container, stopped or otherwise
for ((i = 0; i < ${#project_containers[@]}; i++)); do
	container=${project_containers[$i]}
	# Skip any blanks
	if [[ "$container" != "" ]]; then
		if $DEBUG; then
			echo "existing container [$container]"
		fi
		existing_container_action "${project_containers[$i]}" "$i"
	fi
done

# Will drop through to here with a build
if [[ "$ACTION" == "build" ]]; then
	if build; then
		echo
		echo "-- CONTAINERS -----"
		$DOCKER container ls
	fi
fi
