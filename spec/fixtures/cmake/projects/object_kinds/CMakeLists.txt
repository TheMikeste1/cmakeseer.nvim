cmake_minimum_required(VERSION 3.26)
project(ObjectKinds LANGUAGES CXX)

# A simple cache variable to populate the "cache" object kind
set(MY_CUSTOM_CACHE_VAR "HelloWorld" CACHE STRING "A test variable")

# A dummy target to populate the "codemodel" structure
add_executable(mainApp main.cpp)
