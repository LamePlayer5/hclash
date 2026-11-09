# HClash 原生内核桥接层
# 构建产物：libhclash_core.so（NAPI 模块）
# 链接：libs/libhclash_core_rust.a（core/build-ohos.ps1 | core/build-ohos.sh 预先构建）

cmake_minimum_required(VERSION 3.5)
project(hclash_core)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

# Rust 静态库位置（可用 -DHCLASH_CORE_LIB_DIR=... 覆盖）
set(HCLASH_CORE_LIB_DIR "${NATIVERENDER_ROOT_PATH}/../../../libs" CACHE PATH "rust static lib dir")

include_directories(${NATIVERENDER_ROOT_PATH})

add_library(hclash_core SHARED
    napi_init.cpp
)

# Rust 内核静态库（clash-rs + tun 中继）
add_library(hclash_core_rust STATIC IMPORTED)
set_target_properties(hclash_core_rust PROPERTIES
    IMPORTED_LOCATION ${HCLASH_CORE_LIB_DIR}/libhclash_core_rust.a
)

target_link_libraries(hclash_core PUBLIC
    hclash_core_rust
    libace_napi.z.so
    libhilog_ndk.z.so
    libace_ndk.z.so
    # Rust std / clash-rs 依赖的系统库
    log
    m
    dl
    c++
    c++abi
)
