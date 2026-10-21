# Dependency-free unit and mutation checks for QMBT-2R pre-Seed locality V2.
# All classifier rows are synthetic. No Qloo request is executed.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$validator = Join-Path $PSScriptRoot 'Test-Qmbt2rPreseedLocalityV2.ps1'
$corePath = Join-Path $repositoryRoot 'scripts/qloo-preseed/Qmbt2rLocalityV2.Core.ps1'
. $corePath

$script:passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)
    if (-not $Condition) { throw "V2 unit check failed: $Name" }
    $script:passed++
}

$manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'config/qmbt-2r/preseed-localities-v2.json') -Raw | ConvertFrom-Json
$ny = @($manifest.candidates)[0]
$singapore = @($manifest.candidates)[5]

$expectedNyUri = 'https://hackathon.api.qloo.com/search?query=New%20York%20City%2C%20New%20York%2C%20United%20States%20of%20America&types=urn%3Aentity%3Alocality&page=1&take=100&sort_by=match'
Assert-True ((New-Qmbt2rV2SearchUri $ny) -ceq $expectedNyUri) 'Frozen URI construction must be exact.'

$cityRow = [pscustomobject]@{
    entity_id = '11111111-1111-1111-1111-111111111111'
    name = 'New York'
    types = @('urn:entity:locality')
    disambiguation = 'New York, New York, United States of America'
}
$broaderRow = [pscustomobject]@{
    entity_id = '22222222-2222-2222-2222-222222222222'
    name = 'New York'
    types = @('urn:entity:locality')
    disambiguation = 'New York, United States of America'
}
$wrongCountryRow = [pscustomobject]@{
    entity_id = '33333333-3333-3333-3333-333333333333'
    name = 'New York'
    types = @('urn:entity:locality')
    disambiguation = 'New York, New York, Canada'
}

$result = Resolve-Qmbt2rV2CandidateIdentity -Candidate $ny -Results @($broaderRow, $cityRow, $wrongCountryRow)
Assert-True ($result.classification -ceq 'LOCALITY_RESOLVED') 'Admin1 rule must resolve the synthetic city row.'
Assert-True ($result.entity_id -ceq $cityRow.entity_id) 'Broader same-name locality must not win.'

$result = Resolve-Qmbt2rV2CandidateIdentity -Candidate $ny -Results @($broaderRow)
Assert-True ($result.classification -ceq 'LOCALITY_UNRESOLVED') 'Missing admin1 interior segment must not qualify.'

$duplicateCityRow = [pscustomobject]@{
    entity_id = $cityRow.entity_id
    name = 'New York'
    types = @('urn:entity:locality')
    disambiguation = 'New York, New York, United States'
}
$result = Resolve-Qmbt2rV2CandidateIdentity -Candidate $ny -Results @($cityRow, $duplicateCityRow)
Assert-True ($result.classification -ceq 'LOCALITY_RESOLVED' -and $result.qualifying_unique_id_count -eq 1) 'Duplicate rows with one ID must collapse.'

$secondQualifyingCity = [pscustomobject]@{
    entity_id = '44444444-4444-4444-4444-444444444444'
    name = 'New York City'
    types = @('urn:entity:locality')
    disambiguation = 'New York City, New York, United States of America'
}
$result = Resolve-Qmbt2rV2CandidateIdentity -Candidate $ny -Results @($cityRow, $secondQualifyingCity)
Assert-True ($result.classification -ceq 'LOCALITY_AMBIGUOUS' -and $result.qualifying_unique_id_count -eq 2) 'Two qualifying IDs must remain ambiguous.'

$sgRow = [pscustomobject]@{
    entity_id = '55555555-5555-5555-5555-555555555555'
    name = 'Singapore'
    types = @('urn:entity:locality')
    disambiguation = 'Singapore, Singapore'
}
$result = Resolve-Qmbt2rV2CandidateIdentity -Candidate $singapore -Results @($sgRow)
Assert-True ($result.classification -ceq 'LOCALITY_RESOLVED') 'City-state exact two-segment path must qualify.'

$sgThreeSegment = [pscustomobject]@{
    entity_id = '66666666-6666-6666-6666-666666666666'
    name = 'Singapore'
    types = @('urn:entity:locality')
    disambiguation = 'Singapore, Central, Singapore'
}
$result = Resolve-Qmbt2rV2CandidateIdentity -Candidate $singapore -Results @($sgThreeSegment)
Assert-True ($result.classification -ceq 'LOCALITY_UNRESOLVED') 'City-state extra interior segment must not qualify.'

Assert-True ((Normalize-Qmbt2rV2IdentityText 'Île-de-France') -ceq 'ile de france') 'Unicode and punctuation normalization must be deterministic.'

$fixtureFiles = @(
    'docs/QMBT_2R_PRESEED_LOCALITY_V2.md',
    'config/qmbt-2r/preseed-localities-v2.json',
    'scripts/qloo-preseed/Qmbt2rLocalityV2.Core.ps1',
    'scripts/qloo-preseed/17-qmbt-2r-locality-resolution-v2.ps1',
    '.github/workflows/validation.yml'
)

function New-V2Fixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('qmbt2r-preseed-v2-' + [guid]::NewGuid().ToString('N'))
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
    $root = New-V2Fixture
    try {
        & $Mutation $root
        $rejected = $false
        try { & $validator -RepositoryRoot $root > $null } catch {
            if ($_.Exception.Message -notlike 'QMBT-2R pre-Seed locality V2 validation failed:*') { throw }
            $rejected = $true
        }
        if (-not $rejected) { throw "Unsafe V2 mutation was accepted: $Name" }
        $script:passed++
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}

