# cmakeFiles only reports "globsDependent" from version 1.1, added in CMake 3.30.
cmake_minimum_required(VERSION 3.30)
project(Globs LANGUAGES NONE)

# A recursive glob, which CMake reports with "recurse" set and "listDirectories" omitted
file(GLOB_RECURSE CMAKESEER_RECURSIVE_GLOB CONFIGURE_DEPENDS "headers/*.hpp")

# A glob written with RELATIVE and LIST_DIRECTORIES false, which CMake reports with "relative" set
file(GLOB CMAKESEER_RELATIVE_GLOB CONFIGURE_DEPENDS RELATIVE headers LIST_DIRECTORIES false "headers/nested/*.hpp")

# A plain glob, which CMake reports with only "listDirectories" set
file(GLOB CMAKESEER_PLAIN_GLOB CONFIGURE_DEPENDS "headers/*.txt")