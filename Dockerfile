FROM ubuntu:24.04

LABEL description="RISC-V RV32I Educational Environment"
LABEL maintainer="neander-riscv educational project"

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# System dependencies
# Ubuntu 24.04 (noble) ships Verilator 5.x, compatible with -Wno-UNUSEDSIGNAL.
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        gcc-riscv64-unknown-elf \
        binutils-riscv64-unknown-elf \
        verilator \
        g++ \
        make \
        git \
        curl \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Sanity-check: verify that the RISC-V toolchain is present and functional.
# This layer fails the build early if the packages did not install correctly.
# ---------------------------------------------------------------------------
RUN riscv64-unknown-elf-as --version && \
    riscv64-unknown-elf-objcopy --version

WORKDIR /project

COPY . .

CMD ["bash"]
