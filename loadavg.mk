# This makefile calculates the load average on a Linux system and passes it as an argument to make
# It works for both standard hosts and CircleCI, testing for cgroups 1 and 2 and testing for file presence

# Define a variable to store the cgroup availability
CGROUP := $(shell test -d /sys/fs/cgroup && echo -n yes)

# Define a variable to store the cgroup version
CGROUP_V2 := $(shell test -d /sys/fs/cgroup/unified && echo -n yes)

# Define a variable to store the number of CPUs
NPROC := $(shell if [ -f /proc/cpuinfo ]; then grep -c ^processor /proc/cpuinfo; else nproc; fi)

# Define a variable to store the amount of memory in GB
MEM := $(shell if [ -f /proc/meminfo ]; then awk '/MemTotal/ {print $$2 / 1048576}' /proc/meminfo; else free -g | grep Mem | awk '{print $$2}'; fi)

# Define a variable to store the load average from /proc/loadavg or /sys/fs/cgroup/cpuset/cpuset.loadavg
LOADAVG := $(shell if [ -f /proc/loadavg ]; then cut -f1 -d" " /proc/loadavg; elif [ -f /sys/fs/cgroup/cpuset/cpuset.loadavg ]; then cut -f1 -d" " /sys/fs/cgroup/cpuset/cpuset.loadavg; else echo 0; fi)

# Define a variable to store the load average threshold
LOAD_LIMIT ?= $(shell if [ "$(CGROUP)" = "yes" ]; then if [ "$(CGROUP_V2)" = "yes" ]; then awk 'BEGIN {print $(NPROC) * $(MEM) * 0.75}'; else awk 'BEGIN {print $(NPROC) * $(MEM) * 0.75}'; fi; else awk 'BEGIN {print $(NPROC) * $(MEM) * 0.75}'; fi)

# Print the load limit to the screen
$(info The load limit is $(LOAD_LIMIT))

# Pass the load average threshold as an argument to make
MAKEFLAGS += -l $(LOAD_LIMIT)
