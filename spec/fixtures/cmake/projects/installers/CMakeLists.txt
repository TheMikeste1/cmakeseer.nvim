# The codemodel reports every installer type from version 2.5, so the fixture needs a recent CMake.
cmake_minimum_required(VERSION 3.28)
project(InstallersExample LANGUAGES CXX)

# A static library with a header file set, which the codemodel reports as install rules of the types "target",
# "fileSet", and "cxxModuleBmi".
add_library(installers_math STATIC math.cpp)
target_sources(
    installers_math
    PUBLIC FILE_SET math_headers
        TYPE HEADERS
        BASE_DIRS .
        FILES math.hpp
)
set_target_properties(installers_math PROPERTIES EXPORT_NAME installers_math)

install(
    TARGETS installers_math
    EXPORT InstallersTargets
    ARCHIVE DESTINATION lib
    FILE_SET math_headers DESTINATION include
    CXX_MODULES_BMI DESTINATION include
)

# An executable, whose runtime dependencies the codemodel reports as a runtime dependency set.
add_executable(installers_example main.cpp)
target_link_libraries(installers_example PRIVATE installers_math)

# A single file, which the codemodel reports as an install rule of the type "file".
install(FILES README.md DESTINATION share/installers COMPONENT docs)

# A file that does not exist, which the codemodel reports as an optional install rule of the type "file".
install(FILES missing.txt DESTINATION share/installers OPTIONAL)

# A whole directory, which the codemodel reports as an install rule of the type "directory".
install(DIRECTORY headers/ DESTINATION include/installers)

# The export set, which the codemodel reports as an install rule of the type "export".
install(EXPORT InstallersTargets NAMESPACE Installers:: DESTINATION lib/cmake/Installers FILE InstallersTargets.cmake)

# A script, which the codemodel reports as an install rule of the type "script".
install(SCRIPT cmake/configure.cmake)

# A script installed for every component, which the codemodel reports with "isForAllComponents" set.
install(SCRIPT cmake/configure.cmake ALL_COMPONENTS)

# Code to run at install time, which the codemodel reports as an install rule of the type "code".
install(CODE "message(STATUS \"installed by code\")")

# Code excluded from the default component, which the codemodel reports with "isExcludeFromAll" set.
install(CODE "message(STATUS \"excluded from all\")" EXCLUDE_FROM_ALL)

# An imported target with runtime artifacts, which the codemodel reports as an install rule of the type
# "importedRuntimeArtifacts".
add_library(installers_imported SHARED IMPORTED GLOBAL)
set_target_properties(
    installers_imported
    PROPERTIES
        IMPORTED_LOCATION libinstallers_imported.so
        IMPORTED_RUNTIME_ARTIFACTS_RELEASE libinstallers_imported.so.1
)
install(IMPORTED_RUNTIME_ARTIFACTS installers_imported RUNTIME DESTINATION bin)

# The runtime dependencies of the executable, which the codemodel reports as a runtime dependency set.
install(TARGETS installers_example RUNTIME_DEPENDENCY_SET installers_runtime RUNTIME DESTINATION bin)
install(RUNTIME_DEPENDENCY_SET installers_runtime DESTINATION bin)