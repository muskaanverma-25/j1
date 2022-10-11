GITCOMMIT := $(shell git rev-parse --short HEAD)
GITREFERENCE := $(subst /,_,$(shell git rev-parse --abbrev-ref HEAD))
BUILD_ID ?= dev

export img_tag_latest = $(IMAGE_REGISTRY)/$(IMAGE_NAME):latest
img_tag_commit = $(IMAGE_REGISTRY)/$(IMAGE_NAME):${GITREFERENCE}-${GITCOMMIT}
img_tag_dev = $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(BUILD_ID) 

portalws_env_vars= \
--env-file ./build/.env \
--env DEV_LINUX_MACHINE_NAME=$(DEV_LINUX_MACHINE_NAME) \
--env DEV_WINDOWS_MACHINE_NAME=$(DEV_WINDOWS_MACHINE_NAME) \
--env DEV_EMAIL=$(DEV_EMAIL) \
--env DEV_MAIN_DATABASE=$(DEV_MAIN_DATABASE) \
--env DEV_DOCS_DATABASE=$(DEV_DOCS_DATABASE) \
--env DEV_PORTAL_DATABASE=$(DEV_PORTAL_DATABASE) \
--env DEV_TELUST_ASSYST_MACHINE_NAME=$(DEV_TELUST_ASSYST_MACHINE_NAME) \
--env MYSQL_USERNAME=$(MYSQL_USERNAME) \
--env MYSQL_PASSWORD=$(MYSQL_PASSWORD) \
--env PORT=$(PORT)

.PHONY: show-vars
show-vars:
	@echo "---------- MAKE ARGS ----------"
	@echo "IMAGE_REGISTRY = $(IMAGE_REGISTRY)"
	@echo "IMAGE_NAME = $(IMAGE_NAME)"
	@echo "GITCOMMIT = $(GITCOMMIT)"
	@echo "GITREFERENCE = $(GITREFERENCE)"
	@echo "BUILD_ID = $(BUILD_ID)"
	@echo "img_tag_latest = $(img_tag_latest)"
	@echo "img_tag_commit = $(img_tag_commit)"
	@echo "img_tag_dev = $(img_tag_dev)"
	@echo "--------------------------------"

.PHONY: build
build: show-vars
	@docker build --build-arg REGISTRY=$(IMAGE_REGISTRY) --rm --force-rm -f ./build/Dockerfile -t $(img_tag_latest) -t $(img_tag_commit) -t $(img_tag_dev) .

.PHONY: run
run:
	@docker run --rm --entrypoint /usr/bin/docker-entrypoint.sh -p $(PORT):$(PORT) $(portalws_env_vars) $(img_tag_latest) \
	-c "ruby script/server -e $(ENV_NAME) -p $(PORT)"

.PHONY: debug
debug: 
	@docker run --rm -it $(portalws_env_vars) $(img_tag_latest)

.PHONY: test
test:
	@docker run --rm -d $(img_tag_latest) /bin/bash -c $(TEST_COMMAND)

.PHONY: clean
clean:
	@docker rmi $(img_tag_latest) --force

.PHONY: build-push
build-push:
	@echo "Pushing $(img_tag_dev)"
	@docker push $(img_tag_dev)
	@echo $(img_tag_dev) > build.info
		
.PHONY: release-push
release-push:
	@echo "Pushing $(img_tag_latest)"
	@docker push $(img_tag_latest)
	@docker push $(img_tag_commit)
	@echo $(img_tag_dev) > build.info
	
.PHONY: portalws-run-with-deps
 portalws-run-with-deps:
	@docker-compose -f ./build/docker-compose.yml up --force-recreate -d

WAIT_PORTALWS_SEC := 3
WAIT_PORTALWS_ATTEMPTS := 5
HEALTHY_STATUS := "healthy"

.PHONY: portalws-wait-healthy
portalws-wait-healthy: portalws-run-with-deps
	@NEXT_WAIT_TIME=1; tmp_status=unknown; until [ $$tmp_status = $(HEALTHY_STATUS) ] || [ $$NEXT_WAIT_TIME -gt $(WAIT_PORTALWS_ATTEMPTS) ];\
	do echo Attempt $$NEXT_WAIT_TIME/$(WAIT_PORTALWS_ATTEMPTS) at waiting $(WAIT_PORTALWS_SEC)s till portalws container is healthy ...;\
	tmp_status="`docker inspect -f {{.State.Health.Status}} portalws`"; echo container status is $$tmp_status;\
	sleep $(WAIT_PORTALWS_SEC); NEXT_WAIT_TIME=$$((NEXT_WAIT_TIME+1)); done; \
	if [ $$tmp_status = $(HEALTHY_STATUS) ]; then echo portalws container is $(HEALTHY_STATUS)!; else echo Exceeded the number of attempts!; docker logs portalws; exit 1; fi;

WAIT_PORTALWS_PROXY_SEC := 1
WAIT_PORTALWS_PROXY_ATTEMPTS := 5

.PHONY: portalws-proxy-test
portalws-proxy-test: portalws-wait-healthy
	@NEXT_WAIT_TIME=1; tmp_code=0; until [ $$tmp_code = 401 ] || [ $$NEXT_WAIT_TIME -gt $(WAIT_PORTALWS_PROXY_ATTEMPTS) ];\
	do echo Attempt $$NEXT_WAIT_TIME/$(WAIT_PORTALWS_ATTEMPTS) at curl localhost:10000 and wait $(WAIT_PORTALWS_PROXY_SEC)s to check portalws-proxy container...;\
	sleep $(WAIT_PORTALWS_PROXY_SEC); NEXT_WAIT_TIME=$$((NEXT_WAIT_TIME+1));\
	tmp_code="`curl localhost:10000/portalws/sessions/show --fail --connect-timeout 3 --retry 0 -s -o /dev/null -w %{http_code}`"; echo response code is $$tmp_code; done; \
	if [ $$tmp_code = 401 ]; then echo portalws-proxy test succeeded!; else echo Exceeded the number of attempts!; docker logs portalws-proxy; exit 1; fi;
