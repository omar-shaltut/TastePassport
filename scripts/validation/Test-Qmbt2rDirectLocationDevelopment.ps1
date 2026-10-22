param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

# Offline-only validation for QMBT-2R-DIRECT-LOCATION-DEVELOPMENT-V1.
# This script must never call Qloo.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-DevContract {
    param([bool]$Condition, [string]$Message)

    if (-not $Condition) {
        throw "QMBT-2R development validation failed: $Message"
    }
}

function Read-RepoText {
    param([string]$RelativePath)

    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-DevContract (Test-Path -LiteralPath $path -PathType Leaf) "Missing $RelativePath."
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
}

function Assert-ExactPropertyNames {
    param(
        $Object,
        [string[]]$Expected,
        [string]$Location
    )

    $actual = @($Object.PSObject.Properties.Name | Sort-Object)
    $wanted = @($Expected | Sort-Object)

    Assert-DevContract (
        ($actual -join '|') -ceq ($wanted -join '|')
    ) "$Location has missing or unknown fields."
}

$manifestText = Read-RepoText 'config/qmbt-2r/direct-location-development-v1.json'

try {
    $manifest = $manifestText | ConvertFrom-Json
}
catch {
    throw "QMBT-2R development validation failed: Invalid manifest JSON. $($_.Exception.Message)"
}

Assert-ExactPropertyNames $manifest @(
    'protocol',
    'evidence_class',
    'source_policy',
    'live_execution_authorized_by_manifest',
    'api_path',
    'filter_type',
    'take',
    'filter_location_radius',
    'expected_request_count',
    'cities',
    'categories',
    'pairs',
    'conditions_per_case',
    'retry_policy',
    'prohibitions'
) 'manifest'

Assert-DevContract (
    [string]$manifest.protocol -ceq 'QMBT-2R-DIRECT-LOCATION-DEVELOPMENT-V1'
) 'Protocol identifier changed.'

Assert-DevContract (
    [string]$manifest.evidence_class -ceq 'DEVELOPMENT_DIAGNOSTIC_ONLY'
) 'Evidence class changed.'

Assert-DevContract (
    [string]$manifest.source_policy -ceq 'QMBT-2R-LOC-DIRECT-QUERY-V1'
) 'Source location policy changed.'

Assert-DevContract (
    -not [bool]$manifest.live_execution_authorized_by_manifest
) 'Manifest must never authorize live execution.'

Assert-DevContract (
    [string]$manifest.api_path -ceq '/v2/insights'
) 'API path changed.'

Assert-DevContract (
    [string]$manifest.filter_type -ceq 'urn:entity:place'
) 'filter.type changed.'

Assert-DevContract ([int]$manifest.take -eq 18) 'take must remain 18.'
Assert-DevContract ([int]$manifest.filter_location_radius -eq 0) 'radius must remain 0.'
Assert-DevContract ([int]$manifest.expected_request_count -eq 72) 'Expected request count must remain 72.'
Assert-DevContract ([int]$manifest.conditions_per_case -eq 3) 'Each case must have exactly three conditions.'

$cities = @($manifest.cities)
Assert-DevContract ($cities.Count -eq 2) 'Exactly two development cities are required.'

Assert-DevContract (
    [string]$cities[0].city_id -ceq 'development:istanbul' -and
    [string]$cities[0].label -ceq 'Istanbul' -and
    [string]$cities[0].filter_location_query -ceq 'Istanbul'
) 'Istanbul development query changed.'

Assert-DevContract (
    [string]$cities[1].city_id -ceq 'development:london' -and
    [string]$cities[1].label -ceq 'London' -and
    [string]$cities[1].filter_location_query -ceq 'London'
) 'London development query changed.'

$expectedCategories = @(
    @('art_gallery', 'urn:tag:category:place:art_gallery'),
    @('book_store', 'urn:tag:category:place:book_store'),
    @('museum', 'urn:tag:category:place:museum'),
    @('park', 'urn:tag:category:place:park'),
    @('restaurant', 'urn:tag:category:place:restaurant'),
    @('shopping_mall', 'urn:tag:category:place:shopping_mall')
)

