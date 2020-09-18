#!make

image_name = tinslice/postgres

build:
	docker build --pull \
		-f 12/ubuntu/18.04/Dockerfile -t ${image_name}:12-ubuntu-18.04 .

push:
	docker push ${image_name}:12-ubuntu-18.04

clean:
	docker rmi ${image_name}:12-ubuntu-18.04