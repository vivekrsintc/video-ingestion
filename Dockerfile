# Copyright (c) 2020 Intel Corporation.

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Dockerfile for VideoIngestion

ARG EIS_VERSION
ARG DOCKER_REGISTRY
FROM ${DOCKER_REGISTRY}ia_openvino_base:$EIS_VERSION as openvino
LABEL description="VideoIngestion image"

WORKDIR ${PY_WORK_DIR}
ARG EIS_UID
ARG EIS_USER_NAME
RUN useradd -r -u ${EIS_UID} -G video ${EIS_USER_NAME}

# Adding basler camera's essentials by referring it's repo's README and Removing unwanted files
RUN wget https://www.baslerweb.com/media/downloads/software/pylon_software/pylon-5.1.0.12682-x86_64.tar.gz && \
    tar xvf pylon-5.1.0.12682-x86_64.tar.gz && \
    cd pylon-5.1.0.12682-x86_64 && \
    tar -C /opt -zxf pylonSDK-5.1.0.12682-x86_64.tar.gz && \
    rm -rf pylon-5.1.0.12682-x86_64.tar.gz && \
    rm -rf pylon-5.1.0.12682-x86_64/pylonSDK-5.1.0.12682-x86_64.tar.gz

# Installing python boost dependencies
# Installing common build dependancies
RUN apt-get update && \
    apt-get install -y libboost-python-dev unzip \
    build-essential \
    autoconf make pciutils cpio libtool lsb-release \
    ca-certificates pkg-config bison flex libcurl4-gnutls-dev zlib1g-dev \
    automake

ENV PYLON_CAMEMU 1

# Build Intel(R) Media SDK
ARG MSDK_REPO=https://github.com/Intel-Media-SDK/MediaSDK/releases/download/intel-mediasdk-19.1.0/MediaStack.tar.gz

RUN wget -O - ${MSDK_REPO} | tar xz && \
    cd MediaStack && \
    cp -a opt/. /opt/ && \
    cp -a etc/. /opt/ && \
    ldconfig

ENV LIBVA_DRIVERS_PATH=/opt/intel/mediasdk/lib64
ENV LIBVA_DRIVER_NAME=iHD
ENV PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/opt/intel/mediasdk/lib64/pkgconfig
ENV GST_VAAPI_ALL_DRIVERS=1
ENV LIBRARY_PATH=/usr/lib
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/intel/mediasdk/lib64

ENV PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig

COPY basler-source-plugin ./basler-source-plugin
COPY install_basler_gstreamer_plugin.sh .
RUN chmod +x install_basler_gstreamer_plugin.sh && \
    ./install_basler_gstreamer_plugin.sh

ENV InferenceEngine_DIR=/opt/intel/dldt/inference-engine/share

ENV PYTHONPATH ${PYTHONPATH}:.

ENV DEBIAN_FRONTEND="noninteractive" \
    MFX_HOME=$MFX_HOME:"/opt/intel/mediasdk/" \
    PKG_CONFIG_PATH=$PKG_CONFIG_PATH:"/opt/intel/mediasdk" \
    LIBVA_DRIVERS_PATH=$LIBVA_DRIVERS_PATH:"/usr/lib/x86_64-linux-gnu/dri/" \
    LIBVA_DRIVER_NAME="iHD" \
    LD_RUN_PATH="/usr/lib" \
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/opt/intel/mediasdk/lib/:/opt/intel/mediasdk/share/mfx/samples:/usr/local/lib" \
    TERM="xterm" \
    GST_DEBUG="1" \
    LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libxcb-dri3.so" \
    MODELS_PATH=$MODELS_PATH:"${PY_WORK_DIR}/VideoIngestion/models/"

# Installing dependent python modules - needed by opencv
COPY vi_requirements.txt .
RUN pip3.6 install -r vi_requirements.txt && \
    rm -rf vi_requirements.txt

FROM ${DOCKER_REGISTRY}ia_common:$EIS_VERSION as common
FROM ${DOCKER_REGISTRY}ia_video_common:$EIS_VERSION as video_common

FROM openvino

WORKDIR ${GO_WORK_DIR}

COPY --from=common /usr/local/include /usr/local/include
COPY --from=common /usr/local/lib /usr/local/lib
COPY --from=common ${GO_WORK_DIR}/common/cmake ./common/cmake
COPY --from=common ${GO_WORK_DIR}/common/libs ./common/libs
COPY --from=common ${GO_WORK_DIR}/common/util ${GO_WORK_DIR}/common/util
COPY --from=common /usr/local/lib/python3.6/dist-packages/ /usr/local/lib/python3.6/dist-packages

ARG CMAKE_BUILD_TYPE
ARG RUN_TESTS

COPY --from=video_common ${GO_WORK_DIR}/common/UDFLoader ./common/libs/UDFLoader

# Build UDF loader lib
RUN /bin/bash -c "source /opt/intel/openvino/bin/setupvars.sh && \
    cd ./common/libs/UDFLoader && \
    rm -rf build && \
    mkdir build && \
    cd build && \
    cmake -DWITH_TESTS=${RUN_TESTS} -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} .. && \
    make && \
    if [ "${RUN_TESTS}" = "ON" ] ; then cd ./tests && \
    source ./source.sh && \
    ./frame-tests && \
    ./udfloader-tests && \
    cd .. ; fi && \
    make install"

COPY --from=video_common ${GO_WORK_DIR}/common/udfs/native ./common/udfs/native

# Build native UDF samples
RUN /bin/bash -c "source /opt/intel/openvino/bin/setupvars.sh && \
    cd ./common/udfs/native && \
    rm -rf build && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} .. && \
    make && \
    make install"

ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:/usr/local/lib/udfs/

# Adding project depedency modules
COPY . ./VideoIngestion/
RUN mv VideoIngestion/models . && mv VideoIngestion/test_videos .

ARG WITH_PROFILE
RUN /bin/bash -c "source /opt/intel/openvino/bin/setupvars.sh && \
    cd ./VideoIngestion && \
    rm -rf build && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DWITH_PROFILE=${WITH_PROFILE} .. && \
    make"

# Removing build dependencies
RUN apt-get remove -y wget && \
    apt-get remove -y git && \
    apt-get remove -y curl && \
    apt-get remove -y cmake && \
    apt-get autoremove -y

COPY --from=video_common ${GO_WORK_DIR}/common/udfs/python ./common/udfs/python

ENV PYTHONPATH ${PYTHONPATH}:${GO_WORK_DIR}/common/udfs/python:${GO_WORK_DIR}/common/

ENTRYPOINT ["VideoIngestion/vi_start.sh"]
