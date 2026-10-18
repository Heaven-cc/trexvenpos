$ErrorActionPreference = 'Stop'
$taskRoot = 'C:\Users\USER\AndroidStudioProjects\trexvenpos\.artifacts\credit_returns_20261017'
$ownerRoot = 'C:\Users\USER\AndroidStudioProjects\Trexven'
$posRoot = 'C:\Users\USER\AndroidStudioProjects\trexvenpos'
$sharedRoot = Join-Path $ownerRoot 'packages\trexven_operations\lib\src'
$manifest = @(
  @{ Name='financial_operations_screen.dart'; Target=(Join-Path $sharedRoot 'financial_operations_screen.dart'); Existing=$true },
  @{ Name='financial_operations_support.dart'; Target=(Join-Path $sharedRoot 'financial_operations_support.dart'); Existing=$false },
  @{ Name='financial_operations_details.dart'; Target=(Join-Path $sharedRoot 'financial_operations_details.dart'); Existing=$false },
  @{ Name='finance_tab.dart'; Target=(Join-Path $ownerRoot 'lib\screens\finance\finance_tab.dart'); Existing=$true },
  @{ Name='operations_screen.dart'; Target=(Join-Path $posRoot 'lib\src\features\pos\operations_screen.dart'); Existing=$true },
  @{ Name='dashboard_screen.dart'; Target=(Join-Path $posRoot 'lib\src\features\pos\dashboard_screen.dart'); Existing=$true },
  @{ Name='credit_returns_screen.dart'; Target=(Join-Path $posRoot 'lib\src\features\pos\credit_returns_screen.dart'); Existing=$false }
)
# Refuse to replace any source that changed while the design was being prepared.
foreach ($entry in $manifest) {
  $staged = Join-Path $taskRoot ('staged\' + $entry.Name)
  if (!(Test-Path -LiteralPath $staged)) { throw "Missing staged file: $staged" }
  if ($entry.Existing) {
    $backup = Join-Path $taskRoot ('before\' + $entry.Name)
    if ((Get-FileHash -LiteralPath $entry.Target).Hash -ne (Get-FileHash -LiteralPath $backup).Hash) {
      throw "Source changed since inspection; inspect before applying: $($entry.Target)"
    }
  } elseif (Test-Path -LiteralPath $entry.Target) {
    throw "New destination already exists; inspect before applying: $($entry.Target)"
  }
}
foreach ($entry in $manifest) {
  Copy-Item -LiteralPath (Join-Path $taskRoot ('staged\' + $entry.Name)) -Destination $entry.Target
}
$verified = foreach ($entry in $manifest) {
  $sourceHash = (Get-FileHash -LiteralPath (Join-Path $taskRoot ('staged\' + $entry.Name))).Hash
  $targetHash = (Get-FileHash -LiteralPath $entry.Target).Hash
  if ($sourceHash -ne $targetHash) { throw "Installed hash mismatch: $($entry.Target)" }
  [pscustomobject]@{ File=$entry.Target; SHA256=$targetHash }
}
$verified | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRoot 'applied_manifest.json') -Encoding UTF8
$verified | Format-Table -AutoSize
