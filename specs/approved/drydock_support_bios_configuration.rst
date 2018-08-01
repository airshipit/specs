..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: drydock
   single: redfish
   single: BIOS configuration

============================================================
Drydock: Support BIOS configuration using Redfish OOB driver
============================================================

Proposal to add support for configuring BIOS settings of baremetal node
via Drydock. This blueprint is intended to extend functionality of redfish
OOB driver to support BIOS configuration.

Links
=====

https://storyboard.openstack.org/#!/story/2002912

Problem description
===================

Currently drydock does not provide a mechanism to configure BIOS settings on
a baremetal node. The BIOS settings need to be configured manually prior to
triggering deployment via Airship.

Impacted components
===================

The following Airship components would be impacted by this solution:

#. Drydock - Updates to Orchestrator actions and Redfish OOB driver

Proposed change
===============

The idea is to provide user an option to specify the BIOS configuration of
baremetal nodes as part of HardwareProfile yaml in site definition documents.
Drydock gets this information from manifest documents and whenever
Orchestrator action PrepareNodes is triggered, drydock initiates BIOS
configuration via OOB drivers. As there are no new Orchestrator actions
introduced, the workflow from Shipyard --> Drydock remains the same.

This spec only supports BIOS configuration via Redfish OOB driver. Documents
having BIOS configuration with oob type other than Redfish (ipmi, libvirt)
should result in an error during document validation. This can be achieved by
adding new Validator in Drydock.

Manifest changes
----------------

A new parameter ``bios_settings`` will be added to the HardwareProfile. The
parameter takes a dictionary of strings as its value. Each key/value pair
corresponds to a BIOS setting that need to be configured. This provides
the deployment engineers the flexibility to modify the BIOS settings that
need to be configured on baremetal node.

Sample HardwareProfile with bios_settings::

    ---
    schema: 'drydock/HardwareProfile/v1'
    metadata:
      schema: 'metadata/Document/v1'
      name: dell_r640_test
      storagePolicy: 'cleartext'
      layeringDefinition:
        abstract: false
        layer: global
    data:
      vendor: 'Dell'
      generation: '8'
      hw_version: '3'
      bios_version: '2.2.3'
      boot_mode: bios
      bootstrap_protocol: pxe
      pxe_interface: 0
      bios_settings:
        BootMode: Bios
        BootSeqRetry: Disabled
        InternalUsb: Off
        SriovGlobalEnable: Disabled
        SysProfile: PerfOptimized
        AcPwrRcvry: Last
        AcPwrRcvryDelay: Immediate
      device_aliases:
        pxe_nic01:
          # eno3
          address: '0000:01:00.0'
          dev_type: 'Gig NIC'
          bus_type: 'pci'
      cpu_sets:
        kvm: '4-43,48-87'
      hugepages:
        dpdk:
          size: '1G'
          count: 300

Update the HardwareProfile schema to include a new property ``bios_settings``
of type object. The property should be optional to support backward
compatibility.

Following will be added as part of HardwareProfile schema properties::

    bios_settings:
      type: 'object'

Redfish driver updates
----------------------

Following OOB driver actions are introduced as part of this spec.

#. hd_fields.OrchestratorAction.ConfigBIOS
   To configure the BIOS settings on the node based on HardwareProfile
   manifest document

To support the above actions, following redfish commands will be added -
set_bios_settings, get_bios_settings

Redfish rest api calls to handle the above commands::

    Command:   get_bios_settings
    Request:   GET https://<OOB IP>/redfish/v1/Systems/<System_name>/Bios
    Response:  dict["Attributes"]

    Command:   set_bios_settings
    Request:   PATCH https://<OOB IP>/redfish/v1/Systems/<System_name>/Bios/Settings
               { "Attributes": {
                   "setting1": "value1",
                   "setting2": "value2"
               }}

The request and response objects for the above operations differ for vendors
HP and Dell. Above mentioned request/response objects are for Dell. In case
of HP the request/response object will be::

   {
       "setting1": "value1",
       "setting2": "value2"
   }

In case of failures in setting BIOS configuration, the Redfish server sends
the error message along with error code. The ConfigBios action should mark
the task as failure and add the error message in the task status message.

Orchestrator action updates
---------------------------

PrepareNodes Action currently run the following driver actions in sequence

#. hd_fields.OrchestratorAction.SetNodeBoot on OOB driver
   To set the boot mode to PXE
#. hd_fields.OrchestratorAction.PowerCycleNode on OOB driver
   To powercycle the node
#. hd_fields.OrchestratorAction.IdentifyNode on Node driver
   To identify the node in node driver like maas

PrepareNodes should execute the new OOB driver action as its initial step
``hd_fields.OrchestratorAction.ConfigBIOS``. PrepareNodes creates subtasks
to execute ConfigBios action for each node and collects the subtask status
until drydock timeout ``conf.timeouts.drydock_timeout``. In case of any
failure of ConfigBios subtask for a node, further driver actions wont be
executed for that node. This is in sync with the existing design and no
changes required. ConfigBios action is not retried in case of failures.

Security impact
---------------

None

Performance impact
------------------

BIOS configuration update takes around 35 seconds when invoked from a node
on same rack. This includes establishing a session, running the configuration
API and logging out the session. Time for system restart is not included.
Similarly retrieving BIOS configuration takes around 18 seconds.

Alternatives
------------

This spec only implements BIOS configuration support for Redfish OOB
driver.

Implementation
==============

Work Items
----------

- Update Hardware profile schema to support new attribute bios_setting

- Update Hardware profile objects

- Update Orchestrator action PrepareNodes to call OOB driver for BIOS
  configuration

- Update Redfish OOB driver to support new action ConfigBIOS

- Add unit test cases

Assignee(s):
------------

Primary Assignee:
  Hemanth Nakkina

Other contributors:
  Gurpreet Singh

Dependencies
============

This spec depends on ``Introduce Redfish based OOB Driver for Drydock``
https://storyboard.openstack.org/#!/story/2003007

References
==========

.. _Redfish_standard: https://www.dmtf.org/standards/redfish
