# Setup User Containers for LXC (for Debian/Ubuntu based systems)

If you've used LXC for quick test machines, or any other purpose, this will
allow you to run them without being root.

I've tested it on Ubutnu 20.04 - 22.04, and on Debian 11, but YMMV.  I
figured this might be helpful for someone!

Usage:-
Run the script as the user you wish to have ability to use LXC containers, it will configure LXC as needed, and assign a range of high UID's to that user so that they can fully own at least 16 bits of UID namespace.
