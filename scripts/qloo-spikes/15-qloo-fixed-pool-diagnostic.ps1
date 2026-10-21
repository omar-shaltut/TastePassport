# Qloo fixed-pool API semantics diagnostic.
# NOT confirmatory evidence.
# Protocol: docs/QLOO_FIXED_POOL_DIAGNOSTIC.md
# Includes Pre-execution Amendment 1.

param(
    [string]$City = "Istanbul",
    [string]$CategoryTag = "urn:tag:category:place:art_gallery",
    [int]$Take = 3,
    [string]$OutputRoot = "artifacts/qloo-fixed-pool-diagnostic",
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
$baseUrl = "https://hackathon.api.qloo.com"

if (-not $headers -or -not $headers["X-Api-Key"]) {
    throw "Qloo authentication header is missing. Create `$headers first."
}

if ($Take -ne 3) {
    throw "Diagnostic retrieval is frozen at Take=3."
}

if (-not $Execute) {
    Write-Host "DIAGNOSTIC SAFETY LOCK: no Qloo calls were made."
    Write-Host "Re-run with -Execute only after review and commit."
    exit 0
}

$profiles = @{
    E = @(
        "3A02361C-987B-4F7E-9AAD-071C3853AD92",
        "29B49E3F-A0EC-42C6-A453-38B1C20D8374",
        "439D7BFD-8F08-4248-AEDA-D816DD865C71"
    )
    F = @(
        "DF788007-B5EA-4F29-872B-96BCB8EEC42F",
        "84B18312-3C2B-41A9-863B-89651C2F6A2C",
        "6A4CF4C4-B833-44E1-A426-BB312130C9F3"
    )
}

function Convert-QlooEntities {
    param($Response)

    $rank = 1

    return @(
        foreach ($entity in @($Response.results.entities)) {
            $affinity = $null

            if ($entity.query -and $null -ne $entity.query.affinity) {
                $affinity = [double]$entity.query.affinity
            }

            [PSCustomObject]@{
                Rank     = $rank
                EntityId = [string]$entity.entity_id
                Name     = [string]$entity.name
                Affinity = $affinity
            }

            $rank++
        }
    )
}

function Invoke-SampleRetrieval {
    param(
        [Parameter(Mandatory)]
        [string]$Condition
    )

    $tagParam = [uri]::EscapeDataString($CategoryTag)
    $cityParam = [uri]::EscapeDataString($City)

    $url = (
        "$baseUrl/v2/insights" +
        "?filter.type=urn%3Aentity%3Aplace" +
        "&filter.tags=$tagParam" +
        "&filter.location.query=$cityParam" +
        "&filter.location.radius=0"
    )

    if ($Condition -ne "UNSIGNALED_QLOO_BASELINE") {
        $seedParam = $profiles[$Condition] -join ","
        $url += "&signal.interests.entities=$seedParam"
    }

    $url += "&take=$Take"

    $response = Invoke-RestMethod `
        -Uri $url `
        -Headers $headers `
        -Method Get

    return [PSCustomObject]@{
        Condition  = $Condition
        RequestUrl = $url
        Results    = @(Convert-QlooEntities -Response $response)
    }
}

function Invoke-SingleEntityScore {
    param(
        [Parameter(Mandatory)]
        [string]$EntityId,

        [Parameter(Mandatory)]
        [ValidateSet("E", "F")]
        [string]$Condition,

        [Parameter(Mandatory)]
        [ValidateSet(1, 2)]
        [int]$Repeat
    )

    $cityParam = [uri]::EscapeDataString($City)
    $seedParam = $profiles[$Condition] -join ","

    $url = (
        "$baseUrl/v2/insights" +
        "?filter.type=urn%3Aentity%3Aplace" +
        "&filter.results.entities=$EntityId" +
        "&filter.location.query=$cityParam" +
        "&filter.location.radius=0" +
        "&signal.interests.entities=$seedParam" +
        "&take=1"
    )

    $response = Invoke-RestMethod `
        -Uri $url `
        -Headers $headers `
        -Method Get

    $results = @(Convert-QlooEntities -Response $response)

    $returned = $null
    if ($results.Count -eq 1) {
        $returned = $results[0]
    }

    return [PSCustomObject]@{
        RequestedEntityId = $EntityId
        Condition         = $Condition
        Repeat            = $Repeat
        RequestUrl        = $url
        ReturnedCount     = $results.Count
        ReturnedEntityId  = if ($returned) { $returned.EntityId } else { $null }
        ReturnedName      = if ($returned) { $returned.Name } else { $null }
        Affinity          = if ($returned) { $returned.Affinity } else { $null }
        IdentityMatch     = (
            $results.Count -eq 1 -and
            $returned.EntityId -eq $EntityId
        )
    }
}

function Invoke-BaselineFixedPool {
    param(
        [Parameter(Mandatory)]
        [string[]]$EntityIds,

        [Parameter(Mandatory)]
        [ValidateSet(1, 2)]
        [int]$Repeat
    )

    $cityParam = [uri]::EscapeDataString($City)
    $poolParam = $EntityIds -join ","

    $url = (
        "$baseUrl/v2/insights" +
        "?filter.type=urn%3Aentity%3Aplace" +
        "&filter.results.entities=$poolParam" +
        "&filter.location.query=$cityParam" +
        "&filter.location.radius=0" +
        "&take=$($EntityIds.Count)"
    )

    $response = Invoke-RestMethod `
        -Uri $url `
        -Headers $headers `
        -Method Get

    $results = @(Convert-QlooEntities -Response $response)

    return [PSCustomObject]@{
        Repeat      = $Repeat
        RequestUrl  = $url
        Results     = $results
        ReturnedIds = @($results | ForEach-Object { $_.EntityId })
    }
}

function Test-SameEntitySet {
    param(
        [string[]]$Expected,
        [string[]]$Actual
    )

    if ($Expected.Count -ne $Actual.Count) {
        return $false
    }

    $expectedSorted = @($Expected | Sort-Object)
    $actualSorted = @($Actual | Sort-Object)

    return (($expectedSorted -join "|") -eq ($actualSorted -join "|"))
}

function Get-AffinityRanking {
    param(
        [object[]]$Observations,
        [string]$Condition,
        [int]$Repeat
    )

    return @(
        $Observations |
        Where-Object {
            $_.Condition -eq $Condition -and
            $_.Repeat -eq $Repeat
        } |
        Sort-Object `
            @{ Expression = "Affinity"; Descending = $true },
            @{ Expression = "RequestedEntityId"; Descending = $false } |
        ForEach-Object { $_.RequestedEntityId }
    )
}

