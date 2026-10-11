cmake_minimum_required(VERSION 3.26)
project(failing NONE)

# Configuring fails whenever this file exists in the binary directory, so a test can
# observe a successful reply followed by an error reply in the same build directory.
if(EXISTS "${CMAKE_BINARY_DIR}/FAIL_CONFIGURE")
    message(FATAL_ERROR "FAILED TO CONFIGURE")
endif()
