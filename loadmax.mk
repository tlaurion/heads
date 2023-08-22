# This makefile calculates the load max on a Linux system and passes it as an argument to make
# It works for both standard hosts and CircleCI, testing for cgroups 1 and 2 and testing for file presence

# Define a variable to store the cgroup availability
CGROUP := $(shell test -d /sys/fs/cgroup && echo -n yes)
# print if cgroup is available
$(info cgroup is $(CGROUP))

# Define a variable to store the cgroup version
CGROUP_V2 := $(shell test -d /sys/fs/cgroup/unified && echo -n yes)
# print if cgroup v2 is available
$(info cgroup v2 is $(CGROUP_V2))

# Define a variable to store the number of CPUs
NPROC := $(shell if [ -f /proc/cpuinfo ]; then grep -c ^processor /proc/cpuinfo; else nproc; fi)
# print the number of CPUs
$(info nproc is $(NPROC))

# Define a variable to store the amount of memory in GB
MEM := $(shell if [ "$(CGROUP)" = "yes" ]; then if [ "$(CGROUP_V2)" = "yes" ]; then if [ -f /sys/fs/cgroup/unified/memory.max ]; then cat /sys/fs/cgroup/unified/memory.max | awk '{print $$1 / 1073741824}'; else free -g | grep Mem | awk '{print $$2}'; fi; else if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then cat /sys/fs/cgroup/memory/memory.limit_in_bytes | awk '{print $$1 / 1073741824}'; else free -g | grep Mem | awk '{print $$2}'; fi; fi; else free -g | grep Mem | awk '{print $$2}'; fi)
# print the amount of memory
$(info mem is $(MEM))

# Define a variable to store the dynamic factor
FACTOR := $(shell awk 'BEGIN {factor = $(MEM) / $(NPROC); if (factor < 0.5) factor = 0.5; if (factor > 1) factor = 1; print factor}')
# print the dynamic factor
$(info factor is $(FACTOR))

# Define a variable to store the load max
LOAD_MAX ?= $(shell awk 'BEGIN {print $(NPROC) * $(FACTOR)}')
# print the load max
$(info load max is $(LOAD_MAX))

# Pass the load max as an argument to make
MAKEFLAGS += -l $(LOAD_MAX)