$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")

if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    $resolvedOutputRoot = $OutputRoot
} else {
    $resolvedOutputRoot = Join-Path (Get-Location).Path $OutputRoot
}

$runDir = Join-Path $resolvedOutputRoot $runId
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Write-Host "Collecting frozen diagnostic sample..."

$retrievalE = Invoke-SampleRetrieval -Condition "E"
$retrievalF = Invoke-SampleRetrieval -Condition "F"
$retrievalBaseline = Invoke-SampleRetrieval `
    -Condition "UNSIGNALED_QLOO_BASELINE"

$retrievals = @(
    $retrievalE,
    $retrievalF,
    $retrievalBaseline
)

foreach ($retrieval in $retrievals) {
    if ($retrieval.Results.Count -ne $Take) {
        throw (
            "Diagnostic sample retrieval for {0} returned {1}, expected {2}." -f
            $retrieval.Condition,
            $retrieval.Results.Count,
            $Take
        )
    }
}

# Full de-duplicated union preserving source order:
# E, then F, then UNSIGNALED_QLOO_BASELINE.
$seenIds = @{}
$sample = @()

foreach ($retrieval in $retrievals) {
    foreach ($item in $retrieval.Results) {
        if (-not $seenIds.ContainsKey($item.EntityId)) {
            $seenIds[$item.EntityId] = $true

            $sample += [PSCustomObject]@{
                SourceCondition = $retrieval.Condition
                SourceRank      = $item.Rank
                EntityId        = $item.EntityId
                Name            = $item.Name
            }
        }
    }
}

$sampleIds = @(
    $sample |
    ForEach-Object { $_.EntityId }
)

if ($sampleIds.Count -lt 3 -or $sampleIds.Count -gt 9) {
    throw "Frozen diagnostic union must contain between 3 and 9 unique entities."
}

Write-Host "Frozen diagnostic pool: $($sampleIds.Count) unique entities"

Write-Host "TEST A: personalized per-entity scoring..."

$observations = @()

foreach ($entity in $sample) {
    foreach ($condition in @("E", "F")) {
        foreach ($repeat in @(1, 2)) {
            Write-Host (
                "  {0} / {1} / repeat {2}" -f
                $entity.Name,
                $condition,
                $repeat
            )

            $observations += Invoke-SingleEntityScore `
                -EntityId $entity.EntityId `
                -Condition $condition `
                -Repeat $repeat
        }
    }
}

$identityFailures = @(
    $observations |
    Where-Object { -not $_.IdentityMatch }
)

