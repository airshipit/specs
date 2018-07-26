..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: instructions
   single: getting started

.. _instructions:

============
Instructions
============

- Use the template.rst as the basis of your specification.
- Attempt to detail each applicable section.
- If a section does not apply, use N/A, and optionally provide
  a short explanation.
- New specs for review should be placed in the ``approved`` subfolder, where
  they will undergo review and approval in Gerrit_.
- Specs that have finished implementation should be moved to the
  ``implemented`` subfolder

Indexing and Categorization
---------------------------

Use of the `index`_ directive in reStructuredText for each document provides
the ability to generate indexes to more easily find items later. Authors are
encouraged to use index entries for their documents to help with discovery.

Naming
------

Document naming standards help readers find specs. For the Airship repository,
the following document naming is recommended. The categories listed here are
likely incomplete, and may need expansion to cover new cases. It is preferrable
to deviate (and hopefully amend the list) than force document names into
nonsense categories. Prefer using categories that have previously been used or
that are listed here over new categories, but don't force the category into
something that doesn't make sense.

Document names should follow a pattern as follows::

  [category]_title.rst

Use the following guidelines to determine the category to use for a document:

1) For new functionality and features, the best choice for a category is to
   match a functional duty of Airship.

site-definition
  Parts of the platform that support the definition of a site, including
  management of the yaml definitions, document authoring and translation, and
  the collation of source documents.

genesis
  Used for the steps related to preparation and deployment of the genesis node
  of an Airship deployment.

baremetal
  Those changes to Airflow that provide for the lifecycle of bare metal
  components of the system - provisioning, maintenance, and teardown. This
  includes booting, hardware and network configuration, operating system, and
  other host-level management

k8s
  For functionality that is about interfacing with Kubernetes directly, other
  than the initial setup that is done during genesis.

software
  Functionality that is related to the deployment or redeployment of workload
  onto the Kubernetes cluster.

workflow
  Changes to existing workflows to provide new functionality and creation of
  new workflows that span multiple other areas (e.g. baremetal, k8s, software),
  or those changes that are new arrangements of existing functionality in one
  or more of those other areas.

administration
  Security, logging, auditing, monitoring, and those things related to site
  administrative functions of the Airship platform.

2) For specs that are not feature focused, the component of the system may
   be the best choice for a category, e.g. ``shipyard``, ``armada`` etc...
   When there are multiple components involved, or the concern is cross
   cutting, use of ``airship`` is an acceptable category.

3) If the spec is related to the ecosystem Airship is maintained within, an
   appropriate category would be related to the aspect it is impacting, e.g.:
   ``git``, ``docker``, ``zuul``, etc...

.. _index: http://www.sphinx-doc.org/en/stable/markup/misc.html#directive-index
.. _Gerrit: https://review.openstack.org/#/q/project:openstack/airship-specs
