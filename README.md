# BaBau
Automatic Local Redirection Through Tor


Simple bash script for Kali/Debian to automate tor/privoxy/iptables configuration in order to get quickly all local traffic routed through Tor.

It assumes some programs are already installed:

  - curl 
  - grep
  - iptables
  - tor
  - privoxy


There are a few variables you can change and things that can be improved.
Anyway, have fun!


UPDATE
Now your actual ip address is saved in a temporary file.

NOTE
If you want to use this script in a virtual environment, since you're in a subnet, you must remove your specific subnet from this variable at line 174:

_non_tor="127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 192.168.1.0/16"

For example if your VM has IP 192.168.0.25 simply remove 192.168.0.0/16 so you'll have:

_non_tor="127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.1.0/16"


The idea is taken from:
https://trac.torproject.org/projects/tor/wiki/doc/TransparentProxy

If you're looking for something more secure check this out:
https://trac.torproject.org/projects/tor/wiki/doc/TorifyHOWTO/IsolatingProxy
