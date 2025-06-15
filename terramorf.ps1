<#
.SYNOPSIS
  Destroy all Terraform-managed resources except those you choose to keep,
  when run from a sibling folder of your Terraform project.
#>

# Step 0: Change to Terraform project directory (one level up from script)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tfDir     = Resolve-Path (Join-Path $scriptDir '..')
Set-Location $tfDir

# Step 1: Retrieve all Terraform-managed resources
Write-Host "Listing Terraform state resources in $PWD..." -ForegroundColor Cyan
$allResources = terraform state list

if (-not $allResources) {
    Write-Host "No resources found in state. Are you in the correct Terraform directory?" -ForegroundColor Red
    exit 1
}

# Step 2: Display each resource with an index
Write-Host "`nAvailable Terraform Resources:" -ForegroundColor Green
$index = 1
$resourceMap = @{}
foreach ($res in $allResources) {
    $resourceMap[$index] = $res
    Write-Host ("[{0}] {1}" -f $index, $res)
    $index++
}

# Step 3: Prompt user for which to KEEP
$input = Read-Host -Prompt 'Enter the numbers of the resources to KEEP (comma-separated, e.g. 1,3,5)'
$selectedIndices = $input -split "," |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -match '^\d+$' } |
    ForEach-Object { [int]$_ }

if (-not $selectedIndices) {
    Write-Host "No valid selection made. Exiting without changes." -ForegroundColor Yellow
    exit 0
}

# Step 4: Build and save keep.txt
$keepList = foreach ($i in $selectedIndices) {
    if ($resourceMap.ContainsKey($i)) { $resourceMap[$i] }
}
$keepList | Out-File -FilePath "keep.txt" -Encoding utf8

Write-Host "`nResources to KEEP:" -ForegroundColor Cyan
$keepList | ForEach-Object { Write-Host " - $_" }

# Step 5: Determine which to destroy
$destroyList = $allResources | Where-Object { $keepList -notcontains $_ }

if (-not $destroyList) {
    Write-Host "`nNothing to destroy. Exiting." -ForegroundColor Green
    exit 0
}

Write-Host "`nResources to DESTROY:" -ForegroundColor Red
$destroyList | ForEach-Object { Write-Host " - $_" }

# Step 6: Confirm and execute destroy
$confirmation = Read-Host -Prompt 'Type yes to confirm destroy'
if ($confirmation -ne 'yes') {
    Write-Host "Destroy aborted by user." -ForegroundColor Yellow
    exit 0
}

foreach ($res in $destroyList) {
    Write-Host "`nDestroying $res..." -ForegroundColor Magenta
    # Use the call operator (&) and quote the flag to expand $res
    & terraform destroy "-target=$res" "-auto-approve"
}

Write-Host "`nDestroy complete." -ForegroundColor Green