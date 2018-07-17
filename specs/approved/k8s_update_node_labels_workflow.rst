..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: Kubernetes node labels
   single: workflow
   single: Promenade
   single: Shipyard
   single: Drydock

=================================================
Airship workflow to update Kubernetes node labels
=================================================

Proposal to enhance Airship to support updating `Kubernetes node labels`_ as a
triggered workflow using Shipyard as an entrypoint, Deckhand as a document
repository, Drydock as the decision maker about application of node labels, and
Promenade as the interactive layer to Kubernetes_.

Links
=====

None

Problem description
===================

Over the lifecycle of a deployed site, there is a need to maintain the labels
applied to Kubernetes nodes. Prior to this change the only Airship-supplied
mechanism for this was during a node's deployment. Effectively, the way to
change or remove labels from a deployed node is through a manual process.
Airship aims to eliminate or minimize manual action on a deploy site.

Without the ability to declaratively update the labels for a Kubernetes node,
the engineers responsible for a site lose finer-grained ability to adjust where
deployed software runs -- i.e. node affinity/anti-affinity. While the
software's Helm or Armada chart could be adjusted and the site updated, the
granularity of marking a single node with a label is still missed.

Impacted components
===================

The following Airship components would be impacted by this solution:

#. Drydock - endpoint(s) to evaluate and trigger adding or removing labels on
   a node
#. Promenade - endpoint(s) to add/remove labels on a node.
#. Shipyard - new workflow: update_labels

Proposed change
===============

.. note::

  External to Airship, the process requires updating the site definition
  documents describing `Baremetal Nodes`_ to properly reflect the desired
  labels for a node. The workflow proposed below does not allow for addition
  or elimination of node labels without going through an update of the site
  definition documents.

Shipyard
--------

To achieve the goal of fine-grained declarative Kubernetes label management,
a new Shipyard action will be introduced: ``update_labels``. The update_labels
action will accept a list of targeted nodes as an action parameter. E.g.::

  POST /v1.0/actions

  {
    "name" : "action name",
    "parameters" : {
      "target_nodes": [ "node1", "node2"]
    }
  }

The most recent committed configuration documents will be used to drive the
labels that result on the target nodes.

- If there is no committed version of the configuration documents, the action
  will be rejected.
- If there are no revisions of the configuration documents marked as
  participating in a site action, the action will be rejected.

A new workflow will be invoked for ``update_labels``, being passed the
configuration documents revision and the target nodes as input, using existing
parameter mechanisms.

.. note::

  At the time of writing this blueprint, there are no other actions exposed by
  Shipyard that are focused on a set of target nodes instead of the whole site.
  This introduces a new category of ``targeted`` actions, as opposed to the
  existing ``site`` actions. Targeted actions should not set the site action
  labels (e.g. successful-site-action) on Deckhand revisions as part of the
  workflow.

The workflow will perform a standard validation of the configuration documents
by the involved components (Deckhand, Drydock, Promenade).

Within the Shipyard codebase, a new Drydock operator will be defined to invoke
and monitor the invocation of Drydock to trigger label updates. Using the
task interface of Drydock, a node filter containing the target nodes will be
used to limit the scope of the request to only those nodes, along with the
design reference. E.g.::

  POST /v1.0/tasks

  {
    "action": "relabel_nodes",
    "design_ref": "<deckhand_uri>",
    "node_filter": {
      "filter_set_type": "union",
      "filter_set": [
        {
          "filter_type": "union",
          "node_names": ["node1", "node2"],
          "node_tags": [],
          "node_labels": {},
          "rack_names": [],
          "rack_labels": {},
        }
      ]
    }
  }

.. note::

  Since a node filter is part of this interface, it would technically allow for
  other ways to assign labels across nodes. However at this time, Shipyard will
  only leverage the node_names field.

After invoking Drydock (see below), the workflow step will use the top level
Drydock task result, and disposition the step as failure if any nodes are
unsuccessful. This may result in a partial update. No rollbacks will be
performed.


Drydock
-------

Drydock's task API will provide a new action ``relabel_nodes``. This action will
perform necessary analysis of the design to determine the full set of labels
that should be applied to each node. Some labels are generated dynamically
during node deployment; these will need to be generated and included in the
set of node labels.

Since multiple nodes can be targeted, and success or failure may occur on each,
Drydock will track these as subtasks and roll up success/failure per node to
the top level task.

Promenade
---------

For each node, Drydock will invoke Promenade to apply the set of labels to the
Kubernetes node, using a ``PUT`` against the (new) ``node-labels/{node_name}``
endpoint. The payload of this request is a list of labels for that node. E.g.::

  PUT /v1.0/node-labels/node1

  {
    "label-a":"true",
    "label-n":"some-value"
  }

Promenade will perform a difference of the existing node labels against the
requested node labels. Promenade will then in order:

#) apply new labels and change existing labels with new values
#) remove labels that are not in the request body

API Clients and CLIs
~~~~~~~~~~~~~~~~~~~~

The Drydock, Promenade, and Shipyard API Clients and CLI components will need
to be updated to match the new functionality defined above.

Documentation impact
--------------------

Each of the identified components have associated API (and CLI) documentation
that will be updated to match the new API endpoints and associated payload
formats as noted above.

Security impact
---------------

None - No new security impacts are introduced with this design. Existing
mechanisms will be applied to the changes introduced.

Performance impact
------------------

None - This workflow has no specific performance implications for the
components involved.

High level process
------------------
::

      Shipyard                Workflow                 Drydock                    Promenade
  +---------------+        +-------------+
  | Submit Action +------> |             |
  | update_labels |        |             |
  |               |        |Drydock Task:|       +------------------+
  +---------------+        | relabel_node+-----> |Evaluate baremetal|
                           |             |       |definition;       |
                           |Monitor Task +-----> |generate k8s node |
                           |             |  Poll |labels            |
                           |             | <-----+                  |
                           |             |       |Promenade:        |         +-------------------+
                           |             |       | PUT node-labels  +-------> |Diff existing node |
                           |             |       |  (list of labels)|  Wait   | labels.           |
                           |             |       |                  | <-------+ Add new labels    |
                           |             |       +------------------+         | Remove orphaned   |
                           |             |                                    |  labels           |
                           |             |                                    |                   |
                           |             |                                    +-------------------+
                           |End workflow |
                           |             |
                           +-------------+

Implementation
==============

There are no specific milestones identified for this blueprint.

https://review.openstack.org/#/c/584925/ is work that has started for
Promenade.

Dependencies
============

None

References
==========

.. _Kubernetes: https://kubernetes.io/
.. _Kubernetes node labels: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
.. _Baremetal Nodes: https://airshipit.readthedocs.io/projects/drydock/en/latest/topology.html#host-profiles-and-baremetal-nodes