$categories = @($manifest.categories)
Assert-DevContract ($categories.Count -eq 6) 'Exactly six frozen categories are required.'

for ($i = 0; $i -lt 6; $i++) {
    Assert-DevContract (
        [string]$categories[$i].id -ceq $expectedCategories[$i][0] -and
        [string]$categories[$i].tag -ceq $expectedCategories[$i][1]
    ) "Frozen category at index $i changed."
}

$expectedProfiles = @{
    '2' = @{
        'E' = @(
            '3A02361C-987B-4F7E-9AAD-071C3853AD92',
            '29B49E3F-A0EC-42C6-A453-38B1C20D8374',
            '439D7BFD-8F08-4248-AEDA-D816DD865C71'
        )
        'F' = @(
            'DF788007-B5EA-4F29-872B-96BCB8EEC42F',
            '84B18312-3C2B-41A9-863B-89651C2F6A2C',
            '6A4CF4C4-B833-44E1-A426-BB312130C9F3'
        )
    }
    '3' = @{
        'G' = @(
            'E4FD5F16-4499-4431-9CA9-115625146109',
            'DB4CE34E-3A63-4947-946F-9D52502C5762',
            '1010C15E-3EFA-47D6-911C-1B25026906B5'
        )
        'H' = @(
            '603C7E42-C952-45CB-8B6F-3B803FEFB2F7',
            '32F867B9-E6DF-44C3-BCE4-40160C7ED5E4',
            'AB5E9CA9-E7A4-4D68-A641-FE2276C1C103'
        )
    }
}

$pairs = @($manifest.pairs)
Assert-DevContract ($pairs.Count -eq 2) 'Exactly Pair2 and Pair3 are required.'

foreach ($pair in $pairs) {
    $pairId = [string]$pair.pair_id
    Assert-DevContract ($expectedProfiles.ContainsKey($pairId)) "Unexpected pair: $pairId."

    $profiles = @($pair.profiles)
    Assert-DevContract ($profiles.Count -eq 2) "Pair $pairId must have two profiles."

    foreach ($profile in $profiles) {
        $profileId = [string]$profile.profile_id

        Assert-DevContract (
            $expectedProfiles[$pairId].ContainsKey($profileId)
        ) "Unexpected profile $profileId in Pair $pairId."

        $actualSeeds = @($profile.seed_entity_ids | ForEach-Object { [string]$_ })
        $expectedSeeds = @($expectedProfiles[$pairId][$profileId])

        Assert-DevContract (
            ($actualSeeds -join '|') -ceq ($expectedSeeds -join '|')
        ) "Frozen seed IDs changed for profile $profileId."
    }
}

$retry = $manifest.retry_policy

Assert-DevContract (
    [string]$retry.policy_id -ceq 'EXACT_REQUEST_BOUNDED_RETRY_V1'
) 'Retry policy identifier changed.'

Assert-DevContract ([int]$retry.max_attempts -eq 3) 'Retry max_attempts changed.'
Assert-DevContract (
    (@($retry.fallback_backoff_seconds) -join '|') -ceq '2|8'
) 'Retry backoff changed.'
Assert-DevContract ([int]$retry.retry_after_max_seconds -eq 120) 'Retry-After cap changed.'
Assert-DevContract (-not [bool]$retry.retry_completed_valid_response) 'Completed valid responses must not be retried.'
Assert-DevContract (-not [bool]$retry.content_based_retry_allowed) 'Content-based retry must remain disabled.'

foreach ($name in @(
    'locality_id_filter',
    'wkt_filter',
    'coordinate_filter',
    'geohash_filter',
    'signal_location',
    'alternate_query_after_output',
    'city_replacement',
    'recommendation_preflight',
    'content_based_retry',
    'holdout_access'
)) {
    $property = $manifest.prohibitions.PSObject.Properties[$name]
    Assert-DevContract ($null -ne $property) "Missing prohibition $name."
    Assert-DevContract ([bool]$property.Value) "Prohibition $name must remain enabled."
}

$doc = Read-RepoText 'docs/QMBT_2R_DIRECT_LOCATION_DEVELOPMENT_V1.md'

