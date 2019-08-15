..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: airshipctl
   single: bootstrap
   single: ISO
   single: image
   single: CLI
   single: ephemeral host

====================================
Airshipctl Bootstrap Image Generator
====================================

This spec defines the new ``isogen`` sub-command for ``airshipctl bootstrap``
and describes the interface for image builder. Airship CLI tool will be extended
with an ability to generate an ISO image or image for USB stick. This image
can be used to boot up an ephemeral node with Kubernetes cluster installed.

Links
=====

Jira tasks:

- `airshipctl bootstrap isogen <https://airship.atlassian.net/browse/AIR-98>`_
- `LiveCD PoC <https://airship.atlassian.net/browse/AIR-132>`_
- `ISO builder contract spec <https://airship.atlassian.net/browse/AIR-133>`_
- `isogen subcommand spec <https://airship.atlassian.net/browse/AIR-136>`_
- `Sub command implementation <https://airship.atlassian.net/browse/AIR-137>`_
- `Cloud-init generator <https://airship.atlassian.net/browse/AIR-145>`_

Problem Description
===================

Common approach for spinning new Kubernetes cluster is Cluster API deployed
on top of a small single node cluster based on ``kind`` or ``minikube``.
In order to create Kubernetes cluster on hardware nodes in Data Center user
must deploy this single node cluster on a virtual machine attached to PXE
network or to deploy operating system and Kubernetes cluster to one of the
hardware servers.

In scope of Airship 2.0 user needs to be able to bootstrap ephemeral Kubernetes
cluster with minimal required services (e.g. Cluster API, Metal3, etc).
Ephemeral Cluster should be deployed remotely (if possible) and deployment process
needs to be fully automated.

Impacted Components
===================

- airshipctl

Proposed Change
===============

Airship 2.0 command line tool (i.e. ``airshipctl``) will be able to perform
full cycle of bootstrapping ephemeral Kubernetes node.

First bootstrap step is to generate ISO or flash drive image. Image generator
is executed inside of a container and returns LiveCD or LiveUSB image.

Image generator must implement interface defined below (see
`Image Generator Container Interface`_ section) since ``isogen``
command treats image generator container as a black box.

Airshipctl Subcommand
---------------------

``airshipctl bootstrap`` is extended with ``isogen`` subcommand.
Subcommand is extendable by adding  Container Runtime Interface drivers.

Command flags:

- ``-c`` or ``--conf`` Configuration file (YAML-formatted) path for ISO
  builder container. If option is omitted ``airshipctl config`` is used to
  determine isogen configuration file path. This configuration file is used
  to identify container execution options (e.g. CRI, volume binds etc) and
  as a source of ISO builder parameters (e.g. cloud-init configuration file
  name). File format described in
  `Command and ISO Builder Configuration File Format`_

Command arguments:

- ``-`` can be used when rendered document model has been passed to STDIN.

Subcommand should implement following steps:

- Utilize the ``airshipctl config`` to identify the location of YAML documents
  which contains site information.

- Extract information for ephemeral node from the appropriate documents,
  such as IP, Name, MAC, etc.

- Generate the appropriate user-data and network-config for Cloud-Init.

- Execute container with ISO builder and put YAML-formatted builder config,
  user-data and network-config to a container volume.

YAML manipulations which are required for operations described above rely on
functions and methods that have been implemented as a part of
``airshipctl document`` command.

Image Generator Container Interface
-----------------------------------

Image generator container input.

- Volume (host directory) mounted to certain directory in container. Example:
  ``docker run -v /source/path/on/host:/dst/path/in/container ...``

- YAML-formatted configuration file saved on the mounted volume. Described in
  `Command and ISO Builder Configuration File Format`_

- Shell environment variable ``BUILDER_CONFIG`` which contains ISO builder
  configuration file path (e.g. if volume is bound to ``/data`` in the
  container then ``BUILDER_CONFIG=/data/isogen.yaml``).

