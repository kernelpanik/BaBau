# BaBau
Automatic Local Redirection Through Tor


Simple bash script for Debian to automate tor/privoxy/iptables configuration in order to get quickly all local traffic routed through Tor.

It assumes some programs are already installed:

  - curl 
  - grep
  - iptables
  - tor
  - privoxy
  - proxychains


There are a few variables you can change.
Have fun!


The idea is taken from:
https://trac.torproject.org/projects/tor/wiki/doc/TransparentProxy

If you're looking for something more secure check this out:
https://trac.torproject.org/projects/tor/wiki/doc/TorifyHOWTO/IsolatingProxy
