cmake_minimum_required(VERSION 3.28)
project(GTestAll LANGUAGES CXX)

include(FetchContent)

# Allow a pre-downloaded googletest source tree to speed up fixture builds.
# Set CMAKESEER_GTEST_SOURCE_DIR to a checkout of googletest (the repository
# root that contains the top-level CMakeLists.txt), e.g.:
#
#   export CMAKESEER_GTEST_SOURCE_DIR="$HOME/.cache/cmakeseer/googletest"
#
# When unset, FetchContent downloads googletest from GitHub on first use.
if(DEFINED ENV{CMAKESEER_GTEST_SOURCE_DIR})
  set(FETCHCONTENT_SOURCE_DIR_GTEST $ENV{CMAKESEER_GTEST_SOURCE_DIR} CACHE PATH "" FORCE)
endif()

FetchContent_Declare(
  googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG v1.14.0
)
FetchContent_MakeAvailable(googletest)

add_executable(gtest_all
  basic_test.cpp
  fixture_test.cpp
  parameterized_test.cpp
  typed_test.cpp
  parameterized_typed_test.cpp
  nested/nested_test.cpp
)
target_link_libraries(gtest_all PRIVATE gtest gtest_main)
target_compile_features(gtest_all PRIVATE cxx_std_17)

add_executable(gtest_second
  second_test.cpp
  nested/second_nested_test.cpp
)
target_link_libraries(gtest_second PRIVATE gtest gtest_main)
target_compile_features(gtest_second PRIVATE cxx_std_17)
