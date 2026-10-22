# Dependency-free mutation checks for QMBT-2R-DIRECT-LOCATION-DEVELOPMENT-V1.
# Only temporary repository fixtures are modified. No API request or secret is used.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$validator = Join-Path $PSScriptRoot 'Test-Qmbt2rDirectLocationDevelopment.ps1'
$script:passed = 0

$fixtureFiles = @(
    'config/qmbt-2r/direct-location-development-v1.json',
    'docs/QMBT_2R_DIRECT_LOCATION_DEVELOPMENT_V1.md',
    'scripts/qloo-development/18-qmbt-2r-direct-location-development.ps1',
    'scripts/qloo-development/Qmbt2rDirectLocationDevelopment.Core.ps1',
    '.github/workflows/validation.yml'
)

function New-ValidationFixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) (
        'qmbt2r-direct-location-development-' + [guid]::NewGuid().ToString('N')
    )

    $null = New-Item -ItemType Directory -Path $root

    foreach ($relativePath in $fixtureFiles) {
        $source = Join-Path $repositoryRoot $relativePath
        $destination = Join-Path $root $relativePath

        $null = New-Item -ItemType Directory -Path (Split-Path $destination) -Force
        Copy-Item -LiteralPath $source -Destination $destination
    }

    return $root
}

function Set-TextMutation {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Old,
        [string]$New
    )

    $path = Join-Path $Root $RelativePath
    $text = [IO.File]::ReadAllText($path)

    if (-not $text.Contains($Old)) {
        throw "Mutation fixture text was not found in $RelativePath`: $Old"
    }

    $text = $text.Replace($Old, $New)

    [IO.File]::WriteAllText(
        $path,
        $text,
        [Text.UTF8Encoding]::new($false)
    )
}

function Assert-Rejected {
    param(
        [string]$Name,
        [scriptblock]$Mutation
    )

    $root = New-ValidationFixture

    try {
        & $Mutation $root

        $rejected = $false

        try {
            & $validator -RepositoryRoot $root > $null
        }
        catch {
            if (
                $_.Exception.Message -notlike
                'QMBT-2R development validation failed:*'
            ) {
                throw
            }

            $rejected = $true
        }

        if (-not $rejected) {
            throw "Unsafe development mutation was accepted: $Name"
        }

        $script:passed++
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}

# Positive control: the committed repository must pass first.
& $validator -RepositoryRoot $repositoryRoot > $null
$script:passed++

Assert-Rejected 'Change expected request count from 72 to 71' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"expected_request_count": 72' `
        -New '"expected_request_count": 71'
}

Assert-Rejected 'Change take from 18 to 17' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"take": 18' `
        -New '"take": 17'
}

Assert-Rejected 'Enable nonzero location radius' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"filter_location_radius": 0' `
        -New '"filter_location_radius": 5000'
}

Assert-Rejected 'Change Istanbul frozen direct query' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"filter_location_query": "Istanbul"' `
        -New '"filter_location_query": "Istanbul, Turkey"'
}

Assert-Rejected 'Change London frozen direct query' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"filter_location_query": "London"' `
        -New '"filter_location_query": "London, United Kingdom"'
}

Assert-Rejected 'Change frozen category identity' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"id": "museum", "tag": "urn:tag:category:place:museum"' `
        -New '"id": "landmark", "tag": "urn:tag:category:place:landmark"'
}

Assert-Rejected 'Change a frozen profile seed ID' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '3A02361C-987B-4F7E-9AAD-071C3853AD92' `
        -New '00000000-0000-0000-0000-000000000000'
}

Assert-Rejected 'Authorize live execution through manifest' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"live_execution_authorized_by_manifest": false' `
        -New '"live_execution_authorized_by_manifest": true'
}

Assert-Rejected 'Increase retry attempt budget' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"max_attempts": 3' `
        -New '"max_attempts": 4'
}

Assert-Rejected 'Enable content-based retry' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"content_based_retry_allowed": false' `
        -New '"content_based_retry_allowed": true'
}

Assert-Rejected 'Disable locality-ID prohibition' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"locality_id_filter": true' `
        -New '"locality_id_filter": false'
}

Assert-Rejected 'Disable holdout-access prohibition' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'config/qmbt-2r/direct-location-development-v1.json' `
        -Old '"holdout_access": true' `
        -New '"holdout_access": false'
}

Assert-Rejected 'Disable fail-closed live authorization guard' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'scripts/qloo-development/18-qmbt-2r-direct-location-development.ps1' `
        -Old 'if (-not $LiveAuthorized) {' `
        -New 'if ($false) {'
}

Assert-Rejected 'Remove explicit live authorization switch' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'scripts/qloo-development/18-qmbt-2r-direct-location-development.ps1' `
        -Old '[switch]$LiveAuthorized' `
        -New '[switch]$RunWithoutAuthorization'
}

Assert-Rejected 'Change completed request-count guard' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'scripts/qloo-development/18-qmbt-2r-direct-location-development.ps1' `
        -Old '$requestIndex -ne 72' `
        -New '$requestIndex -ne 71'
}

Assert-Rejected 'Change registered success status' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'scripts/qloo-development/18-qmbt-2r-direct-location-development.ps1' `
        -Old "'DEVELOPMENT_K_FEASIBLE'" `
        -New "'DEVELOPMENT_STRUCTURAL_PASS'"
}

Assert-Rejected 'Change core direct-location radius' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'scripts/qloo-development/Qmbt2rDirectLocationDevelopment.Core.ps1' `
        -Old 'filter.location.radius=0&take=18' `
        -New 'filter.location.radius=1000&take=18'
}

Assert-Rejected 'Change core take from 18' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'scripts/qloo-development/Qmbt2rDirectLocationDevelopment.Core.ps1' `
        -Old 'filter.location.radius=0&take=18' `
        -New 'filter.location.radius=0&take=17'
}

Assert-Rejected 'Introduce signal.location fallback' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath 'scripts/qloo-development/Qmbt2rDirectLocationDevelopment.Core.ps1' `
        -Old '&filter.location.query=' `
        -New '&signal.location=UNAPPROVED&filter.location.query='
}

Assert-Rejected 'Make CI invoke the live development harness' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath '.github/workflows/validation.yml' `
        -Old 'run: ./scripts/validation/Test-Qmbt2rDirectLocation.Tests.ps1' `
        -New 'run: ./scripts/qloo-development/18-qmbt-2r-direct-location-development.ps1 -LiveAuthorized'
}

Assert-Rejected 'Add Qloo credential wiring to CI' {
    param($root)

    Set-TextMutation `
        -Root $root `
        -RelativePath '.github/workflows/validation.yml' `
        -Old 'permissions:' `
        -New "env:`n  QLOO_API_KEY: forbidden-fixture-value`n`npermissions:"
}

Write-Output (
    "QMBT-2R development mutation tests passed: " +
    "$script:passed checks."
)