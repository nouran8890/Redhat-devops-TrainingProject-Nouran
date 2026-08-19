### Problem 1 : Podman build failed with sd-bus call: Permission denied

podman build failed at every RUN instruction and showed warnings about the systemd user session.

Investigation:

podman run worked normally.
Python and pip worked inside containers.
A minimal Containerfile reproduced the same error.
This showed that the problem was related to the Podman build environment, not the application.

#### Solution:
Created a containers.conf configuration file and configured Podman to use cgroupfs instead of the unavailable systemd user session. After that, podman build worked normally.

### Problem 2 : Container could not bind host port 8084 because the address was already in use.

Investigation: podman ps -a showed no running container using the port. ss -ltnp | grep :8084 identified host process PID 74208 listening on port 8084.

#### Solution: 
Terminated the stale host process and started the container successfully.

### Problem 3 : Frontend showed Failed to fetch

The frontend could communicate with the backend using curl, but requests failed when opened in the browser.

Investigation:

Backend containers could communicate correctly through eventhub-net.
The issue was related to how the browser was resolving the backend addresses.

#### Solution:
Tested the frontend through the browser opened from the code editor environment, where the requests resolved correctly. Verified that the frontend and backend communication worked successfully.