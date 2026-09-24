// Bad-solver degradation TB: run with VERILATOR_SOLVER pointing to a nonexistent command.
// Expected under a broken solver: constrained randomize() returns 0 (graceful failure),
// solver warning is printed, process exits cleanly (no crash).
`timescale 1ns/1ps
class CBad;
  rand int unsigned a;
  constraint c { a > 100; a < 200; }
endclass
module tb_badsolver;
  CBad obj;
  int rc;
  initial begin
    obj = new();
    rc = obj.randomize();
    $display("[SCEN][badsolver] rc=%0d a=%0d %s", rc, obj.a, (rc == 0) ? "PASS" : "FAIL");
    if (rc != 0) $fatal(1, "randomize should return 0 when solver is missing");
    $display("ALL_DONE");
    $finish;
  end
endmodule
