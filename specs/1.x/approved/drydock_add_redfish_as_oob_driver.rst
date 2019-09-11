..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

==============================================
Introduce Redfish based OOB Driver for Drydock
==============================================

Proposal to support new OOB type Redfish as OOB driver for Drydock. Redfish
is new standard for Platform management driven by DMTF.

Links
=====

https://storyboard.openstack.org/#!/story/2003007

Problem description
===================

In the current implementation, Drydock supports the following OOB types

#. IPMI via pyhgmi driver to manage baremetal servers
#. Libvirt driver to manage Virtual machines
#. Manual driver

Phygmi is python implementation for IPMI functionality. Currently phygmi
supports few commands related to power on/off, boot, events and Lenovo OEM
functions. Introducing a new IPMI command in pyghmi is complex and requires
to know the low level details of the functionality like Network Function,
Command and the data bits to be sent.

DMTF's have proposed a new Standard Platform management API Redfish using a
data model representation inside of hypermedia RESTful interface. Vendors like
Dell, HP supports Redfish and Rest API are exposed to perform any actions.
Being a REST and model based standard makes it easy for external tools like
Drydock to communicate with the Redfish server.

Impacted components
===================

The following Airship components would be impacted by this solution:

#. Drydock - new OOB driver Redfish

Proposed change
===============

Proposal is to add new OOB driver that supports all Drydock Orchestrator
actions and configure the node as per the action. The communication between
the driver and node will be REST based on Redfish resources exposed by the
node. There shall be no changes in the way driver creates tasks using
Orchestrator, exception handling and the concurrent execution of tasks.

Redfish driver
--------------
Adding a new OOB driver requires to extend the base driver
``drydock_provisioner.drivers.driver.OobDriver``.

OOB type will be named as::

    oob_types_supported = ['redfish']

All the existing Orchestrator OOB actions need to be supported. New Action
classes will be created for each of the OOB action and uses Redfish client
to configure the node.::

    action_class_map = {
        hd_fields.OrchestratorAction.ValidateOobServices: ValidateOobServices,
        hd_fields.OrchestratorAction.ConfigNodePxe: ConfigNodePxe,
        hd_fields.OrchestratorAction.SetNodeBoot: SetNodeBoot,
        hd_fields.OrchestratorAction.PowerOffNode: PowerOffNode,
        hd_fields.OrchestratorAction.PowerOnNode: PowerOnNode,
        hd_fields.OrchestratorAction.PowerCycleNode: PowerCycleNode,
        hd_fields.OrchestratorAction.InterrogateOob: InterrogateOob,
    }

Implement Action classes
------------------------

Action class have to extend the base action
``drydock_provisioner.orchestrator.actions.orchestrator.BaseAction``.
The actions are executed as threads and so each action class have to
implement the start method.

Below is the table that mentions the OOB action and the corresponding
Redfish commands. Details of each redfish command in terms of Redfish API
is specified in the next section.

.. table:: Drydock Actions and redfish commands

   ======================  =========================
   Action                  Redfish Commands
   ======================  =========================
   ValidateOobServices     Not implemented
   ConfigNodePxe           Not implemented
   SetNodeBoot             set_bootdev, get_bootdev
   PowerOffNode            set_power, get_power
   PowerOnNode             set_power, get_power
   PowerCycleNode          set_power, get_power
   InterrogateOob          get_power
   ======================  =========================

No configuration is required for the actions ValidateOobServices, ConfigNodePxe.

Redfish client
--------------

Above mentioned commands (set_bootdev, get_bootdev, set_power, get_power)
will be implemented by new class RedfishObject. This class is responsible
for converting the commands to corresponding REST API and call the
opensource python implementations of redfish clients.
python-redfish-library provided by DMTF is chosen as Redfish client.

In addition, there will be Redfish API extensions related to OEM which will
be specific to vendor. Based on the need, the RedfishObject have to handle them
and provide a clean interface to OOB actions.

The redfish REST API calls for the commands::

    Command:   get_bootdev
    Request:   GET https://<OOB IP>/redfish/v1/Systems/<System_name>/
    Response:  dict["Boot"]["BootSourceOverrideTarget"]

    Command:   set_bootdev
    Request:   PATCH https://<OOB IP>/redfish/v1/Systems/<System_name>/
               {"Boot": {
                   "BootSourceOverrideEnabled": "Once",
                   "BootSourceOverrideTarget": "Pxe",
               }}

    Command:   get_power
    Request:   GET https://<OOB IP>/redfish/v1/Systems/<System_name>/
    Response:  dict["PowerState"]

    Command:   set_power
    Request:   POST https://<OOB IP>/redfish/v1/Systems/<System_name>/Actions/ComputerSystem.Reset
               {
                   "ResetType": powerstate
               }
               Allowed powerstate values are "On", "ForceOff", "PushPowerButton", "GracefulRestart"

Configuration changes
---------------------

OOB driver that will be triggered by Drydock orchestrator is determined by

- availability of driver class in configuration parameter oob_driver
  under [plugins] section in drydock.conf
- OOB type specified in HostProfile in Site manifests

To use the Redfish driver as OOB, the OOB type in Host profile need to be
set as ``redfish`` and a new entry to be added for oob_driver in drydock.conf
``drydock_provisioner.drivers.oob.redfish_driver.RedfishDriver``

Sample Host profile with OOB type redfish::

    ---
    schema: drydock/HostProfile/v1
    metadata:
      schema: metadata/Document/v1
      name: global
      storagePolicy: cleartext
      labels:
        hosttype: global_hostprofile
      layeringDefinition:
        abstract: true
        layer: global
    data:
      oob:
        type: 'redfish'
        network: 'oob'
        account: 'tier4'
        credential: 'cred'

Security impact
---------------

None

Performance impact
------------------

None

Implementation
==============

Work Items
----------

- Add redfish driver to drydock configuration parameter ``oob_driver``

- Add base Redfish driver derived from oob_driver.OobDriver with
  oob_types_supported `redfish`

- Add RedfishObject class that uses python redfish library to talk with
  the node.

- Add OOB action classes specified in Proposed change

- Add related tests - unit test cases

Assignee(s)
-----------

Primary assignee:
  Hemanth Nakkina

Other contributors:
  PradeepKumar KS
  Gurpreet Singh

Dependencies
============

None

References
==========

.. _Redfish_standard: https://www.dmtf.org/standards/redfish
.. _Redfish_python_library: https://github.com/DMTF/python-redfish-library
