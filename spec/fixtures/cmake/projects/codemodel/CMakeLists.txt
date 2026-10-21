# The codemodel reports target "fileSets" from version 2.3, so the fixture needs a recent CMake.
cmake_minimum_required(VERSION 3.28)
project(CodemodelExample LANGUAGES CXX)

# A configured file, which the codemodel reports as a generated source.
configure_file(config.hpp.in config.hpp @ONLY)
source_group("Generated" FILES ${CMAKE_CURRENT_BINARY_DIR}/config.hpp)

# An imported target from a find_package, which the codemodel reports in "abstractTargets".
find_package(Threads REQUIRED)

# An interface library with a header file set, which the codemodel reports without artifacts.
add_library(codemodel_example_headers INTERFACE)
target_sources(
    codemodel_example_headers
    INTERFACE
        FILE_SET codemodel_example_headers
            TYPE HEADERS
            BASE_DIRS include
            FILES include/codemodel_example/version.hpp
)
target_compile_features(codemodel_example_headers INTERFACE cxx_std_20)
target_link_libraries(codemodel_example_headers INTERFACE Threads::Threads)

# A utility target, which the codemodel reports without artifacts and with a folder.
add_custom_target(
    generate_config
    COMMAND
        ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_BINARY_DIR}/config.hpp
        config.hpp.copy
)
set_target_properties(generate_config PROPERTIES FOLDER "Helpers")

add_executable(cmakeseer_example main.cpp)
target_link_libraries(
    cmakeseer_example
    PRIVATE codemodel_example_headers codemodel_math
)
target_compile_features(cmakeseer_example PRIVATE cxx_std_20)
set_target_properties(
    cmakeseer_example
    PROPERTIES CXX_STANDARD 20 CXX_STANDARD_REQUIRED ON
)
target_include_directories(
    cmakeseer_example
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include
)
install(TARGETS cmakeseer_example RUNTIME DESTINATION bin)

add_subdirectory(math)
add_subdirectory(nested)
