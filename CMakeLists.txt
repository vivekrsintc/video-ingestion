# Copyright (c) 2020 Intel Corporation.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM,OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

cmake_minimum_required(VERSION 3.12)
project(video-ingestion VERSION 1.0.0 LANGUAGES C CXX)

# Define CMake options
option(WITH_PROFILE "Compile in profiling mode" OFF)

# Globals
set(EII_COMMON_CMAKE "${CMAKE_CURRENT_SOURCE_DIR}/../common/cmake")

# Set C++ version
set(CMAKE_CXX_STANDARD 14)

# Set CFLAGS for C/C++
set(CMAKE_C_FLAGS "-fPIE -fPIC -O2 -Wall -pedantic -fstack-protector-strong -fno-strict-overflow -fno-delete-null-pointer-checks -fwrapv -D_FORTIFY_SOURCE=2")
set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS}")

# Set LDFLAGS
set(CMAKE_SHARED_LINKER_FLAGS "-z noexecstack -z relro -z now")

# Add cmake module path
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" "${EII_COMMON_CMAKE}")

#if(WITH_PROFILE)
#    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pg")
#endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(EXISTS "${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json")
    EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json
        ${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json
    )
endif()

## --- Picked required gRPC related CMake configuration taken from https://github.com/grpc/grpc/blob/master/examples/cpp/helloworld/CMakeLists.txt --- ##
# Looks for protobuf-config.cmake file installed by Protobuf's cmake installation.
set(protobuf_MODULE_COMPATIBLE TRUE)
find_package(Protobuf CONFIG REQUIRED)
message(STATUS "Using protobuf ${protobuf_VERSION}")

set(_PROTOBUF_LIBPROTOBUF protobuf::libprotobuf)
set(_REFLECTION gRPC::grpc++_reflection)
set(_PROTOBUF_PROTOC $<TARGET_FILE:protobuf::protoc>)

# Find gRPC installation
# Looks for gRPCConfig.cmake file installed by gRPC's cmake installation.
find_package(gRPC CONFIG REQUIRED)
message(STATUS "Using gRPC ${gRPC_VERSION}")

set(_GRPC_GRPCPP gRPC::grpc++)
set(_GRPC_CPP_PLUGIN_EXECUTABLE $<TARGET_FILE:gRPC::grpc_cpp_plugin>)
## --- Picked required gRPC related CMake configuration taken from https://github.com/grpc/grpc/blob/master/examples/cpp/helloworld/CMakeLists.txt --- ##

# Finding packages
find_package(OpenCV REQUIRED)
find_package(EIIMsgEnv REQUIRED)
find_package(Threads REQUIRED)
find_package(EIIUtils REQUIRED)
find_package(EIIConfigMgrStatic REQUIRED)
find_package(EIIMessageBus REQUIRED)
find_package(UDFLoader REQUIRED)
find_package(PkgConfig REQUIRED)
find_package(IntelSafeString REQUIRED)
find_package(realsense2 REQUIRED)

pkg_check_modules(GST REQUIRED
    gstreamer-1.0>=1.14
    gstreamer-video-1.0>=1.14
    gstreamer-sdp-1.0>=1.14
    gstreamer-app-1.0>=1.14)

# Include header directories
include_directories(
    include/
    ${OpenCV_INCLUDE_DIRS}
    ${EIIMsgEnv_INCLUDE}
    ${EIIUtils_INCLUDE}
    ${EIIConfigMgrStatic_INCLUDE}
    ${EIIMessageBus_INCLUDE}
    ${UDFLoader_INCLUDE}
    ${GST_INCLUDE_DIRS}
    ${IntelSafeString_INCLUDE})

# Find C++ sources
file(GLOB SOURCES "src/*.cpp")
link_directories(${CMAKE_INSTALL_PREFIX}/lib)

add_executable(video-ingestion ${SOURCES})
target_link_libraries(video-ingestion
    PUBLIC
        cjson
        ${OpenCV_LIBS}
        ${IntelSafeString_LIBRARIES}
        ${EIIMsgEnv_LIBRARIES}
        ${EIIUtils_LIBRARIES}
        ${EIIConfigMgrStatic_LIBRARIES}
        ${EIIMessageBus_LIBRARIES}
        ${UDFLoader_LIBRARIES}
        ${GST_LIBRARIES}
        ${_REFLECTION}
        ${_GRPC_GRPCPP}
        ${_PROTOBUF_LIBPROTOBUF}
        ${realsense2_LIBRARY}
    PRIVATE
        ${ZMQ_LIBRARIES})

# If compile in debug mode, set DEBUG flag for C code
if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    target_compile_definitions(video-ingestion PRIVATE DEBUG=1)
endif()

if(WITH_PROFILE)
    target_compile_definitions(video-ingestion PRIVATE WITH_PROFILE=1)
endif()
