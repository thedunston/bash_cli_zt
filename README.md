# bash_cli_zt

Status: Actively supported. My recommendation is to start using the new program https://github.com/go_cli_zt

License: [GMU GPL v3.0](https://github.com/thedunston/bash_cli_zt/blob/main/LICENSE.md)

If you want a nice GUI progrm: zeroui- https://github.com/dec0dOS/zero-ui - has a very nice interface.  I have an instance running, but always default to the commandline so I continue using my bash scripts.  I installed UserLand on my Pixel, installed zerotier, and my bash scripts and it worked quite well.

Here are some YouTube videos I created on using ZeroTier:

- Private ZeroTier Network on the Public Internet - https://www.youtube.com/watch?v=xp2ujXe1SOU - The ZeroTier root servers are blocked so that only your Moons are used for managing your ZT nodes.
- ZeroTier Hub and Spoke - https://www.youtube.com/watch?v=Fb65bU3oyEo - Shows how to configure one of your ZT Linux gateways to allow access to other networks it can access.
- bash_cli_zt for for self-hosted controllers - https://www.youtube.com/watch?v=C2HS3cQZY5U - Shows how to use these scripts.
- bash_zt_auth - authorize a ZT client via SSH authentication - https://www.youtube.com/watch?v=7lQlmLD9KW4

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

If you receive an error that "columns" is not found, then install bsdmainutils.

Usage.  You need to run this as root to access the files needed for access to your ZT Controller:

sudo bash ztnetworks.bash

Features:

- Create networks
- Update network description, IP assignments and manage routes
- Edit ACLs using custom format only for IPv4
- Manage Peers
- Add node names and description

I teach full-time and working on my doctorate degree so will work on this as I have time.  I hope it helps someone and folks contribute code.

-duane

thedunston@gmail.com
