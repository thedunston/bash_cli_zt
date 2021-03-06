# bash_cli_zt

Here is a project I was working on to create a ZT controller manager for some basic tasks using Bash since I tend to use the commandline a lot.

It includes:

1. Creating networks, autogenerating private networks or manual network selection.
2. Listing all networks
3. Deleting networks
4. Peer management including listing all peers, authorized peers, and unauthorized with the option to authorize a peer.
5. Deleting a peer from the ZT network is not possible so a hack I use is to set the peer to unathorized and set the IP to 127.0.0.100.  That is only used when listing members under Peer Management so those don't display in the output.
6. Editing ACLs using a format I created.  Still needs to support more rules...I just don't use many that require it.

Requirements:
- curl
- jq
- ipcalc

ipcalc is used to manage the creation of network settings, check for valid masks, etc. for the IP Pool Assignments.

jq is used to create the JSON object for most queries. I'll get around to doing it for all queries.  It is mixed because as I was learning the ZT api, I used manual queries and then started using jq the more I learned how to use it.

Usage.  You need to run this as root to access the files needed for access to your ZT Controller:

sudo bash ztnetworks.bash

Features:

- Create networks
- Update network description, IP assignments and manage routes
- Edit ACLs using custom format only for IPv4
- Manage Peers

I teach full-time and working on a degree so will work on this as I have time.  I hope it helps someone and folks contribute code.

-duane

thedunston@gmail.com
