..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

========
Spyglass
========

Spyglass is a data extraction tool which can interface with
different input data sources to generate site manifest YAML files.
The data sources will provide all the configuration data needed
for a site deployment. These site manifest YAML files generated
by spyglass will be saved in a Git repository, from where Pegleg
can access and aggregate them. This aggregated file can then be
fed to Shipyard for site deployment / updates.

Problem description
===================

During the deployment of Airship Genesis node via Pegleg, it expects that
the deployment engineer provides all the information pertained to Genesis,
Controller & Compute nodes such as PXE IPs, VLANs pertaining to Storage
network, Kubernetes network, Storage disks, Host profiles, etc. as
manifests/YAMLs that are easily understandable by Pegleg.
Currently there exists multiple data sources and these inputs are processed
manually by deployment engineers. Considering the fact that there are
multiple sites for which we need to generate such data, the current process
is cumbersome, error-prone and time-intensive.

The solution to this problem is to automate the overall process so that
the resultant work-flow has standardized operations to handle multiple data
sources and generate site YAMLs considering site type and version.

Impacted components
===================

None.

Proposed change
===============

Proposal here is to develop a standalone stateless automation utility to
extract relevant information from a given site data source and process
it against site specific templates to generate site manifests which can
be consumed by Pegleg. The data sources could be different engineering packages
or extracted from remote external sources. One example of a remote data source
can be an API endpoint.

The application shall perform the automation in two stages. In the first stage
it shall generate a standardized intermediary YAML object after parsing extracted
information from the data source. In the second stage the intermediary YAML shall be
processed by a site processor using site specific templates to generate
site manifests.

Overall Architecture
====================

::

        +-----------+           +-------------+
        |           |           |  +-------+  |
        |           |   +------>|  |Generic|  |
    +-----------+   |   |       |  |Object |  |
    |Tugboat(Xl)| I |   |       |  +-------+  |
    |Plugin     | N |   |       |     |       |
    +-----------+ T |   |       |     |       |
        |         E |   |       |  +------+   |
   +------------+ R |   |       |  |Parser|   +------> Intermediary YAML
   |Remote Data | F |---+       |  +------+   |
   |SourcePlugin| A |           |     |       |
   +------------+ C |           |     |(Intermediary YAML)
        |         E |           |     |       |
        |           |           |     |       |
        |         H |           |     v       |
        |         A |           |  +---------+|(templates)    +------------+
        |         N |           |  |Site     |+<--------------|Repository  |
        |         D |           |  |Processor||-------------->|Adapter     |
        |         L |           |  +---------+|(Generated     +------------+
        |         E |           |      ^      | Site Manifests)
        |         R |           |  +---|-----+|
        |           |           |  |  J2     ||
        |           |           |  |Templates||
        |           |           |  +---------+|
        +-----------+           +-------------+

--

1)Interface handler: Acts as an interface to support multiple plugins like Excel,
  Remote Data Source, etc. The interface would define abstract APIs which would be overridden
  by different plugins. A plugin would implement these APIs based on the type of data source
  to collect raw site data and convert them to a generic object for further processing.
  For example: Consider the APIs connect_data_source() and get_host_profile(). For Excel plugin
  the connect_data_source API would implement file-open methods and the get_host_profile would
  extract host profile related information from the Excel file.

  In the case of a remote data source (for example an API endpoint), the API "connect_data_source"
  shall authenticate (if required) and establish a connection to the remote site and the
  "get_host_profile" API shall implement the logic to extract appropriate details over the established
  connection. In order to support future plugins, one needs to override these interface handler
  APIs and develop logic to extract site data from the corresponding data source.

2)Parser: It processes the information obtained from generic YAML object to create an
  intermediary YAML using the following inputs:
  a) Global Design Rules: Common rules for generating manifest for any kind of site.
  These rule are used for every plugin. for example: IPs to skip before considering allocation to host.
  b) Site Config Rules: These are settings specific to a particular site.
  For example http_proxy, bgp asn number, etc. It can be referred by all plugins. Sometimes these
  site specific information can also be received from plugin data sources. In such cases the
  information from plugin data sources would be used instead of the ones specified in site config rules.

3)Intermediary YAML: It holds the complete site information after getting it from interface
  handler plugin and after application of site specific rules. It maintains a common format agnostic
  of the corresponding data source used. So it act as a primary input to Site Processor for generating
  site manifests.

4)Tugboat(Excel Parser) Plugin: It uses the interface handler APIs to open and parse the Excel file to
  extract site details and create an in memory generic YAML object. This generic object is further processed
  using site specific config rules and global rules to generate an intermediary YAML. The name "Tugboat"
  here is used to identify "Excel Parser". For Excel parser the plugin shall use a Site specification file
  which defines the various location(s) of the site information items in file. The location is specified by
  mentioning rows and columns of the spreadsheet cell containing the specific site data.

