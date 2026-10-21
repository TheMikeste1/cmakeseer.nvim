add_library(codemodel_math_objects OBJECT math.cpp)
set_target_properties(
    codemodel_math_objects
    PROPERTIES POSITION_INDEPENDENT_CODE ON
)

add_library(codemodel_math STATIC $<TARGET_OBJECTS:codemodel_math_objects>)
add_library(codemodel_example::codemodel_math ALIAS codemodel_math)
target_sources(
    codemodel_math
    PUBLIC FILE_SET math_headers TYPE HEADERS BASE_DIRS . FILES math.hpp
)
target_include_directories(codemodel_math PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
source_group("Math Sources" FILES math.cpp math.hpp)

# An imported target, which the codemodel reports in "abstractTargets" instead of "targets".
add_library(codemodel_imported_math STATIC IMPORTED GLOBAL)
set_target_properties(
    codemodel_imported_math
    PROPERTIES IMPORTED_LOCATION libcodemodel_imported_math.a
)

install(
    TARGETS codemodel_math
    ARCHIVE DESTINATION lib
    FILE_SET math_headers DESTINATION include
)