- Cloud-init configuration file named according to ``userDataFileName``
  parameter of ``builder`` section specified in ISO builder configuration file.
  User data file must be placed to the root of the volume which is bound to
  the container.

- Network configuration for cloud init (i.e. network-config)
  named according to ``networkConfigFileName`` parameter of ``builder`` section
  specified in ISO builder configuration file. Network configuration file must
  be placed in the root of the volume which is bound to the container.

Image generator output.

- YAML-formatted metadata file which describes output artifacts. File name for
  metadata is specified in ``builder`` section of ISO builder configuration
  file (see `Command and ISO Builder Configuration File Format`_ for details).
  Metadata file name is specified in ``aitshipctl`` configuration files and
  handeled by ``airshipctl config`` command. Metadata must satisfy
  following schema.

  .. code-block:: yaml

    $schema: 'http://json-schema.org/schema#'
    type: 'object'
    properties:
      bootImagePath:
        type: 'string'
        description: >
          Image file path on host. Host path of the volume is extracted
          from ISO builder confgiration file passed by isogen command to
          container volume.

- ISO or flash disk image placed according to ``bootImagePath`` parameter of
  output metadata file.

Command and ISO Builder Configuration File Format
-------------------------------------------------

YAML formatted configuration file is used for both isogen command and ISO
builder container. Configuration file is copied to volume directory on the
host. ISO builder uses shell environment variable ``BUILDER_CONFIG`` to read
determine configuration file path inside container.

Configuration file format.

.. code-block:: yaml

  $schema: 'http://json-schema.org/schema#'
  type: 'object'
  properties:
    container:
      type: 'object'
      description: 'Configuration parameters for container'
      properties:
        volume:
          type: 'string'
          description: >
            Container volume directory binding.
            Example: /source/path/on/host:/dst/path/in/container
        image:
          type: 'string'
          description: 'ISO generator container image URL'
        containerRuntime:
          type: 'string'
          description: >
            (Optional) Container Runtime Interface driver (default: docker)
        privileged:
          type: 'bool'
          description: >
            (Optional)Defines if container should be started in privileged mode
            (default: false)
    builder:
      type: 'object'
      description: 'Configuration parameters for ISO builder'
      properties:
        userDataFileName:
          type: 'string'
          description: >
            Cloud Init user-data file name placed to the container volume root
        networkConfigFileName:
          type: 'string'
          description: >
            Cloud Init network-config file name placed to the container
            volume root
        outputMetadataFileName:
          type: 'string'
          description: 'File name for output matadata'

Security Impact
---------------

- Kubernetes Certificates are saved on the ISO along with other Cloud Init
  configuration parameters.
- Clound-init contains sensitive information (e.g. could contain ssh keys).

Performance impact
------------------

None

Alternatives
------------

- Modify existing LiveCD ISO image using Golang library.

  - Requires implementation of ISO modification module in Golang.
  - Each time user generated new image ISO content has to be copied to
    temporary build directory since ISO 9660 is read only file system.
  - Support multiple operating systems is challenging since there is no
    standard for ISO image directory structure and live booting.

Implementation
==============

- Image Generator reference implementation based on Debian container from
  airship/images Git repository

  - Dockerfile with all packages required to build LiveCD ISO.
  - Builder script.

- ``airshipctl bootstrap`` extension with new command (i.e.
  ``airshipctl bootstrap isogen``)

  - Define interface for running container execution which enables following
    methods:

    - Pull image: download container image if it's not presented locally
    - Run container: start container, wait for builder script is finished,
      output builder log if CLI debug flag is enabled
    - Run container with output: executes run container method and prints its
      STDOUT
    - Remove container: removes container if command execution successful.

  - Implement interface for docker Container Runtime Environment

Dependencies
============

- New version of hardware nodes definition format in Treasuremap since
  Metal3-IO will replace MAAS for Airship 2.0

References
==========

None
