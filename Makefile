FEDORA_RELEASE=$(shell grep -ioP 'FROM fedora:\K[0-9]+' Containerfile)
REGISTRY=docker.io
SCHEDULER_IMAGE_NAME=$(REGISTRY)/konradkleine/icecream-scheduler:f$(FEDORA_RELEASE)
DAEMON_IMAGE_NAME=$(REGISTRY)/konradkleine/icecream-daemon:f$(FEDORA_RELEASE)
ICECREAM_SUNDAE_IMAGE_NAME=$(REGISTRY)/konradkleine/icecream-sundae:f$(FEDORA_RELEASE)
SCHEDULER_HOST=10.0.101.32
SCHEDULER_HOST_PORT=8765
NETNAME=psi

.PHONY: all
all:
	$(error Please be more specific!)

#---------------------------------------------------------------------------
# Building images
#---------------------------------------------------------------------------

.PHONY: build-images
build-images: build-scheduler-image build-daemon-image build-icecream-sundae-image

.PHONY: build-scheduler-image
build-scheduler-image:
	BUILDAH_FORMAT=docker podman build -t $(SCHEDULER_IMAGE_NAME) --target scheduler .

.PHONY: build-daemon-image
build-daemon-image:
	BUILDAH_FORMAT=docker podman build -t $(DAEMON_IMAGE_NAME) --target daemon .

.PHONY: build-icecream-sundae-image
build-icecream-sundae-image:
	BUILDAH_FORMAT=docker podman build -t $(ICECREAM_SUNDAE_IMAGE_NAME) --target icecream-sundae .

#---------------------------------------------------------------------------
# Pushing images
#---------------------------------------------------------------------------

.PHONY: push-images
push-images: push-scheduler-image push-daemon-image push-icecream-sundae-image

.PHONY: push-scheduler-image
push-scheduler-image:
	podman push $(SCHEDULER_IMAGE_NAME)

.PHONY: push-daemon-image
push-daemon-image:
	podman push $(DAEMON_IMAGE_NAME)

.PHONY: push-icecream-sundae-image
push-icecream-sundae-image:
	podman push $(ICECREAM_SUNDAE_IMAGE_NAME)

#---------------------------------------------------------------------------
# Pulling images
#---------------------------------------------------------------------------

.PHONY: pull-images
pull-images: pull-scheduler-image pull-daemon-image

.PHONY: pull-scheduler-image
pull-scheduler-image:
	podman pull $(SCHEDULER_IMAGE_NAME)

.PHONY: pull-daemon-image
pull-daemon-image:
	podman pull $(DAEMON_IMAGE_NAME)

.PHONY: pull-icecream-sundae-image
pull-icecream-sundae-image:
	podman pull $(ICECREAM_SUNDAE_IMAGE_NAME)

#---------------------------------------------------------------------------
# Running
#
# For ports see:
# https://github.com/icecc/icecream#network-setup-for-icecream-firewalls
#---------------------------------------------------------------------------

.PHONY: run-scheduler
# 8765/tcp = scheduler port
# 8766/tcp = telnet port
# 8765/udp = broadcast port
# 
run-scheduler:
	podman run -it --rm \
		-p 8765:8765/tcp \
		-p 8766:8766/tcp \
		-p 8765:8765/udp \
		$(SCHEDULER_IMAGE_NAME) \
		  --netname $(NETNAME)

.PHONY: run-daemon
run-daemon: get-node-name
	podman run -it --rm \
		-p 10245:10245/tcp \
		$(DAEMON_IMAGE_NAME) \
			--nice 5 \
			--max-processes $(shell nproc) \
			-N $(node_name) \
			--netname $(NETNAME) \
			--scheduler-host $(SCHEDULER_HOST)

# Runs a container with a command line tool to monitor the scheduler
.PHONY: run-icecream-sundae
run-icecream-sundae:
	podman run -it --rm \
		$(ICECREAM_SUNDAE_IMAGE_NAME) \
			--scheduler $(SCHEDULER_HOST) \
			--netname $(NETNAME) \

# Runs a locally install icecream GUI called (icemon)
.PHONY: run-icemon
run-icemon:
	USE_SCHEDULER=$(SCHEDULER_HOST):$(SCHEDULER_HOST_PORT) \
	icemon \
		--netname $(NETNAME) \
		--scheduler $(SCHEDULER_HOST) \
		--port $(SCHEDULER_HOST_PORT)
	

#---------------------------------------------------------------------------
# Helper Targets
#---------------------------------------------------------------------------

.PHONY: get-hostname
# Shows the host's name
get-hostname:
        $(info Getting hostname...)
        $(eval hostname=$(shell hostname | awk '{ print toupper($$0) }'))
        $(info hostname: $(hostname))

.PHONY: get-host-ip
# Shows the host's IP address
get-host-ip:
        $(info Getting host's IP address...)
        $(eval host_ip=$(shell hostname -I | awk '{print $$2}'))
        $(info host_ip: $(host_ip))

.PHONY: get-node-name
get-node-name: get-hostname get-host-ip
	$(info Getting node name...)
	$(eval node_name=$(hostname)_$(shell echo $(host_ip) | tr "." "_"))
	$(info node_name: $(node_name))
