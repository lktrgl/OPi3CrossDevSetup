This is a comprehensive, step-by-step manual for an embedded Linux developer to create and deploy a C application on an **Orange Pi Zero 3** board to control a **General-Purpose Input/Output (GPIO)** pin, using `gcc` and `cmake` for command-line development.

The Orange Pi Zero 3, like many modern embedded systems, uses the standard **Linux kernel GPIO interface**, specifically the **sysfs interface** (though newer systems are migrating to `libgpiod`, the sysfs method is still widely used and excellent for basic command-line demonstration). We'll target an existing GPIO, for example, **PC4**, which is a readily accessible pin on the board's header.

-----

## 🛠️ Step-by-Step Manual: GPIO Control on Orange Pi Zero 3

### Prerequisites

You'll need:

1.  **Orange Pi Zero 3** with a working Linux distribution (e.g., Armbian, Orange Pi OS).
2.  **SSH access** or a local terminal on the board.
3.  The **`gcc`** compiler and **`cmake`** build system installed on the board (or set up for cross-compilation).

### 1\. Identify the Target GPIO Pin

The Orange Pi Zero 3 uses the **Allwinner H616** SoC. GPIO pins are typically named as a **Port Letter** (A, B, C, etc.) and a **Pin Number** (0-31).

  * Let's target **PC4**.
  * **The GPIO Number Calculation:** The Linux kernel converts the Port/Pin designation into a single number:
    $$(\text{Port Letter Index} \times 32) + \text{Pin Number}$$
      * Port A Index = 0
      * Port B Index = 1
      * Port C Index = 2
      * For **PC4**: $$(2 \times 32) + 4 = 64 + 4 = 68$$
  * **Target GPIO Number: 68**

### 2\. Project Setup

We'll create a clean project structure.

| File/Directory | Purpose |
| :--- | :--- |
| `gpio_control/` | Project root directory. |
| `gpio_control/src/` | Holds source files (C code). |
| `gpio_control/src/main.c` | The C application code. |
| `gpio_control/CMakeLists.txt` | The CMake build configuration script. |
| `gpio_control/build.sh` | A convenient Bash script to automate the build. |
| `gpio_control/run.sh` | A convenient Bash script to automate deployment and execution. |

**Bash Commands for Setup:**

```bash
mkdir -p gpio_control/src
cd gpio_control
```

### 3\. Create the C Application Source File

The C application will use the standard **Linux sysfs GPIO interface** by writing to special files under `/sys/class/gpio/`.

**File:** `gpio_control/src/main.c`

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#define GPIO_PIN "68" // PC4 on Orange Pi Zero 3
#define GPIO_SYSFS_PATH "/sys/class/gpio"

// Function to write a value to a file
int write_file(const char *path, const char *value) {
    int fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("Error opening file for write");
        fprintf(stderr, "Failed to open: %s\n", path);
        return -1;
    }
    if (write(fd, value, strlen(value)) < 0) {
        perror("Error writing to file");
        close(fd);
        return -1;
    }
    close(fd);
    return 0;
}

// Function to export the GPIO pin
int gpio_export() {
    printf("Exporting GPIO %s...\n", GPIO_PIN);
    char export_path[128];
    snprintf(export_path, sizeof(export_path), "%s/export", GPIO_SYSFS_PATH);
    // Check if it's already exported before trying to export
    if (access("/sys/class/gpio/gpio68", F_OK) != 0) {
        if (write_file(export_path, GPIO_PIN) < 0) {
            fprintf(stderr, "Failed to export GPIO. Check permissions (run as root or use udev rules).\n");
            return -1;
        }
    } else {
        printf("GPIO %s already exported.\n", GPIO_PIN);
    }
    usleep(100000); // Give kernel a moment to create the sysfs directory
    return 0;
}

// Function to set the GPIO direction
int gpio_set_direction(const char *direction) {
    printf("Setting direction to %s...\n", direction);
    char direction_path[128];
    snprintf(direction_path, sizeof(direction_path), "%s/gpio%s/direction", GPIO_SYSFS_PATH, GPIO_PIN);
    return write_file(direction_path, direction);
}

// Function to set the GPIO value (High/Low)
int gpio_set_value(const char *value) {
    printf("Setting value to %s...\n", value);
    char value_path[128];
    snprintf(value_path, sizeof(value_path), "%s/gpio%s/value", GPIO_SYSFS_PATH, GPIO_PIN);
    return write_file(value_path, value);
}

// Function to unexport the GPIO pin
void gpio_unexport() {
    printf("Unexporting GPIO %s...\n", GPIO_PIN);
    char unexport_path[128];
    snprintf(unexport_path, sizeof(unexport_path), "%s/unexport", GPIO_SYSFS_PATH);
    write_file(unexport_path, GPIO_PIN);
}