5)Remote Data Source Plugin: It uses the interface handler APIs to connect to the data source and extract
  site specific information and then construct a generic in memory YAML object. This object is then parsed
  to generate an intermediary YAML. There may be situations wherein the information extracted from API
  endpoints are incomplete. In such scenarios, the missing information can be supplied from Site Config Rules.

6)Site Processor: The site processor consumes the intermediary YAML and generates site manifests
  based on corresponding site templates that are written in python Jinja2.
  For example, for template file "baremetal.yaml.j2", the site processor will generate "baremetal.yaml"
  with the information obtained from intermediary YAML and also by following the syntax present in the
  corresponding template file.

7)Site Templates(J2 templates): These define the manifest file formats for various entities like
  baremetal, network, host-profiles, etc. The site processor applies these templates to an intermediary
  YAML and generates the corresponding site manifests.
  For example: calico-ip-rules.yaml.j2 will generate calico-ip-rules.yaml when processed by the
  site processor.

8)Repository Adapter: This helps in importing site specific templates from a repository and also
  push generated site manifest YAMLs. The aim of the repository adapter shall be to abstract the
  specific repository operations and maintain an uniform interface irrespective of the type of
  repository used. It shall be possible to add newer repositories in the future without any change
  to this interface. The access to this repository can be regulated by credentials if required and
  those will be passed as parameters to the site specific config file.

9)Sample data flow: for example generating OAM network information from site manifests.

  - Raw rack information from plugin:

    ::

     vlan_network_data:
         oam:
             subnet: 12.0.0.64/26
             vlan: '1321'


  - Rules to define gateway, ip ranges from subnet:

    ::

     rule_ip_alloc_offset:
         name: ip_alloc_offset
             ip_alloc_offset:
                 default: 10
                 gateway: 1


    The above rule specify the ip offset to considered to define ip address for gateway, reserved
    and static ip ranges from the subnet pool.
    So ip range for 12.0.0.64/26 is : 12.0.0.65 ~ 12.0.0.126
    The rule "ip_alloc_offset" now helps to define additional information as follows:

    - gateway: 12.0.0.65 (the first offset as defined by the field 'gateway')
    - reserved ip ranges: 12.0.0.65 ~ 12.0.0.76 (the range is defined by adding
      "default" to start ip range)
    - static ip ranges: 12.0.0.77 ~ 12.0.0.126 (it follows the rule that we need
      to skip first 10 ip addresses as defined by "default")

  - Intermediary YAML file information generated after applying the above rules
    to the raw rack information:

  ::

       network:
            vlan_network_data:
               oam:
                network: 12.0.0.64/26
                gateway: 12.0.0.65 --------+
                reserved_start: 12.0.0.65  |
                reserved_end: 12.0.0.76    |
                routes:                    +--> Newly derived information
                 - 0.0.0.0/0               |
                static_start: 12.0.0.77    |
                static_end: 12.0.0.126 ----+
                vlan: '1321'

  --

  - J2 templates for specifying oam network data: It represents the format in
    which the site manifests will be generated with values obtained from
    Intermediary YAML

  ::

      ---
      schema: 'drydock/Network/v1'
      metadata:
        schema: 'metadata/Document/v1'
        name: oam
        layeringDefinition:
          abstract: false
          layer: 'site'
          parentSelector:
            network_role: oam
            topology: cruiser
          actions:
            - method: merge
              path: .
        storagePolicy: cleartext
      data:
        cidr: {{ data['network']['vlan_network_data']['oam']['network'] }}}
        routes:
          - subnet: {{ data['network']['vlan_network_data']['oam']['routes'] }}
            gateway: {{ data['network']['vlan_network_data']['oam']['gateway'] }}
            metric: 100
          ranges:
          - type: reserved
            start: {{ data['network']['vlan_network_data']['oam']['reserved_start'] }}
            end: {{ data['network']['vlan_network_data']['oam']['reserved_end'] }}
          - type: static
            start: {{ data['network']['vlan_network_data']['oam']['static_start'] }}
            end: {{ data['network']['vlan_network_data']['oam']['static_end'] }}
      ...

  --

  - OAM Network information in site manifests after applying intermediary YAML to J2
    templates.:

  ::

      ---
      schema: 'drydock/Network/v1'
      metadata:
        schema: 'metadata/Document/v1'
        name: oam
        layeringDefinition:
          abstract: false
          layer: 'site'
          parentSelector:
            network_role: oam
            topology: cruiser
          actions:
            - method: merge
              path: .
        storagePolicy: cleartext
      data:
        cidr: 12.0.0.64/26
        routes:
          - subnet: 0.0.0.0/0
            gateway: 12.0.0.65
            metric: 100
        ranges:
          - type: reserved
            start: 12.0.0.65
            end: 12.0.0.76
          - type: static
            start: 12.0.0.77
            end: 12.0.0.126
      ...

  --

Security impact
---------------
The impact would be limited to the use of credentials for accessing the data source, templates and
also for uploading generated manifest files.

Performance impact
------------------

None.

Alternatives
------------

