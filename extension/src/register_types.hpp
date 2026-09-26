#pragma once

// extension/src/register_types.hpp — GDExtension module registration
// entry points (TASK-001.03).

#include <godot_cpp/core/class_db.hpp>

void initialize_dopewars_module(godot::ModuleInitializationLevel p_level);
void uninitialize_dopewars_module(godot::ModuleInitializationLevel p_level);
