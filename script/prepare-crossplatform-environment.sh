#!/bin/bash

###############################################################################

CROSSPLATFORM_CMAKE_SYSROOT="/usr/aarch64-redhat-linux/sys-root/fc41" # change this to folder on your linux

APPLICATION_FOLDER="OPi3_HelloWorld"
CMAKE_PROJECT_NAME="OPi3_HelloWorld"
CMAKE_PROJECT_BINARY_NAME="hello_opi3"

USER_ACCOUNT="orangepi"          # e.g., 'pi', 'root', or your custom user
USER_IP_ADDRESS="192.168.1.1"    # change this to your opi3 ip address
USER_PASSWORD="orangepi"         # change this to your opi3 password

HOST_TO_PING="n.n.n.n"           # address to send the ping to
DELAY_TO_PING="60"               # seconds to sleep till the next ping
TIMES_TO_PING="3"                # number times to send the ping

###############################################################################

DO_INSTALL_PREREQUISITES=y
DO_GENERATE_FOLDERS_AND_PROGRAM_SOURCE_CODE=y
DO_GENERATE_CMAKE_SCRIPTS=y
DO_GENERATE_BUILD_SCRIPT=y
DO_BUILD_APPLICATION=Y
DO_GENERATE_DEPLOY_SCRIPT=y
DO_DEPLOY_APPLICATION=y
DO_GENERATE_LAUNCH_SCRIPT=y
DO_LAUNCH_APPLICATION=y

###############################################################################
#
#   Auxillary functions
#
###############################################################################

function print_fmt()
{
    local msg="$1"

    echo
    echo "#****************************************************************************"
    echo "#"
    echo "#  ${msg}"
    echo "#"
    echo "#****************************************************************************"
    echo
}

function print_cmd()
{
    local cmd="$1"

    echo
    echo "cmd: '${cmd}'"
    echo
}

###############################################################################
#
#   Prerequisite Check and Setup
#
###############################################################################

function install_preprequisites()
{
    if [ -z "${DO_INSTALL_PREREQUISITES}" ] ; then
        return
    fi

    print_fmt "Installing Prerequisites ..."

    # Check your Fedora version/repository names might vary slightly

    # This provides the 'gcc-aarch64-linux-gnu.x86_64' compiler
    local cmd_gcc="sudo dnf install gcc-aarch64-linux-gnu.x86_64"
    print_cmd "${cmd_gcc}"

    ${cmd_gcc}

    local cmd_sysroot="sudo dnf install sysroot-aarch64-fc41-glibc.noarch"
    print_cmd "${cmd_sysroot}"

    ${cmd_sysroot}

    # Install CMake
    local cmd_cmake="sudo dnf install cmake"
    print_cmd "${cmd_cmake}"

    ${cmd_cmake}

    # Install Secure Copy Protocol
    local cmd_scp="sudo dnf install scp"
    print_cmd "${cmd_scp}"

    ${cmd_scp}

    print_fmt "Installing Prerequisites done."
}

###############################################################################
#
#   Project Structure and Source Code
#
###############################################################################