int main(int argc, char *argv[]) {
    if (gpio_export() < 0) return 1;
    if (gpio_set_direction("out") < 0) return 1;

    printf("\nStarting 5-cycle blink on GPIO %s (PC4)...\n", GPIO_PIN);

    // Blink loop
    for (int i = 0; i < 5; i++) {
        // HIGH potential (write "1")
        if (gpio_set_value("1") < 0) break;
        usleep(500000); // 500ms delay

        // LOW potential (write "0")
        if (gpio_set_value("0") < 0) break;
        usleep(500000); // 500ms delay
    }

    printf("Blink finished.\n");
    gpio_unexport();

    return 0;
}
```

-----

### 4\. Create the CMake Build Script

**File:** `gpio_control/CMakeLists.txt`

```cmake
# Minimum version of CMake required
cmake_minimum_required(VERSION 3.10)

# Define the project name
project(gpio_blink C)

# Set the C standard to C99 or later
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED True)

# Define the executable target:
# 1. Target name: gpio_blink
# 2. Source file: src/main.c
add_executable(gpio_blink src/main.c)

# Optional: Set common compiler flags for optimization and warnings
target_compile_options(gpio_blink PUBLIC
    -Wall
    -Wextra
    -O2
)
```

-----

### 5\. Create the Build Script (Automation)

This script simplifies the process of configuring and compiling the project using `cmake` and `make`.

**File:** `gpio_control/build.sh`

```bash
#!/bin/bash

# Define the build directory
BUILD_DIR="build"
APP_NAME="gpio_blink"

# 1. Create and enter the build directory
echo "--- Creating and entering build directory: $BUILD_DIR ---"
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# 2. Configure the project using CMake
echo "--- Configuring project with CMake ---"
# '..' tells CMake to look for CMakeLists.txt one directory up
cmake ..

# Check if configuration was successful
if [ $? -ne 0 ]; then
    echo "!!! CMake configuration failed. Aborting build. !!!"
    exit 1
fi

# 3. Build the project using Make
echo "--- Building project with Make ---"
make

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "!!! Build failed. Aborting. !!!"
    exit 1
fi

# 4. Confirm the executable exists
if [ -f "$APP_NAME" ]; then
    echo "--- Build successful! Executable created: $PWD/$APP_NAME ---"
else
    echo "!!! Executable not found after build. Check CMakeLists.txt and C source. !!!"
    exit 1
fi

# Return to the project root
cd ..
```

-----

### 6\. Create the Run Script (Execution)

The application requires **root privileges** to export the GPIO pin to the sysfs interface. This script executes the built binary using `sudo`.

**File:** `gpio_control/run.sh`

```bash
#!/bin/bash

APP_PATH="./build/gpio_blink"

# Check if the executable exists
if [ ! -f "$APP_PATH" ]; then
    echo "!!! Executable not found at $APP_PATH. Did you run ./build.sh successfully? !!!"
    exit 1
fi

echo "--- Running GPIO Control Application (Requires sudo) ---"

# Execute the application with root privileges
# The C program handles the export, direction, value change, and unexport.
sudo $APP_PATH

# Check exit status of the application
if [ $? -ne 0 ]; then
    echo "!!! Application failed to run or exited with an error. !!!"
    echo "Ensure your kernel supports sysfs GPIO and the pin 68 (PC4) is not in use."
else
    echo "--- Application finished successfully. ---"
fi
```

-----

### 7\. Final Execution Steps on the Orange Pi Zero 3

Assuming you have transferred the entire `gpio_control` directory to the Orange Pi Zero 3 and are in the `gpio_control` directory:

1.  **Make scripts executable:**

    ```bash
    chmod +x build.sh run.sh
    ```

2.  **Build the application:**

    ```bash
    ./build.sh
    ```

      * **Explanation:** This script first creates the `build` directory. Then, `cmake ..` processes the `CMakeLists.txt` to create the platform-specific build files (Makefiles). Finally, `make` compiles `src/main.c` using `gcc` and links it to create the executable `build/gpio_blink`.

3.  **Run the application:**

    ```bash
    ./run.sh
    ```

      * **Explanation:** This script executes the binary using `sudo` to gain the necessary privileges for writing to the `/sys/class/gpio` files.
      * The C program will:
        1.  Write "68" to `/sys/class/gpio/export`.
        2.  Write "out" to `/sys/class/gpio/gpio68/direction`.
        3.  Loop 5 times, writing "1" (HIGH) and then "0" (LOW) to `/sys/class/gpio/gpio68/value`, with a 500ms delay in between.
        4.  Write "68" to `/sys/class/gpio/unexport` to clean up.

You should observe the potential change on the **PC4** pin (Header Pin 38) using a multimeter or by connecting an LED (with a current-limiting resistor) between the pin and GND.
