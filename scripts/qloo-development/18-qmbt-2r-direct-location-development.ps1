param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [hashtable]$Headers,
    [switch]$LiveAuthorized,
    [string]$OutputRoot = 'artifacts/qmbt-2r-direct-location-development'
)

# QMBT-2R development-only direct-location mechanism validation.
# LIVE EXECUTION REQUIRES repository validation for this exact commit
# AND a separate explicit human authorization.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $LiveAuthorized) {
    throw 'LIVE_EXECUTION_NOT_AUTHORIZED: repository validation and explicit human authorization are required.'
}

if ($null -eq $Headers -or
    -not $Headers.ContainsKey('X-Api-Key') -or
    [string]::IsNullOrWhiteSpace([string]$Headers['X-Api-Key'])) {
    throw 'Qloo authentication header is missing. Pass the existing in-memory headers object; do not paste or commit the key.'
}

Add-Type -AssemblyName System.Net.Http

$corePath = Join-Path $PSScriptRoot 'Qmbt2rDirectLocationDevelopment.Core.ps1'
if (-not (Test-Path -LiteralPath $corePath -PathType Leaf)) {
    throw 'Development request core is missing.'
}
. $corePath

$manifestPath = Join-Path $RepositoryRoot 'config/qmbt-2r/direct-location-development-v1.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Frozen development manifest is missing.'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ([string]$manifest.protocol -cne 'QMBT-2R-DIRECT-LOCATION-DEVELOPMENT-V1') {
    throw 'Development protocol identifier changed.'
}
if ([string]$manifest.evidence_class -cne 'DEVELOPMENT_DIAGNOSTIC_ONLY') {
    throw 'Development evidence class changed.'
}
if ([bool]$manifest.live_execution_authorized_by_manifest) {
    throw 'Manifest must never authorize live execution.'
}
if ([int]$manifest.take -ne 18) {
    throw 'Development take must remain 18.'
}
if ([int]$manifest.filter_location_radius -ne 0) {
    throw 'Development filter.location.radius must remain 0.'
}
if ([int]$manifest.expected_request_count -ne 72) {
    throw 'Development pass must contain exactly 72 registered requests.'
}
if (@($manifest.cities).Count -ne 2 -or
    @($manifest.categories).Count -ne 6 -or
    @($manifest.pairs).Count -ne 2) {
    throw 'Frozen development matrix shape changed.'
}

$cityQueries = @($manifest.cities | ForEach-Object { [string]$_.filter_location_query })
if (($cityQueries -join '|') -cne 'Istanbul|London') {
    throw 'Frozen development location queries changed.'
}

foreach ($pair in @($manifest.pairs)) {
    if (@($pair.profiles).Count -ne 2) {
        throw "Pair $($pair.pair_id) must contain exactly two profiles."
    }

    foreach ($profile in @($pair.profiles)) {
        if (@($profile.seed_entity_ids).Count -ne 3) {
            throw "Profile $($profile.profile_id) must contain exactly three frozen seed IDs."
        }
    }
}

if ([IO.Path]::IsPathRooted($OutputRoot)) {
    $resolvedOutputRoot = $OutputRoot
} else {
    $resolvedOutputRoot = Join-Path $RepositoryRoot $OutputRoot
}

$runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$runDirectory = Join-Path $resolvedOutputRoot $runId
$rawDirectory = Join-Path $runDirectory 'raw'

$null = New-Item -ItemType Directory -Path $rawDirectory -Force
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $runDirectory 'direct-location-development-v1.json')

function Write-Qmbt2rDevJson {
    param(
        $Value,
        [string]$Path
    )

    $json = ConvertTo-Json -InputObject $Value -Depth 30
    [IO.File]::WriteAllText(
        $Path,
        $json,
        [Text.UTF8Encoding]::new($false)
    )
}

$requests = [Collections.Generic.List[object]]::new()
$conditionSummaries = [Collections.Generic.List[object]]::new()

$summary = [ordered]@{
    protocol = 'QMBT-2R-DIRECT-LOCATION-DEVELOPMENT-V1'
    evidence_class = 'DEVELOPMENT_DIAGNOSTIC_ONLY'
    retry_policy = 'EXACT_REQUEST_BOUNDED_RETRY_V1'
    started_at_utc = [DateTime]::UtcNow.ToString('o')
    completed_at_utc = $null
    status = 'RUNNING'
    expected_request_count = 72
    completed_request_count = 0
    conditions = $conditionSummaries
}

function Save-Qmbt2rDevState {
    $summary.completed_request_count = $requests.Count

    Write-Qmbt2rDevJson `
        -Value @($requests) `
        -Path (Join-Path $runDirectory 'requests.json')

    Write-Qmbt2rDevJson `
        -Value $summary `
        -Path (Join-Path $runDirectory 'summary.json')
}