No existing utilities available to transform site information automatically.

Implementation
==============

The following high-level implementation tasks are identified:
a) Interface Handler
b) Plugins (Excel and a sample Remote data source plugin)
c) Parser
d) Site Processor
e) Repository Adapter

Usage
=====
The tool will support Excel and remote data source plugin from the beginning.
The section below lists the required input files for each of the aforementioned
plugins.

* Preparation: The preparation steps differ based on selected data source.

  A. Excel Based Data Source.

     - Gather the following input files:

       1) Excel based site Engineering package. This file contains detail specification
          covering IPMI, Public IPs, Private IPs, VLAN, Site Details, etc.
       2) Excel Specification to aid parsing of the above Excel file. It contains
          details about specific rows and columns in various sheet which contain the
          necessary information to build site manifests.
       3) Site specific configuration file containing additional configuration like
          proxy, bgp information, interface names, etc.
       4) Intermediary YAML file. In this cases Site Engineering Package and Excel
          specification are not required.

  B. Remote Data Source

     - Gather the following input information:

       1) End point configuration file containing credentials to enable its access.
          Each end-point type shall have their access governed by their respective plugins
          and associated configuration file.
       2) Site specific configuration file containing additional configuration like
          proxy, bgp information, interface names, etc. These will be used if information
          extracted from remote site is insufficient.

* Program execution

  1. CLI Options:

     +-----------------------------+-----------------------------------------------------------+
     | -g, --generate_intermediary | Dump intermediary file from passed Excel and              |
     |                             | Excel spec.                                               |
     +-----------------------------+-----------------------------------------------------------+
     | -m, --generate_manifests    | Generate manifests from the generated                     |
     |                             | intermediary file.                                        |
     +-----------------------------+-----------------------------------------------------------+
     | -x, --excel PATH            | Path to engineering Excel file, to be passed              |
     |                             | with generate_intermediary. The -s option is              |
     |                             | mandatory with this option. Multiple engineering          |
     |                             | files can be used. For example: -x file1.xls -x file2.xls |
     +-----------------------------+-----------------------------------------------------------+
     | -s, --exel_spec PATH        | Path to Excel spec, to be passed with                     |
     |                             | generate_intermediary. The -x option is                   |
     |                             | mandatory along with this option.                         |
     +-----------------------------+-----------------------------------------------------------+
     | -i, --intermediary PATH     | Path to intermediary file,to be passed                    |
     |                             | with generate_manifests. The -g and -x options            |
     |                             | are not required with this option.                        |
     +-----------------------------+-----------------------------------------------------------+
     | -d, --site_config PATH      | Path to the site specific YAML file  [required]           |
     +-----------------------------+-----------------------------------------------------------+
     | -l, --loglevel INTEGER      | Loglevel NOTSET:0 ,DEBUG:10,    INFO:20,                  |
     |                             | WARNING:30, ERROR:40, CRITICAL:50  [default:20]           |
     +-----------------------------+-----------------------------------------------------------+
     | -e, --end_point_config      | File containing end-point configurations like user-name   |
     |                             | password, certificates, URL, etc.                         |
     +-----------------------------+-----------------------------------------------------------+
     | --help                      | Show this message and exit.                               |
     +-----------------------------+-----------------------------------------------------------+

  2. Example:

    1) Using Excel spec as input data source:

       Generate Intermediary: ``spyglass -g -x <DesignSpec> -s <excel spec> -d <site-config>``

       Generate Manifest & Intermediary: ``spyglass -mg -x <DesignSpec> -s <excel spec> -d <site-config>``

       Generate Manifest with Intermediary: ``spyglass -m -i <intermediary>``

    2) Using external data source as input:

       Generate Manifest and Intermediary: ``spyglass -m -g -e<end_point_config> -d <site-config>``

       Generate Manifest: ``spyglass -m  -e<end_point_config> -d <site-config>``

       .. note::

         The end_point_config shall include attributes of the external data source that are
         necessary for its access. Each external data source type shall have its own plugin to configure
         its corresponding credentials.

* Program output:

    a) Site Manifests: As an initial release, the program shall output manifest files for
       "airship-seaworthy" site. For example: baremetal, deployment, networks, pki, etc.
       Reference: https://github.com/openstack/airship-treasuremap/tree/master/site/airship-seaworthy
    b) Intermediary YAML: Containing aggregated site information generated from data sources that is
       used to generate the above site manifests.

Future Work
============
1. Schema based manifest generation instead of Jinja2 templates. It shall
   be possible to cleanly transition to this schema based generation keeping a unique
   mapping between schema and generated manifests. Currently this is managed by
   considering a mapping of j2 templates with schemas and site type.
2. UI editor for intermediary YAML


Alternatives
============
1. Schema based manifest generation instead of Jinja2 templates.
2. Develop the data source plugins as an extension to Pegleg.

Dependencies
============
1. Availability of a repository to store Jinja2 templates.
2. Availability of a repository to store generated manifests.

References
==========

None
