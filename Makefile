COL_RED="\033[0;31m"
COL_GRN="\033[0;32m"
COL_END="\033[0m"

REPO=vm-from-docker

.PHONY:
all:
	/bin/bash build.sh

.PHONY:
clean: clean-docker-procs clean-docker-images
	@echo ${COL_GRN}"[Remove leftovers]"${COL_END}
	rm -f work/linux.img work/os.tar work/loopback.env

.PHONY:
clean-docker-procs:
	@echo ${COL_GRN}"[Remove Docker Processes]"${COL_END}
	@if [ "`docker ps -qa -f=label=source=${REPO}`" != '' ]; then\
		docker rm `docker ps -qa -f=label=source=${REPO}`;\
	else\
		echo "<noop>";\
	fi

.PHONY:
clean-docker-images:
	@echo ${COL_GRN}"[Remove Docker Images]"${COL_END}
	@if [ "`docker images -q ${REPO}/*`" != '' ]; then\
		docker rmi `docker images -q ${REPO}/*`;\
	else\
		echo "<noop>";\
	fi
