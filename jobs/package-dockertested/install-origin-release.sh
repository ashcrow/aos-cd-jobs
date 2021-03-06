#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

cd /data/src/github.com/openshift/origin
jobs_repo="/data/src/github.com/openshift/aos-cd-jobs/"
git log -1 --pretty=%h >> "${jobs_repo}/ORIGIN_COMMIT"
( source hack/lib/init.sh; os::build::rpm::get_nvra_vars; echo "-${OS_RPM_VERSION}-${OS_RPM_RELEASE}" ) >> "${jobs_repo}/ORIGIN_PKG_VERSION"

docker pull openshift/origin-docker-registry:latest
docker tag openshift/origin-docker-registry:latest "openshift/origin-docker-registry:$( cat "${jobs_repo}/ORIGIN_COMMIT" )"

cd /data/src/github.com/openshift/aos-cd-jobs
playbook_base='/usr/share/ansible/openshift-ansible/playbooks/'
if [[ -s "${playbook_base}/openshift-node/network_manager.yml" ]]; then
    playbook="${playbook_base}openshift-node/network_manager.yml"
else
    playbook="${playbook_base}byo/openshift-node/network_manager.yml"
fi
ansible-playbook -vv --become               \
                 --become-user root         \
                 --connection local         \
                 --inventory sjb/inventory/ \
                 -e deployment_type=origin  \
                 ${playbook}
ansible-playbook -vv --become               \
                 --become-user root         \
                 --connection local         \
                 --inventory sjb/inventory/ \
                 -e deployment_type=origin  \
                 -e openshift_pkg_version="$( cat ./ORIGIN_PKG_VERSION )"               \
                 -e oreg_url='openshift/origin-${component}:'"$( cat ./ORIGIN_COMMIT )" \
                 -e openshift_disable_check=docker_image_availability,package_update,package_availability    \
                 /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml
sudo chmod a+x /etc/ /etc/origin/ /etc/origin/master/
sudo chmod a+rw /etc/origin/master/admin.kubeconfig
