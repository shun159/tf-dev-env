TF_DE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TF_DE_TOP := $(abspath $(TF_DE_DIR)/../)/
SHELL=/bin/bash -o pipefail

# include RPM-building targets
-include $(TF_DE_TOP)contrail/tools/packages/Makefile

REPODIR=$(TF_DE_TOP)contrail
CONTAINER_BUILDER_DIR=$(REPODIR)/contrail-container-builder
CONTRAIL_DEPLOYERS_DIR=$(REPODIR)/contrail-deployers-containers
CONTRAIL_TEST_DIR=$(REPODIR)/third_party/contrail-test
export REPODIR
export CONTRAIL_DEPLOYERS_DIR
export CONTRAIL_TEST_DIR
export CONTAINER_BUILDER_DIR

all: dep rpm containers

fetch_packages:
	@$(TF_DE_DIR)scripts/fetch-packages.sh

setup:
	@yum autoremove -y python2-requests python2-urllib3
	@python2 -m pip list | grep urllib3 >/dev/null && python2 -m pip uninstall -y urllib3 requests chardet || true
	@python2 -m pip -q uninstall -y setuptools || true
	@yum -q reinstall -y python2-setuptools
	@yum -q install -y python2-requests python2-urllib3

sync:
	@$(TF_DE_DIR)scripts/sync-sources.sh

##############################################################################
# RPM repo targets
create-repo:
	@mkdir -p $(REPODIR)/RPMS
	@createrepo --update $(REPODIR)/RPMS/
	@echo "INFO: clean all for contrail repo after udpate"
	@yum clean all --disablerepo=* --enablerepo=contrail || true

update-repo: create-repo

clean-repo:
	@test -d $(REPODIR)/RPMS/repodata && rm -rf $(REPODIR)/RPMS/repodata || true

setup-httpd:
	@$(TF_DE_DIR)scripts/setup-httpd.sh

##############################################################################
# Contrail third party packaged
build-tpp:
	@$(TF_DE_DIR)scripts/build-tpp.sh

package-tpp:
	@$(TF_DE_DIR)scripts/package-tpp.sh

##############################################################################
# Container deployer-src targets
src-containers:
	@$(TF_DE_DIR)scripts/package/build-src-containers.sh |& sed "s/^/src-containers: /"

##############################################################################
# Container builder targets
prepare-containers:
	@$(TF_DE_DIR)scripts/package/prepare-containers.sh |& sed "s/^/containers: /"

list-containers:
	@$(TF_DE_DIR)scripts/package/list-containers.sh $(CONTAINER_BUILDER_DIR) container

container-%:
	@$(TF_DE_DIR)scripts/package/build-containers.sh $(CONTAINER_BUILDER_DIR) container $(patsubst container-%,%,$(subst _,/,$(@))) | sed "s/^/$(@): /"

containers-only:
	@$(TF_DE_DIR)scripts/package/build-containers.sh $(CONTAINER_BUILDER_DIR) container |& sed "s/^/containers: /"

containers: prepare-containers containers-only

##############################################################################
# Container deployers targets
prepare-deployers:
	@$(TF_DE_DIR)scripts/package/prepare-deployers.sh |& sed "s/^/deployers: /"

list-deployers:
	@$(TF_DE_DIR)scripts/package/list-containers.sh $(CONTRAIL_DEPLOYERS_DIR) deployer

deployer-%:
	@$(TF_DE_DIR)scripts/package/build-containers.sh $(CONTRAIL_DEPLOYERS_DIR) deployer $(patsubst deployer-%,%,$(subst _,/,$(@))) | sed "s/^/$(@): /"

deployers-only:
	@$(TF_DE_DIR)scripts/package/build-containers.sh $(CONTRAIL_DEPLOYERS_DIR) deployer |& sed "s/^/deployers: /"

deployers: prepare-deployers deployers-only

##############################################################################
# Operator container targets
operator-containers:
	@$(TF_DE_DIR)scripts/package/build-operator-containers.sh |& sed "s/^/operator-containers: /"

##############################################################################
# Test container targets
test-containers:
	@$(TF_DE_DIR)scripts/package/build-test-containers.sh |& sed "s/^/test-containers: /"

##############################################################################
# Unit Test targets
test:
	@$(TF_DE_DIR)scripts/run-tests.sh $(TEST_PACKAGE)

##############################################################################
# Other clean targets
clean-rpm:
	@test -d $(REPODIR)/RPMS && rm -rf $(REPODIR)/RPMS/* || true

clean: clean-deployers clean-containers clean-repo clean-rpm
	@true

dbg:
	@echo $(TF_DE_TOP)
	@echo $(TF_DE_DIR)

.PHONY: clean-deployers clean-containers clean-repo clean-rpm setup build containers deployers createrepo all
