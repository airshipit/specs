..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: Divingbell
   single: Ansible

============================
Divingbell Ansible Framework
============================

Ansible playbooks to achieve tasks for making bare metal changes
for Divingbell target use cases.

Links
=====

The work to author and implement this spec will be tracked under this `Storyboard Story`_

Problem description
===================

Divingbell uses DaemonSets and complex shell scripting to make bare metal
changes. This raises 2 problems:
- Increasing number of DaemonSets on each host with increasing Divingbell
usecases
- Reinventing the wheel by writing complex shell scripting logic to make
bare metal changes.

Impacted components
===================

The following Airship components will be impacted by this solution:

#. Divingbell: Introducing Ansible framework to make bare metal changes

Proposed change
===============

This spec intends to introduce Ansible framework within Divingbell which is
much simpler to make any bare metal configuration changes as compared to
existing approach of writing complex shell scripting to achieve the same
functionality.

Adding playbook
---------------

Ansible playbooks should be written for making any configuration changes
on the host.

Existing shell script logic for making bare metal changes lives under
``divingbell/templates/bin``, wherever applicable these should be replaced
by newly written Ansible playbooks as described in the sections below.
Ansible playbooks would be part of the Divingbell image.

A separate directory structure needs to be created for adding the playbooks.
Each Divingbell config can be a separate role within the playbook structure.

::
    - playbooks/
        - roles/
             - systcl/
             - limits/
        - group_vars
             - all
        - master.yml

Files under ``group_vars`` should be loaded as a Kubernetes ``ConfigMap`` or
``Secret`` inside the container. Existing entries in ``values.yaml`` for
Divingbell should be used for populating the entries in the file under
``group_vars``.

This PS `Initial commit for Ansible framework`_ should be used as a reference
PS for implementing the Ansibile framework.

Ansible Host
------------

With Divingbell DaemonSet running on each host mounted at ``hostPath``,
``hosts`` should be defined as given below within the ``master.yml``.

::
    hosts: all
    connection: chroot

Ansible chroot plugin should be used for making host level changes.
`Ansible chroot plugin_`

Divingbell Image
----------------

Dockerfile should be created containing the below steps:

  - Pull base image
  - Install Ansible
  - Define working directory
  - Copy the playbooks to the working directory

Divingbell DaemonSets
---------------------

All the Divingbell DaemonSets that follow declarative and idempotent models
should be replaced with a single DaemonSet. This DaemonSet will be
responsible for populating required entries in ``group_vars`` as
``volumeMounts``. Ansible command to run the playbook should be invoked from
within the ``DaemonSet`` spec.

The Ansible command to run the playbook should be invoked from within
the ``DaemonSet`` spec.

The Divingbell DaemonSet for ``exec`` module should be left out from this framework
and it should keep functioning as a separate DaemonSet.

Ansible Rollback
----------------

Rollback should be achieved via the ``update_site`` action i.e. if a playbook
introduces a bad change into the environment then the recovery path would be to
correct the change in the playbooks and run ``update_site`` with new changes.

Security impact
---------------

None -  No new security impacts are introduced with this design.

Performance impact
------------------

As this design reduces the number of DaemonSets being used within Divingbell,
it will be an improvement in performance.

Implementation
==============

This implementation should start off as a separate entity and not make
parallel changes by removing the existing functonality.

New Divingbell usecases can be first targetted with the Ansible framework
while existing framework can co-exist with the new framework.

Dependencies
============

Adds new dependency - Ansible framework.

References
==========

.. _Storyboard Story: https://storyboard.openstack.org/#!/story/2004690
.. _Initial commit for Ansible framework: https://review.openstack.org/#/c/639186/
.. _Ansible chroot plugin: https://docs.ansible.com/ansible/latest/plugins/connection/chroot.html
