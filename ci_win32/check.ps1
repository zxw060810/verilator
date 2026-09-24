# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
# Assert scenario results from a run log: all $Expected scenarios PASS, zero FAIL, ALL_DONE seen
param([string]$Log, [int]$Expected = 11, [string]$Label = "run")
if (-not (Test-Path $Log)) { Write-Output "CHECK[$Label]: LOG MISSING $Log"; exit 1 }
$pass = (Select-String -Path $Log -Pattern '\[SCEN\]\[[a-z_]+\] .* PASS').Count
$fail = (Select-String -Path $Log -Pattern '\[SCEN\]\[[a-z_]+\] .* FAIL').Count
$done = Select-String -Path $Log -Pattern 'ALL_DONE' -Quiet
Write-Output "CHECK[$Label]: pass=$pass fail=$fail all_done=$done (expected $Expected)"
if (($pass -ne $Expected) -or ($fail -ne 0) -or (-not $done)) { exit 1 }
exit 0