function generate_folders_and_program_source_code()
{
    if [ -z "${DO_GENERATE_FOLDERS_AND_PROGRAM_SOURCE_CODE}" ] ; then
        return
    fi

    print_fmt "Preparing project structure and the source code ..."

    (

        local cmd_mkdir="mkdir -p ${APPLICATION_FOLDER}/src && mkdir -p ${APPLICATION_FOLDER}/cmake"
        print_cmd "${cmd_mkdir}"

        eval "${cmd_mkdir}"

        cd ${APPLICATION_FOLDER} || { echo "failed changing folder to '${APPLICATION_FOLDER}'"; exit 1; }

        cat << FEOF > src/main.c
#include <stdio.h>
#include <unistd.h> // For getpid()
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * @brief Checks host reachability using the system's ping utility.
 * * Executes the command: ping -c 1 -W 2 <hostname>
 * -c 1: Send only 1 packet.
 * -W 2: Wait a maximum of 2 seconds for a response.
 * The output is redirected to /dev/null to keep the console clean.
 * * @param hostname The host to ping (e.g., "example.org").
 * @return 0 if the host is reachable (ping succeeded),
 * 1 if the host is unreachable (ping failed or timed out),
 * -1 if the system() call failed.
 */
int check_host_reachability(const char *hostname) {
    // Construct the command string: ping -c 1 -W 2 <hostname> > /dev/null 2>&1
    char command[256];
    // Snprintf for safe string formatting
    if (snprintf(command, sizeof(command), "ping -c 1 -W 2 %s > /dev/null 2>&1", hostname) >= sizeof(command)) {
        fprintf(stderr, "Error: Hostname too long.\n");
        return -1;
    }

    printf("Pinging host: %s...\n", hostname);

    // Execute the ping command and capture the return status
    int status = system(command);

    if (status == -1) {
        // system() failed to execute the shell command
        perror("Error executing ping command via system()");
        return -1;
    }

    // The system() function returns the exit status of the command
    // *left-shifted by eight bits*, or 0 if successful, or -1 on error.
    // WEXITSTATUS macro extracts the lower 8 bits of the child's exit status.
    int exit_code = WEXITSTATUS(status);

    // In Linux:
    // ping exit code 0: Success (host is reachable)
    // ping exit code 1: No reply (host is unreachable/timed out)
    // ping exit code 2: Other errors (e.g., bad hostname)

    if (exit_code == 0) {
        return 0; // Host is reachable
    } else if (exit_code == 1) {
        return 1; // Host is unreachable/timed out
    } else {
        // Other error (e.g., DNS resolution failed, exit code 2)
        fprintf(stderr, "Ping command exited with status %d (Possible DNS error or other issue).\n", exit_code);
        return 1;
    }
}

int main(int argc, char *argv[]) {
    const char *host_name;
    int interval_sec;
    int repeat_count;
    int i;

    // --- 1. Argument Validation ---
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <host_name> <interval_seconds> <repeat_count>\n", argv[0]);
        return EXIT_FAILURE;
    }

    host_name = argv[1];

    // Convert and validate interval
    if (sscanf(argv[2], "%d", &interval_sec) != 1 || interval_sec <= 0) {
        fprintf(stderr, "Error: Invalid interval time (must be a positive integer).\n");
        return EXIT_FAILURE;
    }

    // Convert and validate repeat count
    if (sscanf(argv[3], "%d", &repeat_count) != 1 || repeat_count < 1) {
        fprintf(stderr, "Error: Invalid repeat count (must be an integer >= 1).\n");
        return EXIT_FAILURE;
    }

    printf("Hello from the Orange Pi Zero 3!\n");
    printf("This application was built using a cross-toolchain on Fedora.\n");
    printf("Process ID (PID): %d\n", getpid());

    const char *target_host = host_name;

    printf("--- Ping Checker Started ---\n");
    printf("Host: %s, Interval: %d seconds, Repetitions: %d\n", host_name, interval_sec, repeat_count);
    printf("----------------------------\n");

    // --- 2. Main Check Cycle ---
    for (i = 1; i <= repeat_count; i++) {
        printf("\n--- Cycle %d/%d ---\n", i, repeat_count);

        int result = check_host_reachability(target_host);

        if (result == 0) {
           printf("Result: **%s is REACHABLE.**\n", target_host);
        } else if (result == 1) {
           printf("Result: **%s is UNREACHABLE or TIMED OUT.**\n", target_host);
        } else {
           printf("Result: **An error occurred during the check.**\n");
        }

        // Only sleep if it's not the last cycle
        if (i < repeat_count) {
            printf("Waiting for %d seconds...\n", interval_sec);
            // Sleep for the specified interval
            if (sleep(interval_sec) != 0) {
                // sleep returns remaining seconds if interrupted by a signal
                fprintf(stderr, "Sleep was interrupted, proceeding to next check.\n");
            }
        }
    }

    return 0;
}
FEOF

    ) || { echo "failed to prepare project structure and the source code"; exit 1; }

    print_fmt "Preparing project structure and the source code done."
}


###############################################################################
#
#   CMake Build System Configuration
#
###############################################################################

