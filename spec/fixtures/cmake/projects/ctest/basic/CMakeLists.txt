cmake_minimum_required(VERSION 3.28)
project(CTestBasic LANGUAGES CXX)

enable_testing()

add_executable(ctest_basic ctest_basic.cpp)
add_test(NAME ctest_basic COMMAND ctest_basic)
