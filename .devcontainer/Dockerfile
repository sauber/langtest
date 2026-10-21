# Language-runtimes dev container for the langtest evaluation
FROM ubuntu:24.04

# Noninteractive apt and project timezone
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Copenhagen

# Base packages: build tools, git, Node (elm-test), JDK (scala-cli), Erlang/Elixir, Raku
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo "$TZ" > /etc/timezone && \
    apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates unzip xz-utils build-essential \
      nodejs npm openjdk-21-jdk-headless erlang elixir rakudo && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install locations and PATH for the toolchains installed below
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    GOROOT=/usr/local/go \
    DENO_INSTALL=/usr/local \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH=/usr/local/cargo/bin:/usr/local/go/bin:/root/.opencode/bin:$PATH

# Rust stable toolchain (cargo test, rustfmt, clippy)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile default --default-toolchain stable && \
    rustc --version && cargo --version

# Go toolchain (latest stable release)
RUN GO_VER=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1) && \
    curl -fsSL "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -o /tmp/go.tar.gz && \
    rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz && \
    go version

# Deno runtime (baseline implementation)
RUN curl -fsSL https://deno.land/install.sh | sh -s -- -y && \
    deno --version

# Elm compiler and elm-test runner
RUN npm install -g elm elm-test && \
    elm --version && elm-test --version

# Rakudo (Raku) prebuilt toolchain with zef, overrides the dated apt version
RUN RAKUDO_TARBALL=$(curl -fsSL https://rakudo.org/dl/rakudo/ | grep -oE 'rakudo-moar-[0-9.]+-[0-9]+-linux-x86_64-gcc\.tar\.gz' | sort -uV | tail -n1) && \
    curl -fsSL "https://rakudo.org/dl/rakudo/${RAKUDO_TARBALL}" -o /tmp/rakudo.tar.gz && \
    mkdir -p /opt/rakudo && tar -xzf /tmp/rakudo.tar.gz -C /opt/rakudo --strip-components=1 && rm /tmp/rakudo.tar.gz && \
    ln -sf /opt/rakudo/bin/* /usr/local/bin/ && \
    ln -sf /opt/rakudo/share/perl6/site/bin/zef /usr/local/bin/zef && \
    raku --version && zef --version

# Scala 3 via scala-cli (uses the system JVM from JAVA_HOME)
RUN curl -fsSL https://github.com/VirtusLab/scala-cli/releases/latest/download/scala-cli-x86_64-pc-linux.gz -o /tmp/scala-cli.gz && \
    gunzip -f /tmp/scala-cli.gz && install -m 755 /tmp/scala-cli /usr/local/bin/scala-cli && rm -f /tmp/scala-cli && \
    scala-cli version

# opencode CLI
RUN curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path && \
    /root/.opencode/bin/opencode --version

# Git configuration for the workspace mounted at /workspaces/langtest
RUN git config --global --add safe.directory /workspaces/langtest && \
    git config --global core.autocrlf input
