### Mohamed Adel Kamal, ID: 20230343 notes

#### when i tried to run the setup script for installing everything, i went into the following issues:

1- redis service does not want to run due to a dynamic linkable object file called libz.so,
one of my projects that is writen in cpp i was contributing to downloaded this library locally in usr/local/lib
and made it as a sym link instead that points to a .bak file, redis service was using this instead of the global one
which ended up making it failing and not wanting to run, i had to remove that file on my own to make it run

also had to add this folder to the redis group by running this
`sudo chown -R redis:redis /var/log/redis`


### Nouran Mahmoud Hegazy, ID: 20231220 notes

#### Problem 1 — MongoDB repository compatibility with ubuntu versions

The `setup.sh` script originally hardcoded the Ubuntu `noble` (Ubuntu 24.04) codename for the MongoDB 8.0 repository.

I use Ubuntu 22.04 (Jammy), so the hardcoded repository configuration was not suitable for my environment.

We checked the MongoDB 8.0 repository support and determined that the setup script needs to account for the Ubuntu versions supported by the project.
##### Fix

Updated `setup.sh` to detect the Ubuntu version and select the appropriate MongoDB repository codename:

* Ubuntu 22.04 → `jammy`
* Ubuntu 24.04 → `noble`
* Ubuntu 25.10 → `noble` (MongoDB does not provide a native Questing repository)

Unsupported Ubuntu versions are rejected with an error message.

##### Testing

Tested the setup script on Ubuntu 22.04.5 LTS (Jammy). The script selected the `jammy` MongoDB repository and completed successfully.