function Assert-Accepted {
    param([string]$Name, [scriptblock]$Mutation)
    $root = New-V2Fixture
    try {
        & $Mutation $root
        try { & $validator -RepositoryRoot $root > $null } catch {
            throw "Safe V2 mutation was rejected: $Name. $($_.Exception.Message)"
        }
        $script:passed++
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}

function Set-V2ProtocolContractMutation {
    param([string]$Root, [scriptblock]$Mutation)
    $path = Join-Path $Root 'docs/QMBT_2R_PRESEED_LOCALITY_V2.md'
    $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $match = [regex]::Match($text, '(?ms)^```json\n(.*?)\n```$')
    $value = ConvertFrom-Json -InputObject $match.Groups[1].Value -AsHashtable
    & $Mutation $value
    $json = ConvertTo-Json -InputObject $value -Depth 20
    [IO.File]::WriteAllText($path, $text.Substring(0, $match.Groups[1].Index) + $json + $text.Substring($match.Groups[1].Index + $match.Groups[1].Length))
}

function Set-V2ManifestMutation {
    param([string]$Root, [scriptblock]$Mutation)
    $path = Join-Path $Root 'config/qmbt-2r/preseed-localities-v2.json'
    $value = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path)) -AsHashtable
    & $Mutation $value
    [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $value -Depth 20))
}

& $validator -RepositoryRoot $repositoryRoot
$script:passed++

Assert-Rejected 'Change V2 candidate count' {
    param($root)
    Set-V2ManifestMutation $root { param($value) $value.candidate_count = 7 }
}

Assert-Rejected 'Change frozen admin-aware query' {
    param($root)
    Set-V2ManifestMutation $root { param($value) $value.candidates[0].lookup_query = 'New York City, United States of America' }
}

Assert-Rejected 'Remove admin1 alias' {
    param($root)
    Set-V2ManifestMutation $root { param($value) $value.candidates[6].admin1_aliases = @() }
}

Assert-Rejected 'Turn a normal city into city-state exception' {
    param($root)
    Set-V2ManifestMutation $root { param($value) $value.candidates[0].city_state = $true }
}

Assert-Rejected 'Pin an observed-style entity ID' {
    param($root)
    Set-V2ManifestMutation $root { param($value) $value.candidates[0].expected_entity_id = '77777777-7777-7777-7777-777777777777' }
}

Assert-Rejected 'Allow entity ID allowlists in contract' {
    param($root)
    Set-V2ProtocolContractMutation $root { param($value) $value.observed_entity_id_allowlist_allowed = $true }
}

Assert-Rejected 'Let CI success auto-authorize live lookup' {
    param($root)
    Set-V2ProtocolContractMutation $root { param($value) $value.ci_success_auto_authorizes_live = $true }
}

Assert-Rejected 'Remove explicit human live authorization' {
    param($root)
    Set-V2ProtocolContractMutation $root { param($value) $value.explicit_human_live_authorization_required = $false }
}

Assert-Rejected 'Switch endpoint to Insights' {
    param($root)
    Set-V2ProtocolContractMutation $root { param($value) $value.endpoint = 'https://hackathon.api.qloo.com/v2/insights' }
}

Assert-Rejected 'Change comma segment parser' {
    param($root)
    $path = Join-Path $root 'scripts/qloo-preseed/Qmbt2rLocalityV2.Core.ps1'
    $text = [IO.File]::ReadAllText($path).Replace("`$text.Split(',')", "`$text.Split(';')")
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Change classifier ID in core' {
    param($root)
    $path = Join-Path $root 'scripts/qloo-preseed/Qmbt2rLocalityV2.Core.ps1'
    $text = [IO.File]::ReadAllText($path).Replace('ADMIN1_SEGMENT_IDENTITY_V2', 'FIRST_RESULT_V2')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Run V2 live harness in CI' {
    param($root)
    $path = Join-Path $root '.github/workflows/validation.yml'
    Add-Content -LiteralPath $path -Value "`n      - name: Unsafe V2 live lookup`n        shell: pwsh`n        run: ./scripts/qloo-preseed/17-qmbt-2r-locality-resolution-v2.ps1"
}

Assert-Rejected 'Reference Qloo key in CI' {
    param($root)
    $path = Join-Path $root '.github/workflows/validation.yml'
    Add-Content -LiteralPath $path -Value "`n# QLOO_API_KEY"
}

Assert-Rejected 'Remove post-CI human authorization prose' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PRESEED_LOCALITY_V2.md'
    $text = [IO.File]::ReadAllText($path).Replace('Passing CI does **not** itself authorize a live V2 lookup', 'Passing CI authorizes a live V2 lookup')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Accepted 'Add unrelated safe workflow' {
    param($root)
    $path = Join-Path $root '.github/workflows/unrelated-safe.yml'
    [IO.File]::WriteAllText($path, "name: Safe`non:`n  workflow_dispatch:`njobs:`n  check:`n    runs-on: ubuntu-latest`n    steps:`n      - run: echo safe`n")
}

Write-Output "QMBT-2R pre-Seed locality V2 tests passed: $script:passed checks. No live Qloo calls executed."
