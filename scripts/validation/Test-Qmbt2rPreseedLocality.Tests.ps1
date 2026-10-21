# Dependency-free mutation checks for QMBT-2R pre-Seed locality authorization.
# Only temporary fixtures are modified. No Qloo request is executed.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$validator = Join-Path $PSScriptRoot 'Test-Qmbt2rPreseedLocality.ps1'
$script:passed = 0

$fixtureFiles = @(
    'docs/QMBT_2R_PRESEED_LOCALITY.md',
    'config/qmbt-2r/preseed-localities.json',
    'scripts/qloo-preseed/16-qmbt-2r-locality-resolution.ps1',
    '.github/workflows/validation.yml'
)

function New-Fixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('qmbt2r-preseed-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $root
    foreach ($relative in $fixtureFiles) {
        $destination = Join-Path $root $relative
        $null = New-Item -ItemType Directory -Path (Split-Path $destination) -Force
        Copy-Item -LiteralPath (Join-Path $repositoryRoot $relative) -Destination $destination
    }
    return $root
}

function Assert-Rejected {
    param([string]$Name, [scriptblock]$Mutation)
    $root = New-Fixture
    try {
        & $Mutation $root
        $rejected = $false
        try { & $validator -RepositoryRoot $root > $null } catch {
            if ($_.Exception.Message -notlike 'QMBT-2R pre-Seed locality validation failed:*') { throw }
            $rejected = $true
        }
        if (-not $rejected) { throw "Unsafe mutation was accepted: $Name" }
        $script:passed++
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}

function Assert-Accepted {
    param([string]$Name, [scriptblock]$Mutation)
    $root = New-Fixture
    try {
        & $Mutation $root
        try { & $validator -RepositoryRoot $root > $null } catch {
            throw "Safe mutation was rejected: $Name. $($_.Exception.Message)"
        }
        $script:passed++
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}

function Set-ProtocolContractMutation {
    param([string]$Root, [scriptblock]$Mutation)
    $path = Join-Path $Root 'docs/QMBT_2R_PRESEED_LOCALITY.md'
    $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $match = [regex]::Match($text, '(?ms)^```json\n(.*?)\n```$')
    $value = ConvertFrom-Json -InputObject $match.Groups[1].Value -AsHashtable
    & $Mutation $value
    $json = ConvertTo-Json -InputObject $value -Depth 20
    [IO.File]::WriteAllText($path, $text.Substring(0, $match.Groups[1].Index) + $json + $text.Substring($match.Groups[1].Index + $match.Groups[1].Length))
}

function Set-ManifestMutation {
    param([string]$Root, [scriptblock]$Mutation)
    $path = Join-Path $Root 'config/qmbt-2r/preseed-localities.json'
    $value = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path)) -AsHashtable
    & $Mutation $value
    [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $value -Depth 20))
}

& $validator -RepositoryRoot $repositoryRoot
$script:passed++

Assert-Rejected 'Change candidate count' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidate_count = 7 }
}

Assert-Rejected 'Change a candidate canonical ID' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates[0].canonical_id = 'city:us:manual-replacement' }
}

Assert-Rejected 'Change frozen lookup query' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates[2].lookup_query = 'Paris nearby France' }
}

Assert-Rejected 'Expand accepted names after review' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates[3].accepted_names += 'Mexico Metro Area' }
}

Assert-Rejected 'Change audit coordinates' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates[6].latitude = -34.0 }
}

Assert-Rejected 'Switch authorization endpoint' {
    param($root)
    Set-ProtocolContractMutation $root { param($value) $value.endpoint = 'https://hackathon.api.qloo.com/v2/insights' }
}

Assert-Rejected 'Reduce Search depth' {
    param($root)
    Set-ProtocolContractMutation $root { param($value) $value.take = 20 }
}

Assert-Rejected 'Allow Insights' {
    param($root)
    Set-ProtocolContractMutation $root { param($value) $value.insights_allowed = $true }
}

Assert-Rejected 'Allow Seed Commit creation' {
    param($root)
    Set-ProtocolContractMutation $root { param($value) $value.seed_commit_creation_allowed = $true }
}

Assert-Rejected 'Allow result order to select winner' {
    param($root)
    Set-ProtocolContractMutation $root { param($value) $value.result_order_selects_winner = $true }
}

Assert-Rejected 'Allow completed-content retry' {
    param($root)
    Set-ProtocolContractMutation $root { param($value) $value.completed_content_retry_allowed = $true }
}

Assert-Rejected 'Allow automatic city replacement' {
    param($root)
    Set-ProtocolContractMutation $root { param($value) $value.automatic_city_replacement_allowed = $true }
}

Assert-Rejected 'Allow live execution from CI' {
    param($root)
    Set-ProtocolContractMutation $root { param($value) $value.ci_live_execution_allowed = $true }
}

Assert-Rejected 'Change harness endpoint to Insights' {
    param($root)
    $path = Join-Path $root 'scripts/qloo-preseed/16-qmbt-2r-locality-resolution.ps1'
    $text = [IO.File]::ReadAllText($path).Replace('https://hackathon.api.qloo.com/search', 'https://hackathon.api.qloo.com/v2/insights')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Change harness type away from locality' {
    param($root)
    $path = Join-Path $root 'scripts/qloo-preseed/16-qmbt-2r-locality-resolution.ps1'
    $text = [IO.File]::ReadAllText($path).Replace("`$LocalityType = 'urn:entity:locality'", "`$LocalityType = 'urn:entity:place'")
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Change harness take' {
    param($root)
    $path = Join-Path $root 'scripts/qloo-preseed/16-qmbt-2r-locality-resolution.ps1'
    $text = [IO.File]::ReadAllText($path).Replace('$Take = 100', '$Take = 10')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Inject operational location filter' {
    param($root)
    $path = Join-Path $root 'scripts/qloo-preseed/16-qmbt-2r-locality-resolution.ps1'
    Add-Content -LiteralPath $path -Value "`n# filter.location=POINT(0 0)"
}

Assert-Rejected 'Inject popularity-based classifier' {
    param($root)
    $path = Join-Path $root 'scripts/qloo-preseed/16-qmbt-2r-locality-resolution.ps1'
    Add-Content -LiteralPath $path -Value "`n# choose by popularity"
}

Assert-Rejected 'Run live harness in CI' {
    param($root)
    $path = Join-Path $root '.github/workflows/validation.yml'
    Add-Content -LiteralPath $path -Value "`n      - name: Unsafe live lookup`n        shell: pwsh`n        run: ./scripts/qloo-preseed/16-qmbt-2r-locality-resolution.ps1"
}

Assert-Rejected 'Reference Qloo secret in CI' {
    param($root)
    $path = Join-Path $root '.github/workflows/validation.yml'
    Add-Content -LiteralPath $path -Value "`n# QLOO_API_KEY"
}

Assert-Rejected 'Remove post-pass Seed stop gate in prose' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PRESEED_LOCALITY.md'
    $text = [IO.File]::ReadAllText($path).Replace('do **not** create the Seed Commit or compute holdout ranking', 'create the Seed Commit and compute holdout ranking')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Accepted 'Add unrelated safe workflow' {
    param($root)
    $path = Join-Path $root '.github/workflows/unrelated-safe.yml'
    [IO.File]::WriteAllText($path, "name: Safe`non:`n  workflow_dispatch:`njobs:`n  check:`n    runs-on: ubuntu-latest`n    steps:`n      - run: echo safe`n")
}

Write-Output "QMBT-2R pre-Seed locality validator tests passed: $script:passed checks. No live Qloo calls executed."
