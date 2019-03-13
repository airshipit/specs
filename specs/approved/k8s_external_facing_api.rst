..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: Kubernetes
   single: Promenade
   single: Security

============================================================
Deploy Kubernetes API Server w/ Ingress and Keystone Webhook
============================================================

OpenStack Keystone_ will the be single authentication mechanism for Airship
users. As such, we need to deploy a Kubernetes API server endpoint that
can utilize Keystone for authentication and authorization. The avenue to support
this is using the Kubernetes `webhook admission controller`_ with a webhook
supporting Keystone.

Links
=====

None

Problem description
===================

While Airship component APIs should care for most lifecycle tasks for the
Kubernetes cluster, there will be some maintenance and recovery operations
that will require direct access to the Kubernetes API. To properly secure
this API, it needs to utilize the common single sign-on that operators use
for accessing Airship APIs, i.e. Keystone. However, the external facing API
should minimize risk to the core Kubernetes API servers used by other
Kubernetes core components. This specification proposes a design to maximize
the security of this external facing API endpoint and minimizes the
risk to the core operations of the cluster by avoiding the need to add
complexity to core apiserver configuration or sending extra traffic through
the core apiservers and Keystone.

Impacted components
===================

The following Airship components would be impacted by this solution:

#. Promenade - Maintenance of the chart for external facing Kubernetes API
   servers

Proposed change
===============

Create a chart, ``webhook_apiserver``, for an external facing Kubernetes API server that would
create a Kubernetes Ingress entrypoint for the API server and, optionally, also spin up a
webhook side-car for each API server (i.e. ``sidecar`` mode). The other mode of operation
is ``federated`` mode where the webhook will be accessed over a Kubernetes service.

A new chart is needed because the `standard apiserver chart <https://github.com/openstack/airship-promenade/tree/master/charts/apiserver>`
relies on the anchor pattern creating static pods. The ``webhook_apiserver`` chart
should be based on the standard apiserver chart and use helm_toolkit_ standards.

The chart would provide for configuration of the `Keystone webhook`_ (also
`Keystone webhook addl`_ and `Keystone webhook chart`_) in ``sidecar`` mode and allow for configuring
the webhook service address in ``federated``` mode. The Kubernetes apiserver
would be configured to only allow for authentication/authorization via webhook.
No other authorization modes would be enabled. All ``kube-apiserver`` command line options
should match the with the following exceptions:

  - authorization-mode: ``Webhook``
  - audit-log-path: ``-``
  - authentication-token-webhook-config-file: path to configuration file for accessing the webhook.
  - authorization-webhook-config-file: path to configuration file for accessing the webhook.
  - apiserver-count: omit
  - endpoint-reconciler-type: ``none``

Webhook Configuration
---------------------

The configuration for how the Kubernetes API server will contact the webhook service is
stored in a YAML configuration file based on the `kubeconfig file format`_. The below
example would be used in ``sidecar`` mode.

.. code:: yaml
  :number-lines:

  # clusters refers to the remote service.
  clusters:
    - name: keystone-webhook
      cluster:
        # CA for verifying the remote service.
        certificate-authority: /path/to/webhook_ca.pem
        # URL of remote service to query. Must use 'https'. May not include parameters.
        server: https://localhost:4443/

  # users refers to the API Server's webhook configuration.
  users:
    - name: external-facing-api
      user:
        client-certificate: /path/to/apiserver_webhook_cert.pem # cert for the webhook plugin to use
        client-key: /path/to/apiserver_webhook_key.pem          # key matching the cert

  # kubeconfig files require a context. Provide one for the API Server.
  current-context: webhook
  contexts:
  - context:
      cluster: keystone-webhook
      user: external-facing-api
    name: webhook

Documentation impact
--------------------

Documentation of the overrides to this chart for controlling
webhook authorization mapping policy.

Security impact
---------------

- Additional TLS certificates for apiserver <-> webhook connections
- Keystone webhook must have an admin-level Keystone account
- Optionally, the Keystone webhook minimizes attack surface by becoming a sidecar without external facing service.

Performance impact
------------------

This should not have any performance impacts as the only traffic handled by the webhook
will be from users specifically using Keystone for authentication and authorization.

Testing impact
--------------

The chart should include a Helm test that validates a valid Keystone token
is usable with ``kubectl`` to successfully get a respond from the Kubernetes
API.

Implementation
==============

Milestone 1
-----------

Chart support for ``sidecar`` mode

Milestone 2
-----------

Addition of ``federated`` mode

Dependencies
============

None

References
==========

.. _Keystone: https://docs.openstack.org/keystone
.. _`webhook admission controller`: https://kubernetes.io/docs/reference/access-authn-authz/webhook/
.. _`Keystone webhook`: https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/using-keystone-webhook-authenticator-and-authorizer.md
.. _`Keystone webhook addl`: https://github.com/dims/k8s-keystone-auth
.. _`kubeconfig file format`: https://v1-10.docs.kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/
.. _`Keystone webhook chart`: https://github.com/openstack/openstack-helm-infra/tree/master/kubernetes-keystone-webhook
.. _helm_toolkit: https://docs.openstack.org/openstack-helm/latest/devref/index.html#
