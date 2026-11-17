cmake_minimum_required(VERSION 3.10)
project(spine-conformance-reference CXX)

# Official spine-cpp runtime, from the spine-runtimes submodule of ceramic
set(SPINE_RUNTIMES "${CMAKE_CURRENT_LIST_DIR}/../../../ceramic/git/spine-runtimes" CACHE PATH "spine-runtimes repository")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

file(GLOB SPINE_SOURCES "${SPINE_RUNTIMES}/spine-cpp/src/spine/*.cpp")
add_library(spine-cpp STATIC ${SPINE_SOURCES})
target_include_directories(spine-cpp PUBLIC "${SPINE_RUNTIMES}/spine-cpp/include")

add_executable(spine-reference-dump dump.cpp)
target_link_libraries(spine-reference-dump spine-cpp)
