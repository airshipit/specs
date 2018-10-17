..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: template
   single: creating specs

==========
miniMirror
==========

miniMirror is an application providing Debian packages for deployment.
Basically, it is `Aptly`_  in a container.

Links
=====

The work to author and implement this spec will be tracked under this
`Storyboard Story`_.

Problem description
===================

We need an ability to install Airship without any external sources for
Debian packages. The main goal is to have a single source holding
secured and pinned Debian packages only. An additional goal is a step
toward a self-contained mechanism for deploying Airship.

Proposed change
===============

miniMirror is an application providing Debian repository mirror within
k8s cluster. Debian packages are held inside miniMirror docker image.
Before the image build one should provide a list of desired repo URLs
that will be used for package downloading and optionally a list of
packages with or without specific versions. During the docker image
building, packages are downloaded and stored within the image.
Blacklist for package names can be provided as a configuration for the
container run from the built image.

How miniMirror works?
---------------------

miniMirror uses Aptly as a tool to replicate Debian repositories.
To add or modify the list of repositories one needs to rebuild the docker image.
Blacklist and/or whitelist is a list of rules for a web server
which can block requests do not satisfy to a configuration.
With such an approach the blacklist could be modified dynamically
as a chart option and it does not require image rebuild.

How miniMirror can be used?
---------------------------

If a site is configured with miniMirror the initialization script
(genesis, join) would download the miniMiror image and extract packages
required for docker and finally install docker with dpkg command.

In pseudocode it can be::

  if deploy_with_miniMirror:
     download_miniMirror_image()
     extract_debian_packages_from_miniMirror_image()
     install_docker_from_deb_package()
  else:
     install_docker_from_ubuntu_apt()

Next step, if a site is configured with miniMirror Promenade has to
create a static pod for miniMirror. After the miniMirror static pod
run, the apt source should be updated to point on localhost:$port provided
by miniMirror.

After that, Armada should deploy miniMirror from a chart, providing
k8s deployment, service, and ingress.

Impacted components
===================

The following Airship components will be impacted by this solution:

#. Airship-utils: hold miniMirror Dockerfile and Helm chart.
#. Promenade: initialization scripts are updated to install docker
   from miniMirror, run miniMirror static Pod, update apt source for a host.
#. Treasuremap, Airship-in-a-bottle: update documents to include
   miniMirror Armada chart.

Security impact
===============

These changes will result in a system that monitors Debian package
installation as logs from the miniMirror web server are available
in the k8s cluster. It should be more stable deployment as Debian package
versions are changed only with miniMiror image rebuild.

Performance impact
==================

Performance impact to existing flows will be minimal. It even could
lead to quicker Debian package installation due to the Debian package
source is localized.

Alternatives
============

One alternation is to avoid miniMirror implementation and use existing
tools like `Artifactory` to install apt sources directly. It is clearly
about controlled, pinned source of packages, having a blacklist,
installation monitoring, and offline installation for Debian packages
inside k8s cluster. As one of the Airship principles is a self-contained
deployment miniMirror could be a good step toward it.

Implementation
==============

Please refer to the `Storyboard Story`_ for implementation planning information.

Dependencies
============

Divingbell package management feature is dependent on these changes.

Documentation Impact
====================

Promenade, Treasuremap docs have to be updated according to changes.

References
==========

.. _Storyboard Story: https://storyboard.openstack.org/#!/story/2004110
.. _Aptly: https://www.aptly.info/doc/overview/
.. _Artifactory: https://www.jfrog.com/confluence/display/RTF/Welcome+to+Artifactory
