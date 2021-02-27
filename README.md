# bash_cli_zt

Here is a project I was working on to create a ZT controller manager for some basic tasks using Bash since I tend to use the commandline a lot.

It includes:

1. Creating networks, autogenerating private networks or manual network selection.
2. Listing all networks
3. Deleting networks
4. Peer management including listing all peers, authorized peers, and unauthorized with the option to authorize a peer.
5. Deleting a peer from the ZT network is not possible so a hack I use is to set the peer to unathorized and set the IP to 127.0.0.100.  That is only used when listing members under Peer Management so those don't display in the output.

Requirements:
- curl
- jq
- ipcalc

ipcalc is used to manage the creation of network settings, check for valid masks, etc. for the IP Pool Assignments.

jq is used to create the queries for most queries.

This is not that modular and needs some code cleanup, including more modular code but it works for my purposes.  I teach full-time and working on a degree so will work on this as I have time.  I hope it helps someone and folks contribute code.

-duane

thedunston@gmail.com
