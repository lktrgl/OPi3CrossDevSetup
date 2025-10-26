
# OPi3CrossDevSetup
Automated Setup for Orange Pi Zero 3 Cross-platform C/C++  Development Environment Setup for Fedora Linux 41

## How to start

### Step 1: Cloning the repository
Launch the following command in the terminal window to get the repository cloned to you local machine

```bash
git clone --recurse-submodules git@github.com:lktrgl/OPi3CrossDevSetup.git \
    && cd OPi3CrossDevSetup/script \
    && chmod a+x prepare-crossplatform-environment.sh
```

### Step 2: Setting the configuration up
Open the just cloned `script/prepare-crossplatform-environment.sh` file using your favorite text editor 

```bash
vim OPi3CrossDevSetup/script/prepare-crossplatform-environment.sh
```

Then update the following Bash script variables' values that are listed below:

```bash
USER_ACCOUNT="orangepi"          # e.g., 'pi', 'root', or your custom user
USER_IP_ADDRESS="192.168.1.1"    # change this to your opi3 ip address
USER_PASSWORD="orangepi"         # change this to your opi3 account password

HOST_TO_PING="n.n.n.n"           # address to send the ping to
DELAY_TO_PING="60"               # seconds to sleep till the next ping
TIMES_TO_PING="3"                # number times to send the ping
```

_Note:_
You can skip by your choice any of the automated script pieces by cleaning values of the Bash script variables' values that are listed below:

```bash
DO_INSTALL_PREREQUISITES=y
DO_GENERATE_FOLDERS_AND_PROGRAM_SOURCE_CODE=y
DO_GENERATE_CMAKE_SCRIPTS=y
DO_GENERATE_BUILD_SCRIPT=y
DO_BUILD_APPLICATION=Y
DO_GENERATE_DEPLOY_SCRIPT=y
DO_DEPLOY_APPLICATION=y
DO_GENERATE_LAUNCH_SCRIPT=y
DO_LAUNCH_APPLICATION=y
```
Save you changes and close the `script/prepare-crossplatform-environment.sh` file

### Step 3: Launching the setup script
Make sure that you are allowing using the `sudo` with `root` privileges because the script is going to install some prerequisites packages.

The script creates the `OPi3CrossDevSetup/OPi3_HelloWorld` folder then generates the simple application in C language that is to be assembled using the CMake script.

Make sure that your Orange Pi Zero 3 is up and running at the IP address with the account credentials that you had set up during the **Step 2** of the present manual.

Launch the following command and enjoy:

```bash
cd OPi3CrossDevSetup \
    && script/prepare-crossplatform-environment.sh
```

