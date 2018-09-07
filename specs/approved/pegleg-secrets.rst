..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: template
   single: creating specs

=======================================
Pegleg Secret Generation and Encryption
=======================================

Pegleg is responsible for shepherding deployment manifest documents from their
resting places in Git repositories to a consumable format that is ready
for ingestion into Airship.  This spec expands its responsibility to
account for secure generation and encryption of secrets that are
required within an Airship-based deployment.

Links
=====

The work to author and implement this spec will be tracked under this
`Storyboard Story`_.

Problem description
===================

Airship supports the ability to identify secret information
required for functioning deployments, such as passwords and keys; to
ingest it into the site in a least-privilege-oriented fashion; and
to encrypt it at rest within Deckhand.  However, lifecycle management of
the secrets outside the site should be made automatable and
repeatable, to facilitate operational needs such as periodic password
rotation, and to ensure that unencrypted secrets are only accessible by
authorized individuals.

Impacted components
===================

The following Airship components will be impacted by this solution:

#. Pegleg: enhanced to generate, rotate, encrypt, and decrypt secrets.
#. Promenade: PKICatalog will move to Pegleg.
#. Treasuremap: site manifests augmented to support the updated Secrets schema.
#. Airship-in-a-Bottle: site manifests augmented to support the updated
   Secrets schema.

Proposed change
===============

PeglegManagedDocument
---------------------

With this spec, the role of Pegleg grows from being a custodian of deployment
manifests to additionally being the author of certain manifests.  A new YAML
schema will be created to describe these documents:
``pegleg/PeglegManagedDocument/v1``.
Documents of this type will have one or both of the following data elements,
although more may be added in the future: ``generated``, ``encrypted``.
PeglegManagedDocuments serve as wrappers around other documents, and the
wrapping serves to capture additional metadata that is necessary, but
separate from the managed document proper.
The managed document data will live in the ``data.managedDocument`` portion
of a PeglegManagedDocument.

If a PeglegManagedDocument is ``generated``, then its contents have been
created by Pegleg, and it must include provenance information per this
example::

  schema: pegleg/PeglegManagedDocument/v1
  metadata:
    name: matches-document-name
    schema: deckhand/Document/v1
    labels:
      matching: wrapped-doc
    layeringDefinition:
      abstract: false
      # Pegleg will initially support generation at site level only
      layer: site
    storagePolicy: encrypted
  data:
    generated:
      at: <timestamp>
      by: <author>
      specifiedBy:
        repo: <...>
        reference: <git ref-head or similar>
        path: <PKICatalog/PassphraseCatalog details>
    managedDocument:
      metadata:
        storagePolicy: encrypted
        schema: <as appropriate for wrapped document>
        <metadata from parent PeglegManagedDocument>
        <any other metadata as appropriate>
      data: <generated data>

If a PeglegManagedDocument is ``encrypted``, then its contents have been
encrypted by Pegleg, and it must include provenance information per this
example::

  schema: pegleg/PeglegManagedDocument/v1
  metadata:
    name: matches-document-name
    schema: deckhand/Document/v1
    labels:
      matching: wrapped-doc
    layeringDefinition:
      abstract: false
      layer: matching-wrapped-doc
    storagePolicy: encrypted
  data:
    encrypted:
      at: <timestamp>
      by: <author>
    managedDocument:
      metadata:
        storagePolicy: encrypted
        schema: <as appropriate for wrapped document>
        <metadata from parent PeglegManagedDocument>
        <any other metadata as appropriate>
      data: <encrypted string blob>

A PeglegManagedDocument that is both generated via a Catalog, and encrypted
(as specified by the catalog) will contain both ``generated`` and
``encrypted`` stanzas.

Note that this ``encrypted`` has a different purpose than the Deckhand
``storagePolicy: encrypted`` metadata, which indicates an *intent* for Deckhand
to store a document encrypted at rest in the cluster.  The two can be used
together to ensure security, however:  if a document is marked as
``storagePolicy: encrypted``, then automation may validate that it is only
persisted (e.g. to a Git repository) if it is in fact encrypted within
a PeglegManagedDocument.

Document Generation
-------------------

Document generation will follow the pattern established by Promenade's
PKICatalog pattern.  In fact, PKICatalog management responsibility will move
to Pegleg as part of this effort.  The types of documents that are expected
to be generated are certificates and keys, which are defined via PKICatalog
documents now, and passphrases, which will be defined via a new
``pegleg/PassphraseCatalog/v1`` document.  Longer-term, these specifications
may be combined, or split further (into a CertificateCatalog and
KeypairCatalog), but this is not needed in the initial implementation in
Pegleg.  A collection of manifests
may define more than one of each of these secret catalog documents if desired.

