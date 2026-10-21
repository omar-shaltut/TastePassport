# Dependency-free mutation checks for QMBT-2R-LOC-DIRECT-QUERY-V1.
# Only temporary text fixtures are modified. No API request or secret is used.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$validator = Join-Path $PSScriptRoot 'Test-Qmbt2rDirectLocation.ps1'
$script:passed = 0
$fixtureFiles = @(
    'config/qmbt-2r/direct-location-queries-v1.json',
    'docs/QMBT_2R_LOC_DIRECT_QUERY_V1.md'
)

function New-ValidationFixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('qmbt2r-direct-location-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $root
    foreach ($relativePath in $fixtureFiles) {
        $destination = Join-Path $root $relativePath
        $null = New-Item -ItemType Directory -Path (Split-Path $destination) -Force
        Copy-Item -LiteralPath (Join-Path $repositoryRoot $relativePath) -Destination $destination
    }
    return $root
}

function Set-ManifestMutation {
    param([string]$Root, [scriptblock]$Mutation)
    $path = Join-Path $Root 'config/qmbt-2r/direct-location-queries-v1.json'
    $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    & $Mutation $value
    $json = ConvertTo-Json -InputObject $value -Depth 20
    [IO.File]::WriteAllText($path, $json, [Text.UTF8Encoding]::new($false))
}

function Assert-Rejected {
    param([string]$Name, [scriptblock]$Mutation)
    $root = New-ValidationFixture
    try {
        & $Mutation $root
        $rejected = $false
        try { & $validator -RepositoryRoot $root > $null } catch {
            if ($_.Exception.Message -notlike 'QMBT-2R direct-location validation failed:*') { throw }
            $rejected = $true
        }
        if (-not $rejected) { throw "Unsafe direct-location mutation was accepted: $Name" }
        $script:passed++
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}

& $validator -RepositoryRoot $repositoryRoot
$script:passed++

Assert-Rejected 'Change policy identifier' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.policy_id = 'QMBT-2R-LOC-UNAPPROVED' }
}

Assert-Rejected 'Change candidate count' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidate_count = 7 }
}

Assert-Rejected 'Enable fuzzy locality radius' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.filter_location_radius = 1000 }
}

Assert-Rejected 'Make coordinates operational' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.coordinates_role = 'OPERATIONAL_FILTER' }
}

Assert-Rejected 'Enable fallback geography' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.fallback_geography_allowed = $true }
}

Assert-Rejected 'Change Tokyo direct query after freeze' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates[1].filter_location_query = 'Tokyo, Tokyo, Japan' }
}

Assert-Rejected 'Replace a frozen city' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates[1].canonical_id = 'city:jp:kyoto' }
}

Assert-Rejected 'Reorder frozen city candidates' {
    param($root)
    Set-ManifestMutation $root {
        param($value)
        $tmp = $value.candidates[0]
        $value.candidates[0] = $value.candidates[1]
        $value.candidates[1] = $tmp
    }
}

Assert-Rejected 'Drop a frozen city' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates = @($value.candidates | Select-Object -First 7) }
}

Assert-Rejected 'Add coordinate fallback field' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates[0].latitude = 40.7128 }
}

Assert-Rejected 'Add locality ID fallback field' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates[0].locality_id = 'UNAPPROVED' }
}

Assert-Rejected 'Add unknown top-level field' {
    param($root)
    Set-ManifestMutation $root { param($value) $value['query_mutation_allowed'] = $true }
}

Assert-Rejected 'Duplicate JSON policy key' {
    param($root)
    $path = Join-Path $root 'config/qmbt-2r/direct-location-queries-v1.json'
    $text = [IO.File]::ReadAllText($path)
    $text = $text.Replace('"policy_id": "QMBT-2R-LOC-DIRECT-QUERY-V1",', '"policy_id": "BAD", "policy_id": "QMBT-2R-LOC-DIRECT-QUERY-V1",')
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}

Assert-Rejected 'Authorize live execution in architectural decision' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_LOC_DIRECT_QUERY_V1.md'
    $text = [IO.File]::ReadAllText($path).Replace(
        'Status: FROZEN ARCHITECTURAL DECISION / NO LIVE EXECUTION AUTHORIZED',
        'Status: LIVE EXECUTION AUTHORIZED'
    )
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}

Assert-Rejected 'Remove frozen radius from decision prose' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_LOC_DIRECT_QUERY_V1.md'
    $text = [IO.File]::ReadAllText($path).Replace(
        'Every request uses `filter.location.radius=0`.',
        'Every request may choose a radius.'
    )
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}

Assert-Rejected 'Change a frozen query in decision table only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_LOC_DIRECT_QUERY_V1.md'
    $text = [IO.File]::ReadAllText($path).Replace('`Tokyo, Japan`', '`Tokyo, Tokyo, Japan`')
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}

Write-Output "QMBT-2R direct-location mutation tests passed: $script:passed checks."
