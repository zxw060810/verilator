// SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
// Free-only TB for bad-solver degradation check (Free path does not invoke the solver)
`timescale 1ns/1ps
class Free;
  rand bit [31:0] x;
endclass
module tb_free_only;
  Free f;
  int rc;
  initial begin
    f = new();
    rc = f.randomize();
    $display("[SCEN][free] rc=%0d x=%0d %s", rc, f.x, (rc == 1) ? "PASS" : "FAIL");
    if (rc != 1) $fatal(1, "free failed");
    $display("ALL_DONE");
    $finish;
  end
endmodule
