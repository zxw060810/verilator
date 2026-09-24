// SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
// Constraint randomization combination coverage test (Windows solver pipe validation)
// Each scenario self-checks and prints [SCEN][name] ... PASS/FAIL; $fatal on any FAIL.
// Scenarios: dist / solve_before / randc_full_cycle / inside / implication /
//            array_foreach_sum / assoc / soft_keep / soft_drop / randmode / unsat
`timescale 1ns/1ps

// ---- S1: dist weighted distribution ----
class CDist;
  rand bit [31:0] a;
  constraint c { a dist { 100 :/ 1, 200 :/ 3, 300 :/ 2 }; }
endclass

// ---- S2: solve...before ordering with implication ----
class CSolveBefore;
  rand bit m;
  rand int unsigned b;
  constraint c { solve m before b;
                 (m == 1) -> b inside {[0:10]};
                 (m == 0) -> b inside {[100:110]}; }
endclass

// ---- S3: randc full cycle (4-bit -> 16 draws cover all values) ----
class CRandc;
  randc bit [3:0] c;
endclass

// ---- S4: inside operator ----
class CInside;
  rand bit [31:0] a;
  constraint c { a inside {1, 3, 5, 7}; }
endclass

// ---- S5: implication ----
class CImpl;
  rand bit sel;
  rand int unsigned v;
  constraint c { (sel == 1) -> v inside {[0:15]}; }
endclass

// ---- S6: array foreach + sum ----
class CArrSum;
  rand bit [7:0] arr[4];
  constraint c { foreach (arr[i]) arr[i] inside {[1:20]};
                 arr.sum() with (int'(item)) == 40; }
endclass

// ---- S7: associative array (keys pre-created; randomize only values, per IEEE
//      randomize does not add/remove elements) ----
class CAssoc;
  rand int unsigned aa[int];
  function new();
    aa[0] = 0; aa[10] = 0; aa[20] = 0;  // fix the key set
  endfunction
  constraint c { foreach (aa[i]) aa[i] inside {[1:10]}; }
endclass

// ---- S8/S9: soft keep / soft drop ----
class CSoftKeep;
  rand bit [31:0] a;
  constraint c_hard { a > 0; a < 200; }
  constraint c_soft { soft a < 10; }
endclass
class CSoftDrop;
  rand bit [31:0] a;
  constraint c_hard { a > 100; a < 200; }
  constraint c_soft { soft a < 10; }
endclass

// ---- S10: rand_mode off keeps value ----
class CRandMode;
  rand bit [31:0] a;
  rand bit [31:0] k;
  constraint c { a inside {[1000:2000]}; k inside {[1:50]}; }
endclass

// ---- S11: UNSAT ----
class CUnsat;
  rand bit [31:0] a;
  constraint c { a > 100; a < 50; }
endclass

module tb_rand_combos;
  CDist       d;
  CSolveBefore sb;
  CRandc      rc4;
  CInside     ins;
  CImpl       impl;
  CArrSum     as;
  CAssoc      aa;
  CSoftKeep   sk;
  CSoftDrop   sd;
  CRandMode   rm;
  CUnsat      us;

  int rc, i, n100, n200, n300, nbad, nv;
  bit [15:0] seen;
  bit [3:0]  cval;
  bit ok;
  int unsigned vals[$];

  initial begin
    // ============ S1: dist ============
    d = new(); n100 = 0; n200 = 0; n300 = 0; nbad = 0; ok = 1;
    for (i = 0; i < 300; i++) begin
      rc = d.randomize();
      if (rc != 1) begin nbad++; ok = 0; end
      else if (d.a == 100) n100++;
      else if (d.a == 200) n200++;
      else if (d.a == 300) n300++;
      else begin nbad++; ok = 0; end
    end
    // domain + all-values-seen + weak weight sanity (w=1 vs w=3)
    if (nbad != 0 || n100 == 0 || n200 == 0 || n300 == 0 || n100 >= n200) ok = 0;
    $display("[SCEN][dist] n100=%0d n200=%0d n300=%0d bad=%0d %s", n100, n200, n300, nbad, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "dist failed");

    // ============ S2: solve before ============
    sb = new(); nbad = 0;
    for (i = 0; i < 200; i++) begin
      rc = sb.randomize();
      if (rc != 1) nbad++;
      else if (sb.m == 1 && sb.b > 10) nbad++;
      else if (sb.m == 0 && (sb.b < 100 || sb.b > 110)) nbad++;
    end
    ok = (nbad == 0);
    $display("[SCEN][solve_before] bad=%0d %s", nbad, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "solve_before failed");

    // ============ S3: randc full cycle ============
    rc4 = new(); seen = 16'h0; ok = 1;
    for (i = 0; i < 16; i++) begin
      rc = rc4.randomize();
      cval = rc4.c;
      if (rc != 1 || seen[cval]) ok = 0;
      seen[cval] = 1'b1;
    end
    if (seen != 16'hFFFF) ok = 0;
    $display("[SCEN][randc] seen=%b %s", seen, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "randc failed");

    // ============ S4: inside ============
    ins = new(); nbad = 0;
    for (i = 0; i < 100; i++) begin
      rc = ins.randomize();
      if (rc != 1 || !(ins.a inside {1, 3, 5, 7})) nbad++;
    end
    ok = (nbad == 0);
    $display("[SCEN][inside] bad=%0d %s", nbad, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "inside failed");

    // ============ S5: implication ============
    impl = new(); nbad = 0; nv = 0;
    for (i = 0; i < 200; i++) begin
      rc = impl.randomize();
      if (rc != 1) nbad++;
      else if (impl.sel == 1 && impl.v > 15) nbad++;
      if (impl.sel == 1) nv++;
    end
    ok = (nbad == 0 && nv > 0);
    $display("[SCEN][implication] bad=%0d sel1_cases=%0d %s", nbad, nv, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "implication failed");

    // ============ S6: array foreach + sum ============
    as = new(); nbad = 0;
    for (i = 0; i < 100; i++) begin
      rc = as.randomize();
      if (rc != 1) nbad++;
      else begin
        nv = 0;
        for (int j = 0; j < 4; j++) begin
          if (as.arr[j] < 1 || as.arr[j] > 20) nbad++;
          nv += int'(as.arr[j]);
        end
        if (nv != 40) nbad++;
      end
    end
    ok = (nbad == 0);
    $display("[SCEN][array_sum] bad=%0d %s", nbad, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "array_sum failed");

    // ============ S7: associative array ============
    aa = new(); nbad = 0;
    for (i = 0; i < 50; i++) begin
      rc = aa.randomize();
      if (rc != 1) nbad++;
      else begin
        if (aa.aa.size() != 3) nbad++;
        foreach (aa.aa[k]) if (aa.aa[k] < 1 || aa.aa[k] > 10) nbad++;
      end
    end
    ok = (nbad == 0);
    $display("[SCEN][assoc] bad=%0d %s", nbad, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "assoc failed");

    // ============ S8: soft keep ============
    sk = new(); rc = sk.randomize();
    ok = (rc == 1) && (sk.a < 10);
    $display("[SCEN][soft_keep] rc=%0d a=%0d %s", rc, sk.a, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "soft_keep failed");

    // ============ S9: soft drop ============
    sd = new(); rc = sd.randomize();
    ok = (rc == 1) && (sd.a > 100) && (sd.a < 200);
    $display("[SCEN][soft_drop] rc=%0d a=%0d %s", rc, sd.a, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "soft_drop failed");

    // ============ S10: rand_mode(0) keeps value ============
    rm = new();
    rm.a = 1234;                 // non-default fixed value
    rm.a.rand_mode(0);           // disable randomization of a
    rc = rm.randomize();
    ok = (rc == 1) && (rm.a == 1234) && (rm.k >= 1) && (rm.k <= 50);
    $display("[SCEN][randmode] rc=%0d a=%0d k=%0d %s", rc, rm.a, rm.k, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "randmode failed");

    // ============ S11: UNSAT graceful ============
    us = new(); rc = us.randomize();
    ok = (rc == 0);              // graceful failure, no crash/hang
    $display("[SCEN][unsat] rc=%0d %s", rc, ok ? "PASS" : "FAIL");
    if (!ok) $fatal(1, "unsat failed");

    $display("ALL_DONE");
    $finish;
  end
endmodule