The documents generated via PKICatalog and PassphraseCatalog will follow the
PeglegManagedDocument schema above; note that this is a change to existing
PKICatalog behavior.  The PKICatalog schema and associated code should be
copied to Pegleg (and renamed to ``pegleg/PKICatalog/v1``), and during a
transition period the old and new PKICatalog implementations will exist
side-by-side with slightly different semantics.  Promenade's PKICatalog can
be removed once all deployment manifests have been updated to use the new one.

Pegleg will place generated document files in ``<site>/secrets/passphrases/``,
``<site>/secrets/certificates``, or ``<site>/secrets/keypairs`` as appropriate:

* The generated filenames for passphrases will follow the pattern
  ``<passphrase-doc-name>.yaml``.
* The generated filenames for certificate authorities will follow the pattern
  ``<ca-name>_ca.yaml``.
* The generated filenames for certificates will follow the pattern
  ``<ca-name>_<certificate-doc-name>_certificate.yaml``.
* The generated filenames for certificate keys will follow the pattern
  ``<ca-name>_<certificate-doc-name>_key.yaml``.
* The generated filenames for keypairs will follow the pattern
  ``<keypair-doc-name>.yaml``.
* Dashes in the document names will be converted to underscores for consistency.

A PassphraseCatalog will capture the following example structure::

  schema: pegleg/PassphraseCatalog/v1
  metadata:
    schema: metadata/Document/v1
    name: cluster-passphrases
    layeringDefinition:
      abstract: false
      layer: site
    storagePolicy: cleartext
  data:
    passphrases:
      - document_name: osh-nova-password
        description: Service password for Nova
        encrypted: true
      - document_name: osh-nova-oslo-db-password
        description: Database password for Nova
        encrypted: true
        length: 12

The nonobvious bits of the document described above are:

* ``encrypted`` is optional, and denotes whether the generated
  PeglegManagedDocument will be ``encrypted``, as well as whether the wrapped
  document will have ``storagePolicy: encrypted`` or
  ``storagePolicy: cleartext`` metadata.
  If absent, ``encrypted`` defaults to ``true``.
* ``document_name`` is required, and is used to create the filename of the
  generated PeglegManagedDocument manifest, and the ``metadata.name`` of
  the wrapped ``deckhand/Passphrase/v1`` document.  In both cases, Pegleg will
  replace dashes in the ``document_name`` with underscores.
* ``length`` is optional, and denotes the length in characters of the
  generated cleartext passphrase data.  If absent, ``length`` defaults
  to ``24``.
* ``description`` is optional.

The ``encrypted`` key will be added to the PKICatalog schema, and adds the same
semantics to PKICatalog-based generation as are described above for
PassphraseCatalog.

Pegleg CLI Changes
------------------

The Pegleg CLI interface will be extended as follows.  These
commands will create PeglegManagedDocument manifests in the local repository.
Committing and pushing the changes will be left to the
operator or to script-based automation.

