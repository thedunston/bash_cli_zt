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

This is not that modular and needs some code cleanup.  I'll make things more modular as I have time to work on it. It works for how I use it and I'll upgrade as I use more features or if folks have requests.

I teach full-time and working on a degree so will work on this as I have time.  I hope it helps someone and folks contribute code.

-duane

thedunston@gmail.com

