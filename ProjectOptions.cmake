include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(CppApi_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(CppApi_setup_options)
  option(CppApi_ENABLE_HARDENING "Enable hardening" ON)
  option(CppApi_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    CppApi_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    CppApi_ENABLE_HARDENING
    OFF)

  CppApi_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR CppApi_PACKAGING_MAINTAINER_MODE)
    option(CppApi_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(CppApi_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(CppApi_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(CppApi_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(CppApi_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(CppApi_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(CppApi_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(CppApi_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(CppApi_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(CppApi_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(CppApi_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(CppApi_ENABLE_PCH "Enable precompiled headers" OFF)
    option(CppApi_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(CppApi_ENABLE_IPO "Enable IPO/LTO" ON)
    option(CppApi_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(CppApi_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(CppApi_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(CppApi_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(CppApi_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(CppApi_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(CppApi_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(CppApi_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(CppApi_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(CppApi_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(CppApi_ENABLE_PCH "Enable precompiled headers" OFF)
    option(CppApi_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      CppApi_ENABLE_IPO
      CppApi_WARNINGS_AS_ERRORS
      CppApi_ENABLE_USER_LINKER
      CppApi_ENABLE_SANITIZER_ADDRESS
      CppApi_ENABLE_SANITIZER_LEAK
      CppApi_ENABLE_SANITIZER_UNDEFINED
      CppApi_ENABLE_SANITIZER_THREAD
      CppApi_ENABLE_SANITIZER_MEMORY
      CppApi_ENABLE_UNITY_BUILD
      CppApi_ENABLE_CLANG_TIDY
      CppApi_ENABLE_CPPCHECK
      CppApi_ENABLE_COVERAGE
      CppApi_ENABLE_PCH
      CppApi_ENABLE_CACHE)
  endif()

  CppApi_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (CppApi_ENABLE_SANITIZER_ADDRESS OR CppApi_ENABLE_SANITIZER_THREAD OR CppApi_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(CppApi_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(CppApi_global_options)
  if(CppApi_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    CppApi_enable_ipo()
  endif()

  CppApi_supports_sanitizers()

  if(CppApi_ENABLE_HARDENING AND CppApi_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR CppApi_ENABLE_SANITIZER_UNDEFINED
       OR CppApi_ENABLE_SANITIZER_ADDRESS
       OR CppApi_ENABLE_SANITIZER_THREAD
       OR CppApi_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${CppApi_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${CppApi_ENABLE_SANITIZER_UNDEFINED}")
    CppApi_enable_hardening(CppApi_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(CppApi_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(CppApi_warnings INTERFACE)
  add_library(CppApi_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  CppApi_set_project_warnings(
    CppApi_warnings
    ${CppApi_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(CppApi_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(CppApi_options)
  endif()

  include(cmake/Sanitizers.cmake)
  CppApi_enable_sanitizers(
    CppApi_options
    ${CppApi_ENABLE_SANITIZER_ADDRESS}
    ${CppApi_ENABLE_SANITIZER_LEAK}
    ${CppApi_ENABLE_SANITIZER_UNDEFINED}
    ${CppApi_ENABLE_SANITIZER_THREAD}
    ${CppApi_ENABLE_SANITIZER_MEMORY})

  set_target_properties(CppApi_options PROPERTIES UNITY_BUILD ${CppApi_ENABLE_UNITY_BUILD})

  if(CppApi_ENABLE_PCH)
    target_precompile_headers(
      CppApi_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(CppApi_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    CppApi_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(CppApi_ENABLE_CLANG_TIDY)
    CppApi_enable_clang_tidy(CppApi_options ${CppApi_WARNINGS_AS_ERRORS})
  endif()

  if(CppApi_ENABLE_CPPCHECK)
    CppApi_enable_cppcheck(${CppApi_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(CppApi_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    CppApi_enable_coverage(CppApi_options)
  endif()

  if(CppApi_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(CppApi_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(CppApi_ENABLE_HARDENING AND NOT CppApi_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR CppApi_ENABLE_SANITIZER_UNDEFINED
       OR CppApi_ENABLE_SANITIZER_ADDRESS
       OR CppApi_ENABLE_SANITIZER_THREAD
       OR CppApi_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    CppApi_enable_hardening(CppApi_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
