### Mohamed Adel Kamal, ID: 20230343 notes

#### when i tried to run the setup script for installing everything, i went into the following issues:

1- redis service does not want to run due to a dynamic linkable object file called libz.so,
one of my projects that is writen in cpp i was contributing to downloaded this library locally in usr/local/lib
and made it as a sym link instead that points to a .bak file, redis service was using this instead of the global one
which ended up making it failing and not wanting to run, i had to remove that file on my own to make it run

also had to add this folder to the redis group by running this
`sudo chown -R redis:redis /var/log/redis`
