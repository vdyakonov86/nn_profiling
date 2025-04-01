FROM python:3.11

ARG DEBIAN_FRONTEND=noninteractive

# create a non-root user
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && mkdir /home/$USERNAME/.config && chown $USER_UID:$USER_GID /home/$USERNAME/.config

# set up sudo privileges
RUN apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME

# base utils
RUN apt-get install -y \
    vim \
    git \
    wget \
    curl \
    zip \
    unzip \
    python3-pip \
    x11-apps \
    # Autocomplete
    bash-completion \
    python3-argcomplete

# ===== YOLO 11 =====
# ultralytics install
# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

# Downloads to user config dir
ADD https://github.com/ultralytics/assets/releases/download/v0.0.0/Arial.ttf \
    https://github.com/ultralytics/assets/releases/download/v0.0.0/Arial.Unicode.ttf \
    /root/.config/Ultralytics/

# Install linux packages
# g++ required to build 'tflite_support' and 'lap' packages, libusb-1.0-0 required for 'tflite_support' package
RUN apt-get install -y --no-install-recommends \
    htop libgl1 libglib2.0-0 libpython3-dev gnupg g++ libusb-1.0-0 

# Create working directory
WORKDIR /ultralytics

# Copy contents and configure git
COPY ultralytics .
ADD https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.pt .

# Install pip packages
RUN pip install uv
RUN uv pip install --system -e ".[export]" --extra-index-url https://download.pytorch.org/whl/cpu --index-strategy unsafe-first-match

# Run exports to AutoInstall packages
RUN yolo export model=tmp/yolo11n.pt format=edgetpu imgsz=32
RUN yolo export model=tmp/yolo11n.pt format=ncnn imgsz=32
# Requires Python<=3.10, bug with paddlepaddle==2.5.0 https://github.com/PaddlePaddle/X2Paddle/issues/991
RUN uv pip install --system "paddlepaddle>=2.6.0" x2paddle

# Remove extra build files
RUN rm -rf tmp /root/.config/Ultralytics/persistent_cache.json

WORKDIR /

# jupyter
RUN pip install ipython ipykernel 
RUN pip install numpy torch torchvision torchsummary

# ===== END YOLO 11 =====

COPY scripts/.bashrc /home/${USERNAME}/bashrc
RUN cat /home/${USERNAME}/bashrc >> /home/${USERNAME}/.bashrc && rm /home/${USERNAME}/bashrc

# Remove folder in order to ensure to run apt-get update before installing new package 
# (without this folder 'apt-get update' will not work)
RUN rm -rf /var/lib/apt/lists/*
# switch from root to user
USER $USERNAME
# add user to video group to allow access to webcam
RUN sudo usermod --append --groups video $USERNAME

ENV LANG=en_US.UTF-8

CMD ["bash"]