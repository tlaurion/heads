# Start from the Debian "Bookworm" image
FROM mcr.microsoft.com/devcontainers/base:bookworm

# Install necessary packages
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    bc \
    bison \
    bridge-utils \
    build-essential \
    bzip2 \
    ccache \
    cmake \
    cpio \
    cpu-checker \
    doxygen \
    flex \
    gawk \
    gnat \
    git \
    gnupg \
    graphviz \
    iasl \
    imagemagick \
    innoextract \
    libdigest-sha-perl \
    libelf-dev \
    libguestfs-tools \
    libncurses5-dev \
    libtool \
    libudev-dev \
    libudev1 \
    libusb-1.0-0-dev \
    libvirt-clients \
    libvirt-daemon-system \
    m4 \
    nasm \
    ncurses-dev \
    patch \
    pkg-config \
    python-is-python3 \
    python3 \
    qemu-kvm \
    rsync \
    sudo \
    swtpm \
    swtpm-tools \
    texinfo \
    udev \
    uuid-dev \
    virtinst \
    wget \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