Assert-DevContract (
    $doc -match 'QMBT-2R-DIRECT-LOCATION-DEVELOPMENT-V1'
) 'Development protocol document identifier is missing.'

Assert-DevContract (
    $doc -match '72'
) 'Development document no longer records the 72-request pass.'

Assert-DevContract (
    $doc -match 'Istanbul' -and $doc -match 'London'
) 'Development document no longer freezes Istanbul/London.'

Assert-DevContract (
    $doc -match 'filter\.location\.radius=0'
) 'Development document no longer freezes radius=0.'

$harness = Read-RepoText 'scripts/qloo-development/18-qmbt-2r-direct-location-development.ps1'
$core = Read-RepoText 'scripts/qloo-development/Qmbt2rDirectLocationDevelopment.Core.ps1'
$workflow = Read-RepoText '.github/workflows/validation.yml'

Assert-DevContract (
    $workflow -notmatch '(?i)18-qmbt-2r-direct-location-development\.ps1|LiveAuthorized'
) 'Repository CI must never invoke or authorize the development live harness.'

Assert-DevContract (
    $workflow -notmatch '(?i)QLOO_API_KEY|X-Api-Key|hackathon\.api\.qloo\.com'
) 'Repository CI must not contain Qloo credentials or live endpoint wiring.'

Assert-DevContract (
    $harness -match '\[switch\]\$LiveAuthorized'
) 'Harness explicit live-authorization switch is missing.'

Assert-DevContract (
    $harness -match 'if\s*\(\s*-not\s+\$LiveAuthorized\s*\)\s*\{'
) 'Harness fail-closed authorization condition changed.'

Assert-DevContract (
    $harness -match 'LIVE_EXECUTION_NOT_AUTHORIZED'
) 'Harness fail-closed live authorization guard is missing.'

$authGuardIndex = $harness.IndexOf('LIVE_EXECUTION_NOT_AUTHORIZED')
$headerCheckIndex = $harness.IndexOf("ContainsKey('X-Api-Key')")

Assert-DevContract (
    $authGuardIndex -ge 0 -and
    $headerCheckIndex -gt $authGuardIndex
) 'Authorization guard must execute before credential validation.'

Assert-DevContract (
    $harness -match 'expected_request_count\s+-ne\s+72' -or
    $harness -match 'expected_request_count.*72'
) 'Harness no longer checks the 72-request contract.'

Assert-DevContract (
    $harness -match 'requestIndex\s+-ne\s+72'
) 'Harness no longer verifies exactly 72 completed requests.'

Assert-DevContract (
    $harness -match "summary\.status\s*=\s*'DEVELOPMENT_K_FEASIBLE'"
) 'Harness success status no longer matches the registered DEVELOPMENT_K_FEASIBLE contract.'

Assert-DevContract (
    $harness -notmatch '(?i)\$env:QLOO_API_KEY|secrets\.QLOO_API_KEY'
) 'Harness must not read a committed or environment API key directly.'

Assert-DevContract (
    $core -match 'filter\.location\.query='
) 'Core no longer uses direct location query.'

Assert-DevContract (
    $core -match 'filter\.location\.radius=0'
) 'Core no longer freezes radius=0.'

Assert-DevContract (
    $core -match 'take=18'
) 'Core no longer freezes take=18.'

Assert-DevContract (
    $core -match 'signal\.interests\.entities='
) 'Core personalized request signal is missing.'

Assert-DevContract (
    $core -match 'EXACT_REQUEST_BOUNDED_RETRY_V1' -or
    (
        $core -match 'MaxAttempts\s*=\s*3' -and
        $core -match 'BackoffSeconds\s*=\s*@\(2,\s*8\)'
    )
) 'Core bounded retry contract changed.'

Assert-DevContract (
    $core -notmatch '(?i)filter\.location=(?!\.query|\.radius)|signal\.location|geohash'
) 'Core contains an unregistered geography fallback.'

Write-Output 'QMBT-2R development static validation passed: exact 72-request Pair2/Pair3 x Istanbul/London direct-location contract, radius=0, take=18, bounded retry, fail-closed authorization, and no geography fallback are preserved. No live calls executed.'