# Start from the Debian "Bookworm" image
FROM debian:bookworm

# Install necessary packages
RUN apt-get update && apt-get install -y \
    build-essential \
    zlib1g-dev \
    uuid-dev \
    libdigest-sha-perl \
    libelf-dev \
    bc \
    bzip2 \
    bison \
    flex \
    git \
    gnupg \
    gawk \
    iasl \
    m4 \
    nasm \
    patch \
    python3 \
    python-is-python3 \
    wget \
    gnat \
    cpio \
    ccache \
    pkg-config \
    cmake \
    libusb-1.0-0-dev \
    autoconf \
    texinfo \
    ncurses-dev \
    doxygen \
    graphviz \
    udev \
    libudev1 \
    libudev-dev \
    automake \
    libtool \
    rsync \
    innoextract \
    sudo \
    imagemagick \
    libncurses5-dev \
    swtpm \
    swtpm-tools \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virtinst \
    libguestfs-tools \
    && rm -rf /var/lib/apt/lists/*