$affinityFailures = @(
    $observations |
    Where-Object { $null -eq $_.Affinity }
)

$rankingChecks = @()

foreach ($condition in @("E", "F")) {
    $rank1 = @(
        Get-AffinityRanking `
            -Observations $observations `
            -Condition $condition `
            -Repeat 1
    )

    $rank2 = @(
        Get-AffinityRanking `
            -Observations $observations `
            -Condition $condition `
            -Repeat 2
    )

    $sameRanking = (
        $rank1.Count -eq $sampleIds.Count -and
        $rank2.Count -eq $sampleIds.Count -and
        (($rank1 -join "|") -eq ($rank2 -join "|"))
    )

    $rankingChecks += [PSCustomObject]@{
        Condition       = $condition
        Repeat1Ranking  = $rank1
        Repeat2Ranking  = $rank2
        RankingStable   = $sameRanking
    }
}

$personalizedRankingFailures = @(
    $rankingChecks |
    Where-Object { -not $_.RankingStable }
)

$testAPass = (
    $identityFailures.Count -eq 0 -and
    $affinityFailures.Count -eq 0 -and
    $personalizedRankingFailures.Count -eq 0
)

Write-Host "TEST B: unsignaled baseline fixed-pool ranking..."

$baseline1 = Invoke-BaselineFixedPool `
    -EntityIds $sampleIds `
    -Repeat 1

$baseline2 = Invoke-BaselineFixedPool `
    -EntityIds $sampleIds `
    -Repeat 2

$baseline1ExactSet = Test-SameEntitySet `
    -Expected $sampleIds `
    -Actual $baseline1.ReturnedIds

$baseline2ExactSet = Test-SameEntitySet `
    -Expected $sampleIds `
    -Actual $baseline2.ReturnedIds

$baselineStableOrder = (
    $baseline1.ReturnedIds.Count -eq $sampleIds.Count -and
    $baseline2.ReturnedIds.Count -eq $sampleIds.Count -and
    (($baseline1.ReturnedIds -join "|") -eq ($baseline2.ReturnedIds -join "|"))
)

$testBPass = (
    $baseline1ExactSet -and
    $baseline2ExactSet -and
    $baselineStableOrder
)

$decision = if ($testAPass -and $testBPass) {
    "PASS_COMPLETE_FIXED_POOL_RANKING_VIABLE"
} else {
    "FAIL_CURRENT_FIXED_POOL_STRATEGY_NOT_VALIDATED"
}

$gitCommit = $null

try {
    $gitCommit = (git rev-parse HEAD 2>$null).Trim()
} catch {
    $gitCommit = $null
}

$record = [PSCustomObject]@{
    RunId                    = $runId
    Protocol                 = "QLOO_FIXED_POOL_DIAGNOSTIC"
    ProtocolAmendment        = "PRE_EXECUTION_AMENDMENT_1"
    EvidenceClass            = "DIAGNOSTIC_NOT_CONFIRMATORY"
    GitCommit                = $gitCommit
    City                     = $City
    CategoryTag              = $CategoryTag
    RetrievalTake            = $Take
    FrozenSampleCount        = $sampleIds.Count
    FrozenSample             = $sample
    SampleRetrievals         = $retrievals
    TestA = [PSCustomObject]@{
        Name                   = "PERSONALIZED_PER_ENTITY_SCORING"
        Pass                   = $testAPass
        IdentityFailureCount   = $identityFailures.Count
        AffinityFailureCount   = $affinityFailures.Count
        RankingFailureCount    = $personalizedRankingFailures.Count
        RankingChecks          = $rankingChecks
        Observations           = $observations
    }
    TestB = [PSCustomObject]@{
        Name                   = "UNSIGNALED_BASELINE_FIXED_POOL"
        Pass                   = $testBPass
        Repeat1ExactEntitySet  = $baseline1ExactSet
        Repeat2ExactEntitySet  = $baseline2ExactSet
        StableOrdering         = $baselineStableOrder
        Repeat1                = $baseline1
        Repeat2                = $baseline2
    }
    Decision                 = $decision
}

$json = $record | ConvertTo-Json -Depth 14

[System.IO.File]::WriteAllText(
    (Join-Path $runDir "diagnostic-result.json"),
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host ""
Write-Host "DIAGNOSTIC COMPLETE"
Write-Host "Run directory: $runDir"
Write-Host "Frozen pool size: $($sampleIds.Count)"
Write-Host "Test A personalized scoring: $testAPass"
Write-Host "Test B baseline fixed pool: $testBPass"
Write-Host "Decision: $decision"