For the CLI commands below which encrypt or decrypt secrets, an environment
variable (e.g. ``$PEGLEG_KEY`` will be use to capture the key/passphrase to use.
``pegleg site secrets rotate`` will use a second variable
(e.g. ``$PEGLEG_PREVIOUS_KEY``) to hold the key/passphrase being rotated
out.

``pegleg site secrets generate passphrases``:  Generate passphrases according to
all PassphraseCatalog documents in the site.
Note that regenerating passphrases can be accomplished
simply by re-running ``pegleg site secrets generate passphrases``.

``pegleg site secrets generate pki``:  Generate certificates and keys according
to all PKICatalog documents in the site.
Note that regenerating certificates can be accomplished
simply by re-running ``pegleg site secrets generate pki``.

``pegleg site secrets generate``:  Combines the two commands above.
May be expanded in the future to include other manifest generation activities.

``pegleg site bootstrap``: For now, a synonym for
``pegleg site secrets generate``,
and may be expanded in the future to include other bootstrapping activities.

``pegleg site secrets encrypt``:  Encrypt all site documents which have
``metadata.storagePolicy: encrypted``, and which are not already encrypted
within a wrapping PeglegManagedDocument.  Note that the
``pegleg site secrets generate`` commands encrypt generated secrets as
specified, so ``pegleg site secrets encrypt`` is intended mainly for
external-facing secrets which a deployment engineer brings to the site
manifests.
The output PeglegManagedDocument will be written back to the filename that
served as its source.

``pegleg site secrets decrypt <document YAML file>``: Decrypt a specific
PeglegManagedDocument manifest, unwrapping it and outputting the cleartext
original document YAML to standard output.  This is intended to be used when
an authorized deployment engineer needs to determine a particular cleartext
secret for a specific operational purpose.

``pegleg site secrets rotate``:  This action re-encrypts encrypted secrets
with a new key/passphrase, and it takes the previously-used key and a new
key as input.  It accomplishes its task via two activities:

* For encrypted secrets that were imported from outside of Pegleg
  (i.e. PeglegManagedDocuments which lack the ``generated`` stanza),
  decrypt them with the old key (in-memory), re-encrypt them with
  the new key, and output the results.
* Perform a fresh ``pegleg site secrets generate`` process using the new key.
  This will replace all ``generated`` secrets with new secret values
  for added security.  There is an assumption here that the only actors
  that need to know generated secrets are the services within the
  Airship-managed cluster, not external services or deployment engineers,
  except perhaps for point-in-time troubleshooting or operational
  exercises.

Driving deployment of a site directly via Pegleg is follow-on functionality
which will
collect site documents, use them to create the ``genesis.sh`` script, and then
interact directly with Shipyard to drive deployments.  Its details are beyond
the scope of this spec, but when implemented, it should decrypt documents
wrapped by applicable PeglegManagedDocuments at the lst responsible moment,
and take care not to write, log, or stdout them to disk as cleartext.

Note that existing ``pegleg collect`` functionality should **not** be changed
to decrypt encrypted secrets; this is because it writes its output to disk.
If ``pegleg collect`` is called, at this point in time, the
PeglegManagedDocuments will be written (encrypted) to disk.
To enable special case full site secret decryption, a ``--force-decrypt`` flag
will be added to ``pegleg collect`` to do this under controlled circumstances,
and to help bridge the gap with existing CICD pipelines until Pegleg-driven
site deployment is in place.  It will leverage the ``$PEGLEG_KEY``
variable described above.

Secret Generation
-----------------

The ``rstr`` library should be invoked to generate secrets of the
appropriate length and character set.
This library uses the ``os.urandom()`` function,
which in turn leverages ``/dev/urandom`` on Linux,
and it is suitable for cryptographic purposes.

Characters in generated secrets will be evenly distributed across lower-
and upper-case letters, digits, and punctuation in
!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~.  Note this is equivalent to the union of
Python string.ascii_letters, string.digits, and string.punctuation.

Secret Encryption
-----------------

Details around encryption will be defined in a follow-on patch set to this spec.

Security impact
===============

These changes will result in a system that handles site secrets in a highly
secure manner, in the face of multiple roles and day 2 operational needs.

Performance impact
==================

Performance impact to existing flows will be minimal.  Pegleg will need to
additionally decrypt secrets as part of site deployment, but this will be
an efficient operation performed once per deployment.

Alternatives
============

The Python ``secrets`` library presents a convenient interface for generating
random strings.  However, it was introduced in Python 3.6, and it would be
limiting to introduce this constraint on Airship CICD pipelines.

The ``strgen`` library presents an even more convenient interface for
generating pseudo-random strings; however, it leverages the Python ``random``
library, which is unsuitably random for cryptographic purposes.

Deckhand already supports a ``storagePolicy`` element which indicates whether
whether Deckhand will persist document data in an encrypted state, and this
flag could have been re-used by Pegleg to indicate whether a secret is
(or should be) encrypted.  However, "should this data be encrypted" is a
fundamentally different question than "is this data encrypted now", and
additional metadata-esque parameters (``generated``, ``generatedLength``)
were desired as well, so this proposal adds ``data.encrypted`` to indicate
the point-in-time encryption status.  ``storagePolicy`` is still valuable
in this context to make sure everything that *should* be encrypted *is*,
prior to performing actions with it (e.g. Git commits).

This proposed implementation writes the output of generation/encryption events
back to the same source files from which the original data came.  This is a
destructive operation; however, it wasn't evident that it is problematic in
any anticipated workflow.  In addition, it sidesteps challenges around
naming of generated files, and cleanup of original files.

Implementation
==============

Please refer to the `Storyboard Story`_ for implementation planning information.

Dependencies
============

This work should be based on the patchset to add `Git branch and revision
support`_ to Pegleg, if it is not merged by the time implementation begins.
This patchset alters the CLI interface and Git repository management code,
and basing on it will avoid future refactoring.

References
==========

.. _Storyboard Story: https://storyboard.openstack.org/#!/story/2003708
.. _Git branch and revision support: https://review.openstack.org/#/c/577886/
