DOCKER_VERSION := 1
CP_VERSION := 3.0.1
VERSION := ${CP_VERSION}-${DOCKER_VERSION}
COMPONENTS := base kafka-rest
COMMIT_ID := $(shell git rev-parse --short HEAD)
MYSQL_DRIVER_VERSION := 5.1.39

REPOSITORY := confluentinc
#	REPOSITORY := <your_personal_repo>

clean-containers:
	for container in `docker ps -aq -f label=io.confluent.docker.testing=true` ; do \
        echo "\nRemoving container $${container} \n========================================== " ; \
				docker rm -f $${container} || exit 1 ; \
  done

clean-images:
	for image in `docker images -q -f label=io.confluent.docker | uniq` ; do \
        echo "Removing image $${image} \n==========================================\n " ; \
				docker rmi -f $${image} || exit 1 ; \
  done

base/include/etc/confluent/docker/docker-utils.jar:
	mkdir -p base/include/etc/confluent/docker
	cd java \
	&& mvn clean compile package assembly:single -DskipTests \
	&& cp target/docker-utils-1.0.0-SNAPSHOT-jar-with-dependencies.jar ../base/include/etc/confluent/docker/docker-utils.jar \
	&& cd -

build-debian: base/include/etc/confluent/docker/docker-utils.jar
	# We need to build images with confluentinc namespace so that dependent image builds dont fail
	# and then tag the images with REPOSITORY namespace
	for component in ${COMPONENTS} ; do \
		echo "\n\nBuilding $${component} \n==========================================\n " ; \
		docker build --build-arg COMMIT_ID=$${COMMIT_ID} --build-arg BUILD_NUMBER=$${BUILD_NUMBER}  -t confluentinc/cp-$${component}:latest $${component} || exit 1 ; \
		docker tag confluentinc/cp-$${component}:latest ${REPOSITORY}/cp-$${component}:latest  || exit 1 ; \
		docker tag confluentinc/cp-$${component}:latest ${REPOSITORY}/cp-$${component}:${CP_VERSION} || exit 1 ; \
		docker tag confluentinc/cp-$${component}:latest ${REPOSITORY}/cp-$${component}:${VERSION} || exit 1 ; \
		docker tag confluentinc/cp-$${component}:latest ${REPOSITORY}/cp-$${component}:${COMMIT_ID} || exit 1 ; \
  done
