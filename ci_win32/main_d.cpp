// SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
// Standalone main for the D-chain MSVC build (--cc --exe generates no main).
// Standard Verilator model harness skeleton (same shape as upstream examples).
#include "Vtb_rand_combos.h"
#include "verilated.h"
#include <memory>

int main(int argc, char** argv, char**) {
    const std::unique_ptr<VerilatedContext> context{new VerilatedContext};
    context->commandArgs(argc, argv);
    const std::unique_ptr<Vtb_rand_combos> top{new Vtb_rand_combos{context.get()}};
    while (!context->gotFinish()) top->eval();
    top->final();
    return 0;
}