$handler = [Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $false

$client = [Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds($script:Qmbt2rDevTimeoutSeconds)

$requestIndex = 0

try {
    foreach ($pair in @($manifest.pairs)) {
        $profiles = @($pair.profiles)

        $conditions = @(
            [PSCustomObject]@{
                condition_id = "PROFILE_$($profiles[0].profile_id)"
                profile_id = [string]$profiles[0].profile_id
                seed_entity_ids = @($profiles[0].seed_entity_ids)
                unsignaled = $false
            },
            [PSCustomObject]@{
                condition_id = "PROFILE_$($profiles[1].profile_id)"
                profile_id = [string]$profiles[1].profile_id
                seed_entity_ids = @($profiles[1].seed_entity_ids)
                unsignaled = $false
            },
            [PSCustomObject]@{
                condition_id = 'UNSIGNALED_QLOO_BASELINE'
                profile_id = $null
                seed_entity_ids = @()
                unsignaled = $true
            }
        )

        foreach ($city in @($manifest.cities)) {
            foreach ($condition in $conditions) {
                $conditionRecords = [Collections.Generic.List[object]]::new()

                foreach ($category in @($manifest.categories)) {
                    $requestIndex++

                    $uri = New-Qmbt2rDevRequestUri `
                        -LocationQuery ([string]$city.filter_location_query) `
                        -CategoryTag ([string]$category.tag) `
                        -SeedIds @($condition.seed_entity_ids) `
                        -Unsignaled ([bool]$condition.unsignaled)

                    $slugParts = @(
                        ('{0:d3}' -f $requestIndex),
                        [string]$pair.pair_id,
                        [string]$city.city_id,
                        [string]$condition.condition_id,
                        [string]$category.id
                    )

                    $slug = (($slugParts -join '-') -replace '[^a-zA-Z0-9.-]+', '-')

                    $transport = Invoke-Qmbt2rDevFrozenRequest `
                        -Client $client `
                        -Uri $uri `
                        -Headers $Headers `
                        -RawDirectory $rawDirectory `
                        -Slug $slug

                    $returnedIds = @(
                        Get-Qmbt2rDevEntityIds -Entities @($transport.entities)
                    )

                    $distinctIds = @(
                        $returnedIds | Select-Object -Unique
                    )

                    $record = [ordered]@{
                        request_index = $requestIndex
                        pair_id = [string]$pair.pair_id
                        city_id = [string]$city.city_id
                        city_label = [string]$city.label
                        filter_location_query = [string]$city.filter_location_query
                        condition_id = [string]$condition.condition_id
                        profile_id = $condition.profile_id
                        category_id = [string]$category.id
                        category_tag = [string]$category.tag
                        requested_take = 18
                        request_uri = $uri
                        final_http_status = [int]$transport.status_code
                        attempts = @($transport.attempts)
                        returned_entity_count = @($transport.entities).Count
                        distinct_entity_id_count = $distinctIds.Count
                        returned_entity_ids = $returnedIds
                    }

                    $requests.Add($record)
                    $conditionRecords.Add($record)

                    Save-Qmbt2rDevState
                }

                $quota = Get-Qmbt2rDevQuotaAssembly -Records @($conditionRecords)

                $conditionSummaries.Add([ordered]@{
                    pair_id = [string]$pair.pair_id
                    city_id = [string]$city.city_id
                    city_label = [string]$city.label
                    condition_id = [string]$condition.condition_id
                    profile_id = $condition.profile_id
                    structural_pass = [bool]$quota.structural_pass
                    final_unique_entity_count = [int]$quota.final_unique_entity_count
                    categories = @($quota.categories)
                })

                Save-Qmbt2rDevState
            }
        }
    }

    if ($requestIndex -ne 72 -or $requests.Count -ne 72) {
        throw "REGISTERED_REQUEST_COUNT_MISMATCH: expected 72, completed $($requests.Count)."
    }

    $failedConditions = @(
        $conditionSummaries |
        Where-Object { -not $_.structural_pass }
    )

    if ($failedConditions.Count -eq 0) {
        $summary.status = 'DEVELOPMENT_K_FEASIBLE'
    } else {
        $summary.status = 'DEVELOPMENT_K_NOT_FEASIBLE'
    }

    $summary.completed_at_utc = [DateTime]::UtcNow.ToString('o')
    Save-Qmbt2rDevState

    Write-Output (
        "QMBT-2R direct-location development pass completed: " +
        "$($summary.status); requests=$($requests.Count)."
    )
}
catch {
    $summary.status = 'INCOMPLETE_EXECUTION_API_OR_TRANSPORT'
    $summary.completed_at_utc = [DateTime]::UtcNow.ToString('o')
    $summary.failure_message = $_.Exception.Message
    Save-Qmbt2rDevState
    throw
}
finally {
    $client.Dispose()
    $handler.Dispose()
}