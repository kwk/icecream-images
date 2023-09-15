FEDORA_RELEASE=$(shell grep -ioP 'FROM fedora:\K[0-9]+' Containerfile)
REGISTRY=docker.io
SCHEDULER_IMAGE_NAME=$(REGISTRY)/konradkleine/icecream-scheduler:f$(FEDORA_RELEASE)
DAEMON_IMAGE_NAME=$(REGISTRY)/konradkleine/icecream-daemon:f$(FEDORA_RELEASE)

.PHONY: all
all:
	$(error Please be more specific!)

#---------------------------------------------------------------------------
# Building images
#---------------------------------------------------------------------------

.PHONY: build-images
build-images: build-scheduler-image build-daemon-image

.PHONY: build-scheduler-image
build-scheduler-image:
	BUILDAH_FORMAT=docker podman build -t $(SCHEDULER_IMAGE_NAME) --target scheduler .

.PHONY: build-daemon-image
build-daemon-image:
	BUILDAH_FORMAT=docker podman build -t $(DAEMON_IMAGE_NAME) --target daemon .

#---------------------------------------------------------------------------
# Pushing images
#---------------------------------------------------------------------------

.PHONY: push-images
push-images: push-scheduler-image push-daemon-image

.PHONY: push-scheduler-image
push-scheduler-image:
	podman push $(SCHEDULER_IMAGE_NAME)

.PHONY: push-daemon-image
push-daemon-image:
	podman push $(DAEMON_IMAGE_NAME)

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

#---------------------------------------------------------------------------
# Running
#---------------------------------------------------------------------------

.PHONY: run-scheduler
run-scheduler:
	podman run -it --rm \
		-p 8765:8765/tcp \
		-p 8766:8766/tcp \
		-p 8765:8765/udp \
		-p 8766:8766/tcp \
		$(SCHEDULER_IMAGE_NAME)

.PHONY: run-daemon
run-daemon:
	podman run -it --rm \
		-p 10245:10245/tcp \
		-p 8766:8766/tcp \
		-p 8765:8765/udp \
		-p 8766:8766/tcp \
		$(DAEMON_IMAGE_NAME)

.PHONY: run-icemon
run-icemon:
	USE_SCHEDULER=0.0.0.0:8765 icemon
	