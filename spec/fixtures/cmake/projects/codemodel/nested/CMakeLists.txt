project(NestedExample LANGUAGES CXX)

add_library(codemodel_greeting SHARED greeting.cpp greeting.hpp)
target_link_libraries(
    codemodel_greeting
    PRIVATE codemodel_math codemodel_imported_math
)
target_compile_definitions(
    codemodel_greeting
    PRIVATE CMAKESEER_GREETING_NAME="nested"
)

add_executable(codemodel_greet greet.cpp)
target_link_libraries(codemodel_greet PRIVATE codemodel_greeting)

add_library(codemodel_plugin MODULE plugin.cpp)
target_link_libraries(codemodel_plugin PRIVATE codemodel_math)
