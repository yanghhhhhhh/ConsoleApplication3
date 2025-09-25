#!/bin/bash
set -e

# Define versions
BINUTILS_VERSION=2.27
GCC_VERSION=9.4.0
GLIBC_VERSION=2.12
LINUX_VERSION=2.6.32

# Define directories
PREFIX=/opt/toolchain
SYSROOT=$PREFIX/sysroot
TARGET=x86_64-linux-gnu
JOBS=$(nproc)

# Create directories
mkdir -p $PREFIX $SYSROOT

# Download sources
wget -nc https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz
wget -nc https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz
wget -nc https://ftp.gnu.org/gnu/glibc/glibc-$GLIBC_VERSION.tar.gz
wget -nc https://www.kernel.org/pub/linux/kernel/v2.6/linux-$LINUX_VERSION.tar.gz
wget -nc https://ftp.gnu.org/gnu/gmp/gmp-6.1.1.tar.gz
wget -nc https://ftp.gnu.org/gnu/mpfr/mpfr-4.1.0.tar.gz
wget -nc https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz

# Extract sources
tar -xf binutils-$BINUTILS_VERSION.tar.gz
tar -xf gcc-$GCC_VERSION.tar.gz
tar -xf glibc-$GLIBC_VERSION.tar.gz
tar -xf linux-$LINUX_VERSION.tar.gz
tar -xf gmp-6.1.1.tar.gz
tar -xf mpfr-4.1.0.tar.gz
tar -xf mpc-1.2.1.tar.gz

# Link GMP, MPFR, MPC into GCC
mv gmp-6.1.1 gcc-$GCC_VERSION/gmp
mv mpfr-4.1.0 gcc-$GCC_VERSION/mpfr
mv mpc-1.2.1 gcc-$GCC_VERSION/mpc

# Install kernel headers
cd linux-$LINUX_VERSION
make mrproper
make headers_check
make INSTALL_HDR_PATH=$SYSROOT/usr headers_install
cd ..

# Build binutils
mkdir -p build-binutils && cd build-binutils
../binutils-$BINUTILS_VERSION/configure --prefix=$PREFIX --target=$TARGET --disable-nls
make -j$JOBS
make install
cd ..

# Build GCC stage1
mkdir -p build-gcc-stage1 && cd build-gcc-stage1
../gcc-$GCC_VERSION/configure --prefix=$PREFIX --target=$TARGET --disable-multilib --enable-languages=c --without-headers
make all-gcc -j$JOBS
make install-gcc
cd ..

# Build glibc
mkdir -p build-glibc && cd build-glibc
../glibc-$GLIBC_VERSION/configure --prefix=/usr --host=$TARGET --build=$(uname -m)-linux-gnu --with-headers=$SYSROOT/usr/include --disable-multilib --enable-kernel=2.6.32 --disable-werror --enable-obsolete-rpc --with-binutils=$PREFIX/bin
make install-bootstrap-headers=yes install-headers cross_compiling=yes install_root=$SYSROOT -j$JOBS
cd ..

# Build libgcc
cd build-gcc-stage1
make all-target-libgcc -j$JOBS
make install-target-libgcc
cd ..

# Build full GCC
mkdir -p build-gcc-stage2 && cd build-gcc-stage2
../gcc-$GCC_VERSION/configure --prefix=$PREFIX --target=$TARGET --enable-languages=c,c++ --with-sysroot=$SYSROOT --disable-multilib
make -j$JOBS
make install
cd ..
