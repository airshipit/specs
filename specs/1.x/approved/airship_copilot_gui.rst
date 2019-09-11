..
  This work is licensed under a Creative Commons Attribution 3.0 Unported
  License.

  http://creativecommons.org/licenses/by/3.0/legalcode

.. index::
   single: Airship
   single: Shipyard
   single: GUI
   single: CLI
   single: API

===============
Airship Copilot
===============

Copilot is an Electron application that can interface with Airship CLIs and
REST interfaces.  This tool will wrap SSH sessions and HTTP/HTTPS calls to
Airship components.  The responses will be enhanced with a GUI (links for more
commands, color coded, formatting, etc.).

Links
=====

None

Problem description
===================

Airship can be difficult to approach as a user.  There are lots of commands to
know with lots of data to interpret.

Impacted components
===================

None.

Proposed change
===============

Create an Electron application that simplifies the experience of accessing
Airship.  The application will be 100% client side, thus no change to the
Airship components.  The application will default to use HTTP/HTTPS APIs,
but will be able to use the CLI commands when needed via an SSH connection.
All of the raw commands input and output will be available for the user to
see, with the goal of the user not needing to look at the raw input/output.

The application will start as a GUI interface to Shipyard.
  - Shipyard
    - API calls (create, commit, get, logs, etc.)
    - CLI commands (create, commit, get, logs, etc.)
    - From a list of actions drill down into logs

The GUI will create links to additional commands based off of the response.
The GUI can color code different aspects of the response and format it.  An
example would be when Shipyard returns a list of tasks, that list can be used
to create hyperlinks to drill down on that task (details, logs, etc.).

The GUI could start by looking similar to the CLI.  Where the values in the
different columns would be buttons/links to call additional commands for more
information.

::

    Name               Action                                   Lifecycle        Execution Time             Step Succ/Fail/Oth        Footnotes
    deploy_site        action/01BTP9T2WCE1PAJR2DWYXG805V        Failed           2017-09-23T02:42:12        12/1/3                    (1)
    update_site        action/01BZZKMW60DV2CJZ858QZ93HRS        Processing       2017-09-23T04:12:21        6/0/10                    (2)


Security impact
---------------

None - This will continue to use HTTP/HTTPS and SSH just like today, the only
difference is that it is wrapped in an application.

Performance impact
------------------

Minimal - Wrapping the commands in an Electron application might add a little
latency, but only on the client side.

Future plans
------------

Extend to other Airship components.  Pegleg seems like the next step, but
any componment with an exposed API/CLI.

Dependencies
============

None

References
==========

.. _Electron: https://electronjs.org/
