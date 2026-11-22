FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Avoid interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive

# Configure environment paths
ENV JAVA_HOME="/usr/lib/jvm/temurin-21-jdk-amd64"
ENV ANDROID_HOME="/usr/local/android-sdk"
ENV ANDROID_SDK_ROOT="/usr/local/android-sdk"
ENV FLUTTER_HOME="/usr/local/flutter"
ENV KOTLIN_HOME="/usr/local/kotlinc"

ENV PATH="${PATH}:${JAVA_HOME}/bin:${KOTLIN_HOME}/bin:${FLUTTER_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/35.0.0"

# Install essential build tools, Linux GTK / GL requirements, and prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    gnupg \
    curl \
    wget \
    git \
    unzip \
    xz-utils \
    zip \
    adb \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    libglu1-mesa \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Eclipse Temurin OpenJDK 21 (required by Android Gradle Plugin 8.9+ and ChowGenie jvmTarget 21)
RUN mkdir -p /etc/apt/keyrings && \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb jammy main" > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && apt-get install -y temurin-21-jdk && \
    rm -rf /var/lib/apt/lists/*

# Install Kotlin Compiler CLI (v2.1.0 to match project Gradle Kotlin plugin)
RUN mkdir -p ${KOTLIN_HOME} && \
    wget -q https://github.com/JetBrains/kotlin/releases/download/v2.1.0/kotlin-compiler-2.1.0.zip -O /tmp/kotlin.zip && \
    unzip -q /tmp/kotlin.zip -d /usr/local/ && \
    rm /tmp/kotlin.zip

# Install Android SDK Command Line Tools
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

# Accept licenses and install Android SDK components (API 34 & 36, NDK 28.2.13676358 matching ChowGenie)
RUN yes | sdkmanager --sdk_root=${ANDROID_HOME} --licenses && \
    sdkmanager --sdk_root=${ANDROID_HOME} \
    "platform-tools" \
    "platforms;android-36" \
    "platforms;android-34" \
    "build-tools;35.0.0" \
    "build-tools;34.0.0" \
    "ndk;28.2.13676358"

# Install Flutter SDK (Stable Channel)
RUN git clone https://github.com/flutter/flutter.git -b stable ${FLUTTER_HOME}

# Configure permissions for the Codespaces default user (vscode)
RUN chown -R vscode:vscode ${ANDROID_HOME} ${FLUTTER_HOME} ${KOTLIN_HOME}

# Switch to non-root vscode user to configure Flutter
USER vscode

# Configure Flutter settings and precache engine artifacts
RUN flutter config --no-analytics && \
    flutter config --android-sdk ${ANDROID_HOME} && \
    flutter precache

WORKDIR /workspaces/Chow-Genie-HybridAI
