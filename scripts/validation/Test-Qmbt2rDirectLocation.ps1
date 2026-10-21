param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

# Offline-only validation for QMBT-2R-LOC-DIRECT-QUERY-V1.
# This script reads committed text/config only and must never call Qloo.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-DirectLocation {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "QMBT-2R direct-location validation failed: $Message" }
}

function Read-RepositoryText {
    param([string]$RelativePath)
    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-DirectLocation (Test-Path -LiteralPath $path -PathType Leaf) "Missing $RelativePath."
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
}

function Assert-NoDuplicateJsonKeys {
    param([System.Text.Json.JsonElement]$Element)
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($property in $Element.EnumerateObject()) {
            Assert-DirectLocation ($names.Add($property.Name)) "Duplicate JSON key: $($property.Name)."
            Assert-NoDuplicateJsonKeys $property.Value
        }
    } elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($item in $Element.EnumerateArray()) { Assert-NoDuplicateJsonKeys $item }
    }
}

function Assert-ExactValue {
    param($Expected, $Actual, [string]$Location = 'manifest')

    if ($Expected -is [Collections.IDictionary]) {
        Assert-DirectLocation ($Actual -is [Collections.IDictionary]) "$Location must be an object."
        $expectedKeys = @($Expected.Keys | Sort-Object)
        $actualKeys = @($Actual.Keys | Sort-Object)
        Assert-DirectLocation (($expectedKeys -join '|') -ceq ($actualKeys -join '|')) "$Location has missing or unknown fields."
        foreach ($key in $expectedKeys) {
            Assert-ExactValue $Expected[$key] $Actual[$key] "$Location.$key"
        }
        return
    }

    if ($Expected -is [array]) {
        Assert-DirectLocation ($Actual -is [array]) "$Location must be an array."
        Assert-DirectLocation ($Expected.Count -eq $Actual.Count) "$Location changed length."
        for ($i = 0; $i -lt $Expected.Count; $i++) {
            Assert-ExactValue $Expected[$i] $Actual[$i] "$Location[$i]"
        }
        return
    }

    $expectedJson = ConvertTo-Json -InputObject $Expected -Compress
    $actualJson = ConvertTo-Json -InputObject $Actual -Compress
    Assert-DirectLocation ($expectedJson -ceq $actualJson) "$Location changed from its frozen value."
}

$manifestText = Read-RepositoryText 'config/qmbt-2r/direct-location-queries-v1.json'
try {
    $document = [System.Text.Json.JsonDocument]::Parse($manifestText)
    try { Assert-NoDuplicateJsonKeys $document.RootElement } finally { $document.Dispose() }
    $manifest = ConvertFrom-Json -InputObject $manifestText -AsHashtable -Depth 50
} catch {
    throw "QMBT-2R direct-location validation failed: Invalid manifest JSON. $($_.Exception.Message)"
}

$expected = @{
    policy_id = 'QMBT-2R-LOC-DIRECT-QUERY-V1'
    candidate_count = 8
    filter_location_radius = 0
    coordinates_role = 'AUDIT_METADATA_ONLY'
    fallback_geography_allowed = $false
    candidates = @(
        @{ canonical_id = 'city:us:new-york-city'; filter_location_query = 'New York City, United States of America' },
        @{ canonical_id = 'city:jp:tokyo'; filter_location_query = 'Tokyo, Japan' },
        @{ canonical_id = 'city:fr:paris'; filter_location_query = 'Paris, France' },
        @{ canonical_id = 'city:mx:mexico-city'; filter_location_query = 'Mexico City, Mexico' },
        @{ canonical_id = 'city:br:sao-paulo'; filter_location_query = 'São Paulo, Brazil' },
        @{ canonical_id = 'city:sg:singapore'; filter_location_query = 'Singapore, Singapore' },
        @{ canonical_id = 'city:au:sydney'; filter_location_query = 'Sydney, Australia' },
        @{ canonical_id = 'city:za:cape-town'; filter_location_query = 'Cape Town, South Africa' }
    )
}
Assert-ExactValue $expected $manifest

$ids = @($manifest.candidates | ForEach-Object { [string]$_.canonical_id })
Assert-DirectLocation ((@($ids | Select-Object -Unique).Count) -eq 8) 'Candidate canonical IDs must be unique.'

$queries = @($manifest.candidates | ForEach-Object { [string]$_.filter_location_query })
Assert-DirectLocation ((@($queries | Select-Object -Unique).Count) -eq 8) 'Direct location query strings must be unique.'
Assert-DirectLocation (-not [regex]::IsMatch($manifestText, '(?i)\b(latitude|longitude|geohash|locality_id|entity_id|filter_location|signal_location|wkt)\b')) 'Manifest must not add an operational geography fallback field.'
Assert-DirectLocation (-not [regex]::IsMatch($manifestText, '(?i)QLOO_API_KEY|hackathon\.api\.qloo\.com|/v2/insights')) 'Manifest must remain offline data only.'

$decision = Read-RepositoryText 'docs/QMBT_2R_LOC_DIRECT_QUERY_V1.md'
$statusMatches = [regex]::Matches($decision, '(?m)^Status: .*$')
Assert-DirectLocation ($statusMatches.Count -eq 1) 'Architectural decision must contain exactly one Status line.'
Assert-DirectLocation ($statusMatches[0].Value -ceq 'Status: FROZEN ARCHITECTURAL DECISION / NO LIVE EXECUTION AUTHORIZED') 'Architectural decision must not authorize live execution.'
Assert-DirectLocation ($decision.Contains('Decision identifier: `QMBT-2R-LOC-DIRECT-QUERY-V1`')) 'Architectural decision identifier changed or is missing.'
Assert-DirectLocation ($decision.Contains('Every request uses `filter.location.radius=0`.')) 'Architectural decision no longer freezes radius=0.'
Assert-DirectLocation ($decision.Contains('Researcher latitude/longitude remains immutable audit metadata only')) 'Architectural decision no longer keeps coordinates audit-only.'
Assert-DirectLocation ($decision.Contains('No live Qloo call is authorized by this document.')) 'Architectural decision live-execution stop gate changed.'

foreach ($candidate in $expected.candidates) {
    $row = '| `' + $candidate.canonical_id + '` | `' + $candidate.filter_location_query + '` |'
    Assert-DirectLocation ($decision.Contains($row)) "Architectural decision table changed for $($candidate.canonical_id)."
}

Write-Output 'QMBT-2R direct-location static validation passed: exact eight queries, radius=0, audit-only coordinates, no fallback geography, and no live execution authorization are frozen.'
