..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: template
   single: creating specs

.. note::

  Blueprints are written using ReSTructured text.

Add index directives to help others find your spec. E.g.::

  .. index::
     single: template
     single: creating specs

===========================================
Airship Multiple Linux Distribution Support
===========================================

Various Airship services were developed originally around Ubuntu. This spec
will add the ability in Airship to plug in Linux Distro's, refactor the
existing Ubuntu support as the default Linux distro plugin, and add openSUSE
and other Linux distro's as new plugins.

Links
=====

The work to author and implement this spec is tracked in Storyboard:
https://storyboard.openstack.org/#!/story/2003699

Problem description
===================

Airship was originally developed focusing on the Ubuntu environment:

- While having a well defined driver interface, the baremetal provisioner
  currently only supports Canonical's MAAS.
- Promenade bootstraps only on a Ubuntu deployer.
- Assumption of Debian packages in various services.
- Builds and references only Ubuntu based container images.

Airship is missing a large user base if only supports Ubuntu.

Impacted components
===================

Most Airship components will be impacted by this spec:

#. Promenade: add the ability to bootstrap on any Linux distro and add new
   plugins for openSUSE, CentOS, etc.
#. Pegleg: enhanced to build image on non Debian distros and add openSUSE,
   CentOS and other Linux distros to CI gate.
#. Deckhand: enhanced to build image on non Debian distros and add openSUSE,
   CentOS and other Linux distros to CI gate.
#. Armada: enhanced to build image on non Debian distro and add openSUSE,
   CentOS and other Linux distros to CI gate.
#. Shipyard: enhanced to build image on non Debian distro and add openSUSE,
   CentOS and other Linux distros CI gate.
#. Drydock: enhanced to provision bare metal on non Ubuntu Linux distros using
   Ironic driver (expect to have a separate spec).
#. Airship-in-a-Bottle: add the ability to deploy Airship-in-a-Bottle on
   openSUSE, CentOS, etc.

Proposed change
===============

Pegleg
------

- Add non Ubuntu Linux distros CI gate, including openSUSE, CentOS, etc.

  - tools/gate/playbooks/docker-image-build.yaml: support Docker rpm install on
    non Debian Linux.
  - add gate test case for openSUSE, CentOS.

Deckhand
--------

- Container image(s)

  - images/deckhand/Dockerfile: add rpm package support for non Debian Linux
    distros

- Verify Deckhand Python source code and scripts are Linux distro agnostic
- Update document for rpm package installation, e.g., getting started guide
- Add Non Debian Linux support in gate playbooks

  - tools/gate/playbooks/docker-image-build.yaml
  - tools/gate/playbooks/roles/install-postgresql/tasks/install-postgresql.yaml
  - tools/gate/playbooks/roles/run-integration-tests/tasks/integration-tests.yaml
  - tools/gate/roles/install-postgresql/tasks/install-postgresql.yaml
  - tools/gate/roles/run-integration-tests/tasks/integration-tests.yaml
  - tools/run_pifpaf.sh
  - add gate test case for openSUSE, CentOS, etc.

Shipyard
--------

- Container image(s)

  - images/shipyard/Dockerfile: add rpm package for openSUSE, CentOS, etc.
  - images/airflow/Dockerfile:  add rpm package for openSUSE, CentOS, etc.

- Verify Shipyard Python source code and scripts are Linux distro agnostic.
- Update documentation where references Ubuntu and MAAS as the sole option.

  - README.rst
  - docs/source/client-user-guide.rst
  - docs/source/deployment-guide.rst

- Add non Debian Linux support in gate playbooks

  - tools/gate/playbooks/roles/build-images/tasks/airship-shipyard.yaml
  - tools/gate/roles/build-images/tasks/airship-shipyard.yaml
  - tools/gate/scripts/000-environment-setup.sh
  - add test cases in zuul for openSUSE, CentOS, etc.

Armada
------

- Container image(s)

  - Dockerfile: add rpm package for non Debian Linux (Docker file location is
    inconsistent with other projects).

- Verify Python source code and scripts are Linux distro agnostic.

- Update documentation where references Ubuntu and MAAS as the sole option,
  e.g., getting-started.rst.

