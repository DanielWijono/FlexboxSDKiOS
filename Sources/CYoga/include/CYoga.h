/*
 * CYoga — internal C shim for FlexboxCore.
 *
 * This target exists for one reason: to re-export Meta's Yoga C ABI under a
 * single, collision-resistant module name (`CYoga`) so that exactly one Swift
 * file in FlexboxCore (`Engine/YogaInterop.swift`) imports it. The upstream
 * Yoga SwiftPM package vends its module as `core`, which is too generic to
 * import directly across a dependency graph.
 *
 * Do not add declarations here. Only `#include <yoga/Yoga.h>`.
 */

#pragma once

#include <yoga/Yoga.h>