function generate_cmake_scripts()
{
    if [ -z "${DO_GENERATE_CMAKE_SCRIPTS}" ] ; then
        return
    fi

    print_fmt "Generating CMake script ..."

    (

        cd ${APPLICATION_FOLDER} || { echo "failed changing folder to '${APPLICATION_FOLDER}'"; exit 1; }

        cat << FEOF > cmake/aarch64-toolchain.cmake
# This file is the Toolchain file for cross-compiling to AArch64 (Orange Pi Zero 3)

# Define the target system and architecture
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Set the location of the cross-compiler
# Use the full prefix installed by dnf (aarch64-linux-gnu-)
set(TOOLCHAIN_PREFIX aarch64-linux-gnu-)

# Specify the compilers
set(CMAKE_C_COMPILER   \${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_CXX_COMPILER \${TOOLCHAIN_PREFIX}g++) # Not strictly needed for C, but good practice

# Define paths for system root (sysroot) if needed for external libs,
# but for a simple static build, we can often rely on the default toolchain libs.
set(CMAKE_SYSROOT "${CROSSPLATFORM_CMAKE_SYSROOT}")

# Programs (like 'strip', 'gdb') should be searched ONLY on the HOST.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# Libraries and Headers should be searched ONLY within the SYSROOT.
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
FEOF

    cat << FEOF > CMakeLists.txt
# Minimum version requirement
cmake_minimum_required(VERSION 3.10)

# Project definition
project(${CMAKE_PROJECT_NAME} C)

# Set the output directory for the final executable
set(EXECUTABLE_OUTPUT_PATH \${PROJECT_SOURCE_DIR}/bin)

# Add the executable target
add_executable(${CMAKE_PROJECT_BINARY_NAME} src/main.c)

# Optional: Set RPATH to ensure the loader finds libraries on the target system
# This is usually only needed for shared libraries, but good to know
# set_target_properties(${CMAKE_PROJECT_BINARY_NAME} PROPERTIES
#     INSTALL_RPATH "\$ORIGIN/../lib"
# )

# Optional: Print the compiler being used for verification during the build
message(STATUS "Using C Compiler: \${CMAKE_C_COMPILER}")
FEOF

    ) || { echo "failed to generate CMake script"; exit 1; }

    print_fmt "Generating CMake script done."
}

###############################################################################
#
#   Build Automation Script
#
###############################################################################

function generate_build_script()
{
    if [ -z "${DO_GENERATE_BUILD_SCRIPT}" ] ; then
        return
    fi

    print_fmt "Generating Automation Build script ..."

    (

        cd ${APPLICATION_FOLDER} || { echo "failed changing folder to '${APPLICATION_FOLDER}'"; exit 1; }

        cat << FEOF > build.sh
#!/bin/bash
# Script to configure and build the cross-compiled application

# --- Configuration ---
BUILD_DIR="build"
TOOLCHAIN_FILE="cmake/aarch64-toolchain.cmake"
EXECUTABLE_NAME="${CMAKE_PROJECT_BINARY_NAME}"

# --- Setup ---
echo "Cleaning previous build..."
rm -rf \${BUILD_DIR}
mkdir -p \${BUILD_DIR}

# --- CMake Configure ---
echo "Configuring CMake for AArch64 cross-compilation..."
cmake \
    -S . \
    -B \${BUILD_DIR} \
    -DCMAKE_TOOLCHAIN_FILE="\${TOOLCHAIN_FILE}" \
    -DCMAKE_BUILD_TYPE=Release || { echo "CMake configuration failed!"; exit 1; }

# --- Build ---
echo "Building the application..."
cmake --build \${BUILD_DIR} -j\$(nproc) || { echo "Build failed!"; exit 1; }

# --- Verification ---
echo "--- Build successful! ---"
echo "Verifying executable architecture..."
file bin/\${EXECUTABLE_NAME}
FEOF
    ) || { echo "failed to generate Automation Build script"; exit 1; }

    print_fmt "Generating Automation Build script done."
}

###############################################################################
#
#   Execution and Verification on Host
#
###############################################################################

function build_application()
{
    if [ -z "${DO_BUILD_APPLICATION}" ] ; then
        return
    fi

    print_fmt "Building the Application ..."

# The key is the output showing ARM aarch64, confirming it was correctly cross-compiled.
# The final executable is located at bin/${CMAKE_PROJECT_BINARY_NAME}.

    (

        cd ${APPLICATION_FOLDER} || { echo "failed changing folder to '${APPLICATION_FOLDER}'"; exit 1; }

        local cmd="chmod +x build.sh && ./build.sh"
        print_cmd "${cmd}"

        eval "${cmd}"

    ) || { echo "application building failed!"; exit 1; }

    print_fmt "Building the Application done."
}

###############################################################################
#
#   Generate Deployment to Target System (Orange Pi Zero 3) Script
#
###############################################################################

function generate_deploy_script()
{
    if [ -z "${DO_GENERATE_DEPLOY_SCRIPT}" ] ; then
        return
    fi

    print_fmt "Generating Deploy script ..."

    (

        cd ${APPLICATION_FOLDER} || { echo "failed changing folder to '${APPLICATION_FOLDER}'"; exit 1; }

        cat << FEOF > deploy.sh
#!/bin/bash
# Script to deploy the application to the Orange Pi Zero 3

# --- Configuration ---
TARGET_USER="${USER_ACCOUNT}"
TARGET_IP="${USER_IP_ADDRESS}"
TARGET_PASSWORD="${USER_PASSWORD}"
TARGET_PATH="/home/\${TARGET_USER}/app"
EXECUTABLE_NAME="${CMAKE_PROJECT_BINARY_NAME}"
SOURCE_FILE="bin/\${EXECUTABLE_NAME}"

# --- Check for executable ---
if [ ! -f "\${SOURCE_FILE}" ]; then
    echo "Error: Executable \${SOURCE_FILE} not found. Did you run ./build.sh?"
    exit 1
fi

# --- Deployment ---
echo "Creating target directory on OPI3: \${TARGET_USER}@\${TARGET_IP}:\${TARGET_PATH}"
echo "Hint: \"\${TARGET_PASSWORD}\""
ssh \${TARGET_USER}@\${TARGET_IP} "mkdir -p \${TARGET_PATH}"

echo "Deploying \${EXECUTABLE_NAME} to OPI3..."
echo "Hint: \"\${TARGET_PASSWORD}\""
scp "\${SOURCE_FILE}" "\${TARGET_USER}@\${TARGET_IP}:\${TARGET_PATH}/" || { echo "SCP failed!"; exit 1; }

echo "--- Deployment successful! ---"
echo "Next step: Log in and run the application:"
echo "Hint: \"\${TARGET_PASSWORD}\""
echo "ssh \${TARGET_USER}@\${TARGET_IP}"
echo "\${TARGET_PATH}/\${EXECUTABLE_NAME}"
FEOF

# Note: The first time you connect, SSH/SCP will ask you to confirm the host's fingerprint.

    ) || { echo "failed to generate Deploy script"; exit 1; }

    print_fmt "Generating Deploy script done."
}

###############################################################################
#
#   Deployment to Target System (Orange Pi Zero 3)
#
###############################################################################

function deploy_application()
{
    if [ -z "${DO_DEPLOY_APPLICATION}" ] ; then
        return
    fi

    print_fmt "Deploying the Application ..."

    (

        cd ${APPLICATION_FOLDER} || { echo "failed changing folder to '${APPLICATION_FOLDER}'"; exit 1; }

        local cmd="chmod +x deploy.sh && ./deploy.sh"
        print_cmd "${cmd}"

        eval "${cmd}"

    ) || { echo "application deployment failed!"; exit 1; }

    print_fmt "Deploying the Application done."
}

###############################################################################
#
#   Generate Execution on Target System (Orange Pi Zero 3) Script
#
###############################################################################

function generate_launch_script()
{
    if [ -z "${DO_GENERATE_LAUNCH_SCRIPT}" ] ; then
        return
    fi

    print_fmt "Generating Launch script ..."

    (

        cd ${APPLICATION_FOLDER} || { echo "failed changing folder to '${APPLICATION_FOLDER}'"; exit 1; }

        cat << FEOF > launch.sh

    echo "Connect to the OPI3 to Run the Executable:"
    echo "Hint: \"${USER_PASSWORD}\""
    echo "Hint: \"cd /home/${USER_ACCOUNT}/app && ./${CMAKE_PROJECT_BINARY_NAME}\""
    echo "Hint: \"cd /home/${USER_ACCOUNT}/app && ./${CMAKE_PROJECT_BINARY_NAME} ${HOST_TO_PING} ${DELAY_TO_PING} ${TIMES_TO_PING}\""
    ssh ${USER_ACCOUNT}@${USER_IP_ADDRESS}
FEOF

   ) || { echo "failed to generate Launch script"; exit 1; }

    print_fmt "Generating Launch script done."

}

###############################################################################
#
#   Execution on Target System (Orange Pi Zero 3)
#
###############################################################################

function launch_application()
{
    if [ -z "${DO_LAUNCH_APPLICATION}" ] ; then
        return
    fi

    print_fmt "Launching the Application ..."

    (

        cd ${APPLICATION_FOLDER} || { echo "failed changing folder to '${APPLICATION_FOLDER}'"; exit 1; }

        local cmd="chmod +x launch.sh && ./launch.sh"
        print_cmd "${cmd}"

        eval "${cmd}"

    ) || { echo "application running failed!"; exit 1; }

    print_fmt "Launching the Application done."

}

###############################################################################
#
#   MAIN
#
###############################################################################

function main()
{
    install_preprequisites
    generate_folders_and_program_source_code
    generate_cmake_scripts
    generate_build_script
    build_application
    generate_deploy_script
    deploy_application
    generate_launch_script
    launch_application
}

###############################################################################

main