- Add non Debian Linux support in gate playbooks

  - Add rpm package support when ansible_os_family is SUSE or Red Hat
  - tools/gate/playbooks/docker-image-build.yaml
  - Add test cases in zuul for openSUSE, CentOS, etc.

Promenade
---------

- Container image(s)

  - Dockerfile: add rpm package for SUSE (Docker file location is inconsistent
    with other projects)

- Verify Python source code and scripts are Linux distro agnostic, e.g.,

  - Genesis process assumes Debian-based OS. Changes are required to maintain
    this functionality for other distros as well as logic to pick the right
    template, e.g., promenade/templates/roles/common/etc/apt/sources.list.d.
  - tests/unit/api/test_update_labels.py: label is hard coded to "ubuntubox".
    which seems to be just cosmetics
  - tests/unit/api/test_validatedesign.py: deb for Docker and socat

- Update documentation where references Ubuntu and MAAS as the sole option and
  add list of docker images for other Linux OS than Ubuntu

  - getting-started.rst
  - developer-onboarding.rst
  - examples: HostSystem.yaml, armada-resources.yaml

- Add non Debian Linux support in gate playbooks

  - tools/gate/config-templates/site-config.yaml: add rpm install for Docker
    and socat based on os family
  - tools/setup_gate.sh: add rpm install for Docker based on os family
  - tools/zuul/playbooks/docker-image-build.yaml
  - tools/cleanup.sh:
  - add test cases in zuul for openSUSE, CentOS, etc.

Treasuremap
-----------

- Update documentation to add authoring and deployment instructions for
  OpenSUSE, CentOS, etc. Differences are around deb vs rpm packaging, container
  images, repos.

  - doc/source/authoring_and_deployment.rst
  - global/profiles/kubernetes-host.yaml
  - global/schemas/drydock/Region/v1.yaml
  - global/schemas/promenade/HostSystem/v1.yaml
  - global/software/config/versions.yaml
  - tools/gate/Jenkinsfile
  - global/profiles/kubernetes-host.yaml
  - site/airship-seaworthy/networks/common-addresses.yaml (points to ubuntu
    ntp server)
  - site/airship-seaworthy/profiles/region.yaml (comments references "ubuntu"
    user)
  - site/airship-seaworthy/secrets/passphrases/ubuntu_crypt_password.yaml (name
    hardcoded with "ubuntu" reference)
  - site/airship-seaworthy/software/charts/ucp/divingbell/divingbell.yaml (user
    name is hardcoded "ubuntu")
  - tools/updater.py

- Add CI gate for openSUSE, CentOS, etc.

  - tools/gate/Jenkinsfile

Security impact
---------------

Do not expect any material change in security controls and/or policies.

SUSE plans to adopt the Airship AppArmor profile in the Treasuremap project.

Performance impact
------------------

Do not expect performance impact.

Alternatives
------------

None. Extending Linux distro support is critical for Airship to expand its user
base and for its developer community to grow.

Implementation
==============

We propose three milestones to develop the feature in an iterative approach.

Milestone 1: Multi Linux distro support in the bring your own K8s and Ceph use
case. The work in this milestone is to bring Armada, Shipyard, Deckhand and
Pegleg to Linux distro agnostic, and support Ubuntu and openSUSE as the two
available options, and CentOS if there are developers familiar with CentOS
join the effort.

Milestone 2: Add the ability in bootstrapping to plug in the KubeAdm and Ceph
release/packages built for the underlying Linux distros on the existing
Physical hosts. The work is focused on Promenade component.

Milestone 3: Add the ability in Drydock to provision baremetal on Linux distros
in addition to Ubuntu.

Assignee(s):

SUSE is committed to implement this spec, add the openSUSE plugins and gate
tests, and welcomes the community to join the effort.

Dependencies
============

OpenStack Helm
--------------

1. Add the openSUSE base OS option in the OSH tool images, including
   cepf-config-helper, libvirt, OpenVSwitch, tempest, vbmc.
2. Add the ability to specify OS choice in loci.sh and support Ubuntu,
   openSUSE, CentOS etc.

LOCI
----

1. Add openSUSE base OS option in all OpenStack service images in LOCI.

Airship
-------

1. Bring your own K8s and Ceph storage. Link TBD
2. Add Ironic driver in Drydock. Link TBD

References
==========

Any external references (other than the direct links above)
