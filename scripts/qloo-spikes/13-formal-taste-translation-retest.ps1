# TastePassport - Formal Taste Translation Retest
# Confirmatory-by-default execution harness for the pre-registered protocol.
# Pair 2 and Pair 3 x Istanbul and London.
# No agent loop, compliance logic, FoodSignalShare, or post-hoc curation.

param(
    [string[]]$PairIds = @("2", "3"),
    [string[]]$Cities = @("Istanbul", "London"),
    [int]$CategoryTake = 7,
    [string]$OutputRoot = "artifacts/taste-translation-retest"
)

$ErrorActionPreference = "Stop"
$baseUrl = "https://hackathon.api.qloo.com"

if (-not $headers -or -not $headers["X-Api-Key"]) {
    throw "Qloo authentication header is missing. Create `$headers first."
}

if ($CategoryTake -ne 7) {
    throw "Formal retest protocol requires CategoryTake=7."
}

$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")

if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    $resolvedOutputRoot = $OutputRoot
} else {
    $resolvedOutputRoot = Join-Path (Get-Location).Path $OutputRoot
}

$runDir = Join-Path $resolvedOutputRoot $runId

$categories = @(
    [PSCustomObject]@{
        Id   = "museum"
        Name = "Museum"
        Tag  = "urn:tag:category:place:museum"
    },
    [PSCustomObject]@{
        Id   = "art_gallery"
        Name = "Art gallery"
        Tag  = "urn:tag:category:place:art_gallery"
    },
    [PSCustomObject]@{
        Id   = "book_store"
        Name = "Book store"
        Tag  = "urn:tag:category:place:book_store"
    }
)

$profiles = @{
    E = [PSCustomObject]@{
        PairId = "2"
        ProfileId = "E"
        Seeds = @(
            [PSCustomObject]@{
                Name = "Blade Runner 2049"
                Type = "urn:entity:movie"
                EntityId = "3A02361C-987B-4F7E-9AAD-071C3853AD92"
            },
            [PSCustomObject]@{
                Name = "Tesla"
                Type = "urn:entity:brand"
                EntityId = "29B49E3F-A0EC-42C6-A453-38B1C20D8374"
            },
            [PSCustomObject]@{
                Name = "Snow Crash"
                Type = "urn:entity:book"
                EntityId = "439D7BFD-8F08-4248-AEDA-D816DD865C71"
            }
        )
    }

    F = [PSCustomObject]@{
        PairId = "2"
        ProfileId = "F"
        Seeds = @(
            [PSCustomObject]@{
                Name = "The Grand Budapest Hotel"
                Type = "urn:entity:movie"
                EntityId = "DF788007-B5EA-4F29-872B-96BCB8EEC42F"
            },
            [PSCustomObject]@{
                Name = "Gucci"
                Type = "urn:entity:brand"
                EntityId = "84B18312-3C2B-41A9-863B-89651C2F6A2C"
            },
            [PSCustomObject]@{
                Name = "The Great Gatsby"
                Type = "urn:entity:book"
                EntityId = "6A4CF4C4-B833-44E1-A426-BB312130C9F3"
            }
        )
    }

    G = [PSCustomObject]@{
        PairId = "3"
        ProfileId = "G"
        Seeds = @(
            [PSCustomObject]@{
                Name = "Into the Wild"
                Type = "urn:entity:movie"
                EntityId = "E4FD5F16-4499-4431-9CA9-115625146109"
            },
            [PSCustomObject]@{
                Name = "Patagonia"
                Type = "urn:entity:brand"
                EntityId = "DB4CE34E-3A63-4947-946F-9D52502C5762"
            },
            [PSCustomObject]@{
                Name = "Walden"
                Type = "urn:entity:book"
                EntityId = "1010C15E-3EFA-47D6-911C-1B25026906B5"
                Disambiguation = "1854, Henry David Thoreau"
            }
        )
    }

    H = [PSCustomObject]@{
        PairId = "3"
        ProfileId = "H"
        Seeds = @(
            [PSCustomObject]@{
                Name = "Lost in Translation"
                Type = "urn:entity:movie"
                EntityId = "603C7E42-C952-45CB-8B6F-3B803FEFB2F7"
            },
            [PSCustomObject]@{
                Name = "Aesop"
                Type = "urn:entity:brand"
                EntityId = "32F867B9-E6DF-44C3-BCE4-40160C7ED5E4"
            },
            [PSCustomObject]@{
                Name = "Norwegian Wood"
                Type = "urn:entity:book"
                EntityId = "AB5E9CA9-E7A4-4D68-A641-FE2276C1C103"
                Disambiguation = "1987, Haruki Murakami"
            }
        )
    }
}

$pairs = @{
    "2" = @("E", "F")
    "3" = @("G", "H")
}

foreach ($pairId in $PairIds) {
    if (-not $pairs.ContainsKey($pairId)) {
        throw "Unsupported PairId: $pairId. Formal confirmatory harness supports PairIds 2 and 3."
    }
}

foreach ($city in $Cities) {
    if ($city -notin @("Istanbul", "London")) {
        throw "Unsupported city: $city. Formal protocol freezes Istanbul and London."
    }
}

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

function Write-Utf8Json {
    param(
        $Value,
        [string]$Path,
        [int]$Depth = 12
    )

    $json = $Value | ConvertTo-Json -Depth $Depth
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-ProfileSeedIds {
    param($Profile)

    return @(
        $Profile.Seeds |
        ForEach-Object { [string]$_.EntityId }
    )
}

function Convert-QlooPlace {
    param(
        $Place,
        [int]$Rank
    )

    $affinity = $null
    if ($Place.query -and $null -ne $Place.query.affinity) {
        $affinity = [double]$Place.query.affinity
    }

    $address = $null
    if ($Place.properties -and $Place.properties.address) {
        $address = [string]$Place.properties.address
    }

    $primaryGenre = $null
    if ($Place.properties -and $Place.properties.primary_genre) {
        $primaryGenre = [string]$Place.properties.primary_genre
    }

    $tags = @()
    if ($Place.tags) {
        $tags = @(
            $Place.tags |
            ForEach-Object {
                [PSCustomObject]@{
                    Id   = if ($_.tag_id) { [string]$_.tag_id } elseif ($_.id) { [string]$_.id } else { $null }
                    Name = if ($_.name) { [string]$_.name } else { $null }
                }
            }
        )
    }

    return [PSCustomObject]@{
        Rank         = $Rank
        EntityId     = [string]$Place.entity_id
        Name         = [string]$Place.name
        Affinity     = $affinity
        Address      = $address
        PrimaryGenre = $primaryGenre
        Tags         = $tags
    }
}

function Convert-QlooResponse {
    param($Response)

    $output = @()
    $rank = 1

    foreach ($place in @($Response.results.entities)) {
        $output += Convert-QlooPlace -Place $place -Rank $rank
        $rank++
    }

    return $output
}

function Invoke-QlooCategoryRetrieval {
    param(
        $Profile,
        $Category,
        [string]$City,
        [int]$Take
    )

    $seedIds = Get-ProfileSeedIds -Profile $Profile
    $seedParam = $seedIds -join ","
    $tagParam = [uri]::EscapeDataString([string]$Category.Tag)
    $cityParam = [uri]::EscapeDataString($City)

    $url = (
        "$baseUrl/v2/insights" +
        "?filter.type=urn%3Aentity%3Aplace" +
        "&signal.interests.entities=$seedParam" +
        "&filter.tags=$tagParam" +
        "&filter.location.query=$cityParam" +
        "&filter.location.radius=0" +
        "&take=$Take"
    )

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    $results = @(Convert-QlooResponse -Response $response)

    return [PSCustomObject]@{
        RequestUrl = $url
        Results    = $results
    }
}

function Invoke-QlooFixedPool {
    param(
        $Profile,
        [array]$EntityIds,
        [string]$City,
        [switch]$Unsignaled
    )

    $ids = @(
        $EntityIds |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ } |
        Select-Object -Unique
    )

    if ($ids.Count -lt 1) {
        throw "Fixed candidate pool is empty."
    }

    if ($ids.Count -gt 50) {
        throw "Fixed candidate pool exceeds Qloo take limit: $($ids.Count)."
    }

    $poolParam = $ids -join ","
    $cityParam = [uri]::EscapeDataString($City)

    $url = (
        "$baseUrl/v2/insights" +
        "?filter.type=urn%3Aentity%3Aplace" +
        "&filter.results.entities=$poolParam" +
        "&filter.location.query=$cityParam" +
        "&filter.location.radius=0"
    )

    if (-not $Unsignaled) {
        if (-not $Profile) {
            throw "Personalized fixed-pool scoring requires a profile."
        }

        $seedIds = Get-ProfileSeedIds -Profile $Profile
        $seedParam = $seedIds -join ","
        $url += "&signal.interests.entities=$seedParam"
    }

    $url += "&take=$($ids.Count)"

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    $results = @(Convert-QlooResponse -Response $response)

    return [PSCustomObject]@{
        Condition  = if ($Unsignaled) { "UNSIGNALED_QLOO_BASELINE" } else { "PERSONALIZED" }
        RequestUrl = $url
        Results    = $results
    }
}

function Get-EntityIds {
    param([array]$Items)

    return @(
        $Items |
        ForEach-Object { [string]$_.EntityId } |
        Where-Object { $_ } |
        Select-Object -Unique
    )
}

function Get-Jaccard {
    param(
        [array]$A,
        [array]$B
    )

    $aIds = @(Get-EntityIds -Items $A)
    $bIds = @(Get-EntityIds -Items $B)

    $shared = @(
        $aIds |
        Where-Object { $bIds -contains $_ } |
        Select-Object -Unique
    )

    $union = @(
        $aIds + $bIds |
        Select-Object -Unique
    )

    if ($union.Count -eq 0) {
        return 0.0
    }

    return [double]($shared.Count / $union.Count)
}

function Get-TopKOverlap {
    param(
        [array]$A,
        [array]$B,
        [int]$K
    )

    if ($K -lt 1) {
        throw "K must be at least 1."
    }

    $aTop = @(
        $A |
        Select-Object -First $K |
        ForEach-Object { [string]$_.EntityId }
    )

    $bTop = @(
        $B |
        Select-Object -First $K |
        ForEach-Object { [string]$_.EntityId }
    )

    $denominator = [math]::Max(
        1,
        [math]::Min(
            $K,
            [math]::Max($aTop.Count, $bTop.Count)
        )
    )

    $shared = @(
        $aTop |
        Where-Object { $bTop -contains $_ } |
        Select-Object -Unique
    )

    return [double]($shared.Count / $denominator)
}

function Get-PearsonCorrelation {
    param(
        [double[]]$X,
        [double[]]$Y
    )

    if ($X.Count -ne $Y.Count) {
        throw "Pearson vectors must have equal length."
    }

    if ($X.Count -lt 2) {
        return $null
    }

    $meanX = ($X | Measure-Object -Average).Average
    $meanY = ($Y | Measure-Object -Average).Average

    $numerator = 0.0
    $sumSqX = 0.0
    $sumSqY = 0.0

    for ($i = 0; $i -lt $X.Count; $i++) {
        $dx = $X[$i] - $meanX
        $dy = $Y[$i] - $meanY

        $numerator += ($dx * $dy)
        $sumSqX += ($dx * $dx)
        $sumSqY += ($dy * $dy)
    }

    $denominator = [math]::Sqrt($sumSqX * $sumSqY)

    if ($denominator -eq 0.0) {
        return $null
    }

    return [double]($numerator / $denominator)
}

function Get-SpearmanCorrelation {
    param(
        [array]$A,
        [array]$B
    )

    $aRank = @{}
    $bRank = @{}

    foreach ($item in $A) {
        $aRank[[string]$item.EntityId] = [double]$item.Rank
    }

    foreach ($item in $B) {
        $bRank[[string]$item.EntityId] = [double]$item.Rank
    }

    $sharedIds = @(
        $aRank.Keys |
        Where-Object { $bRank.ContainsKey($_) }
    )

    if ($sharedIds.Count -lt 2) {
        return $null
    }

    $x = @()
    $y = @()

    foreach ($id in $sharedIds) {
        $x += [double]$aRank[$id]
        $y += [double]$bRank[$id]
    }

    return Get-PearsonCorrelation -X $x -Y $y
}

function Get-AffinityComparison {
    param(
        [array]$A,
        [array]$B
    )

    $aAffinity = @{}
    $bAffinity = @{}

    foreach ($item in $A) {
        if ($null -ne $item.Affinity) {
            $aAffinity[[string]$item.EntityId] = [double]$item.Affinity
        }
    }

    foreach ($item in $B) {
        if ($null -ne $item.Affinity) {
            $bAffinity[[string]$item.EntityId] = [double]$item.Affinity
        }
    }

    $sharedIds = @(
        $aAffinity.Keys |
        Where-Object { $bAffinity.ContainsKey($_) }
    )

    if ($sharedIds.Count -eq 0) {
        return [PSCustomObject]@{
            SharedAffinityCount = 0
            PearsonAffinity     = $null
            DeltaMean           = $null
            DeltaStdDev         = $null
        }
    }

    $x = @()
    $y = @()
    $deltas = @()

    foreach ($id in $sharedIds) {
        $aValue = [double]($aAffinity[$id])
        $bValue = [double]($bAffinity[$id])

        $x += $aValue
        $y += $bValue
        $deltas += ($aValue - $bValue)
    }

    $mean = ($deltas | Measure-Object -Average).Average

    $stdDev = $null
    if ($deltas.Count -gt 1) {
        $sumSq = 0.0

        foreach ($delta in $deltas) {
            $sumSq += [math]::Pow(($delta - $mean), 2)
        }

        $stdDev = [math]::Sqrt($sumSq / $deltas.Count)
    }

    return [PSCustomObject]@{
        SharedAffinityCount = $sharedIds.Count
        PearsonAffinity     = Get-PearsonCorrelation -X $x -Y $y
        DeltaMean           = [double]$mean
        DeltaStdDev         = $stdDev
    }
}

function Test-SameEntitySet {
    param(
        [array]$ExpectedIds,
        [array]$ActualItems
    )

    $expected = @(
        $ExpectedIds |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ } |
        Sort-Object -Unique
    )

    $actual = @(
        $ActualItems |
        ForEach-Object { [string]$_.EntityId } |
        Where-Object { $_ } |
        Sort-Object -Unique
    )

    if ($expected.Count -ne $actual.Count) {
        return $false
    }

    return (@(
        $expected |
        Where-Object { $actual -notcontains $_ }
    ).Count -eq 0)
}

function Get-RetrievalComparison {
    param(
        [array]$A,
        [array]$B,
        [string]$CategoryId
    )

    $aIds = @(Get-EntityIds -Items $A)
    $bIds = @(Get-EntityIds -Items $B)

    $shared = @(
        $aIds |
        Where-Object { $bIds -contains $_ } |
        Select-Object -Unique
    )

    $union = @(
        $aIds + $bIds |
        Select-Object -Unique
    )

    return [PSCustomObject]@{
        CategoryId     = $CategoryId
        CandidateCountA = $aIds.Count
        CandidateCountB = $bIds.Count
        SharedCount     = $shared.Count
        UnionSize       = $union.Count
        Jaccard         = Get-Jaccard -A $A -B $B
        Top7Overlap     = Get-TopKOverlap -A $A -B $B -K 7
    }
}

function Get-FixedPoolComparison {
    param(
        [array]$A,
        [array]$B,
        [int]$PoolSize
    )

    $affinity = Get-AffinityComparison -A $A -B $B

    return [PSCustomObject]@{
        PoolSize             = $PoolSize
        Top10Overlap         = Get-TopKOverlap -A $A -B $B -K 10
        SpearmanRank         = Get-SpearmanCorrelation -A $A -B $B
        PearsonAffinity      = $affinity.PearsonAffinity
        SharedAffinityCount  = $affinity.SharedAffinityCount
        AffinityDeltaMean    = $affinity.DeltaMean
        AffinityDeltaStdDev  = $affinity.DeltaStdDev
    }
}

function Select-BlindPlaceFields {
    param([array]$Items)

    return @(
        $Items |
        Select-Object -First 10 |
        ForEach-Object {
            [PSCustomObject]@{
                Name    = $_.Name
                Address = $_.Address
            }
        }
    )
}

function New-SemanticBlindPacket {
    param(
        [string]$PairId,
        [string]$City,
        $ProfileA,
        $ProfileB,
        [array]$RankingA,
        [array]$RankingB
    )

    $lists = @(
        [PSCustomObject]@{
            ProfileId = $ProfileA.ProfileId
            Places    = @(Select-BlindPlaceFields -Items $RankingA)
        },
        [PSCustomObject]@{
            ProfileId = $ProfileB.ProfileId
            Places    = @(Select-BlindPlaceFields -Items $RankingB)
        }
    ) | Sort-Object { Get-Random }

    $publicLists = @()
    $answerKey = @()

    for ($i = 0; $i -lt $lists.Count; $i++) {
        $label = if ($i -eq 0) { "X" } else { "Y" }

        $publicLists += [PSCustomObject]@{
            Label  = $label
            Places = $lists[$i].Places
        }

        $answerKey += [PSCustomObject]@{
            Label     = $label
            ProfileId = $lists[$i].ProfileId
        }
    }

    $packet = [PSCustomObject]@{
        EvaluationType = "PROFILE_ASSIGNMENT"
        PairId          = $PairId
        City            = $City
        Profiles        = @(
            [PSCustomObject]@{
                ProfileId = $ProfileA.ProfileId
                Seeds = @(
                    $ProfileA.Seeds |
                    Select-Object Name, Type, Disambiguation
                )
            },
            [PSCustomObject]@{
                ProfileId = $ProfileB.ProfileId
                Seeds = @(
                    $ProfileB.Seeds |
                    Select-Object Name, Type, Disambiguation
                )
            }
        )
        Lists = $publicLists
        EvaluatorInstructions = @(
            "Assign List X and List Y to the two profiles.",
            "Report confidence as low, medium, or high.",
            "Explain the taste-fit rationale.",
            "State whether the distinction is meaningfully taste-related or mainly generic/category-driven."
        )
    }

    return [PSCustomObject]@{
        Packet    = $packet
        AnswerKey = $answerKey
    }
}

function New-BaselineBlindPacket {
    param(
        [string]$PairId,
        [string]$City,
        $Profile,
        [array]$Personalized,
        [array]$Baseline
    )

    $lists = @(
        [PSCustomObject]@{
            Condition = "PERSONALIZED"
            Places    = @(Select-BlindPlaceFields -Items $Personalized)
        },
        [PSCustomObject]@{
            Condition = "UNSIGNALED_QLOO_BASELINE"
            Places    = @(Select-BlindPlaceFields -Items $Baseline)
        }
    ) | Sort-Object { Get-Random }

    $publicLists = @()
    $answerKey = @()

    for ($i = 0; $i -lt $lists.Count; $i++) {
        $label = if ($i -eq 0) { "X" } else { "Y" }

        $publicLists += [PSCustomObject]@{
            Label  = $label
            Places = $lists[$i].Places
        }

        $answerKey += [PSCustomObject]@{
            Label     = $label
            Condition = $lists[$i].Condition
        }
    }

    $packet = [PSCustomObject]@{
        EvaluationType = "BASELINE_ADVANTAGE"
        PairId          = $PairId
        City            = $City
        ProfileId       = $Profile.ProfileId
        Seeds            = @(
            $Profile.Seeds |
            Select-Object Name, Type, Disambiguation
        )
        Lists = $publicLists
        EvaluatorInstructions = @(
            "Choose which list better fits the supplied taste profile.",
            "Report confidence as low, medium, or high.",
            "Explain the taste-fit rationale.",
            "State whether any advantage is meaningfully taste-related or mainly generic/category-driven."
        )
    }

    return [PSCustomObject]@{
        Packet    = $packet
        AnswerKey = $answerKey
    }
}

function Get-BaselineRankingComparison {
    param(
        [array]$Personalized,
        [array]$Baseline
    )

    $personalRank = @{}
    $baselineRank = @{}

    foreach ($item in $Personalized) {
        $personalRank[[string]$item.EntityId] = [int]$item.Rank
    }

    foreach ($item in $Baseline) {
        $baselineRank[[string]$item.EntityId] = [int]$item.Rank
    }

    $sharedIds = @(
        $personalRank.Keys |
        Where-Object { $baselineRank.ContainsKey($_) }
    )

    $rankChanges = @(
        foreach ($id in $sharedIds) {
            [PSCustomObject]@{
                EntityId         = $id
                PersonalizedRank = $personalRank[$id]
                BaselineRank     = $baselineRank[$id]
                RankDelta        = ($personalRank[$id] - $baselineRank[$id])
            }
        }
    )

    return [PSCustomObject]@{
        SharedCount       = $sharedIds.Count
        Top10Overlap      = Get-TopKOverlap -A $Personalized -B $Baseline -K 10
        SpearmanRank      = Get-SpearmanCorrelation -A $Personalized -B $Baseline
        MeanAbsRankDelta  = if ($rankChanges.Count -gt 0) {
            [double]((
                $rankChanges |
                ForEach-Object { [math]::Abs([double]$_.RankDelta) } |
                Measure-Object -Average
            ).Average)
        } else {
            $null
        }
        RankChanges = $rankChanges
    }
}
function Invoke-FormalRetestCase {
    param(
        [string]$PairId,
        [string]$City
    )

    $profileIds = @($pairs[$PairId])

    if ($profileIds.Count -ne 2) {
        throw "Pair $PairId must contain exactly two profiles."
    }

    $profileA = $profiles[$profileIds[0]]
    $profileB = $profiles[$profileIds[1]]

    $caseId = ("pair{0}-{1}" -f $PairId, $City.ToLowerInvariant())
    $caseDir = Join-Path $runDir $caseId
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null

    Write-Host ""
    Write-Host "CASE $caseId"

    $retrievalRecords = @()
    $retrievalMetrics = @()
    $poolIds = @()

    foreach ($category in $categories) {
        Write-Host ("  Retrieval {0} / {1}" -f $category.Name, $profileA.ProfileId)
        $retrievalA = Invoke-QlooCategoryRetrieval `
            -Profile $profileA `
            -Category $category `
            -City $City `
            -Take $CategoryTake

        Write-Host ("  Retrieval {0} / {1}" -f $category.Name, $profileB.ProfileId)
        $retrievalB = Invoke-QlooCategoryRetrieval `
            -Profile $profileB `
            -Category $category `
            -City $City `
            -Take $CategoryTake

        if ($retrievalA.Results.Count -ne $CategoryTake) {
            throw "$caseId / $($category.Id) / $($profileA.ProfileId): expected $CategoryTake candidates; received $($retrievalA.Results.Count)."
        }

        if ($retrievalB.Results.Count -ne $CategoryTake) {
            throw "$caseId / $($category.Id) / $($profileB.ProfileId): expected $CategoryTake candidates; received $($retrievalB.Results.Count)."
        }

        $retrievalRecords += [PSCustomObject]@{
            CategoryId = $category.Id
            CategoryName = $category.Name
            ProfileId = $profileA.ProfileId
            RequestUrl = $retrievalA.RequestUrl
            Results = $retrievalA.Results
        }

        $retrievalRecords += [PSCustomObject]@{
            CategoryId = $category.Id
            CategoryName = $category.Name
            ProfileId = $profileB.ProfileId
            RequestUrl = $retrievalB.RequestUrl
            Results = $retrievalB.Results
        }

        $retrievalMetrics += Get-RetrievalComparison `
            -A $retrievalA.Results `
            -B $retrievalB.Results `
            -CategoryId $category.Id

        $poolIds += @(Get-EntityIds -Items $retrievalA.Results)
        $poolIds += @(Get-EntityIds -Items $retrievalB.Results)
    }

    $poolIds = @(
        $poolIds |
        Where-Object { $_ } |
        Select-Object -Unique
    )

    if ($poolIds.Count -lt 10) {
        throw "${caseId}: frozen candidate pool has fewer than 10 candidates: $($poolIds.Count)."
    }

    if ($poolIds.Count -gt 42) {
        throw "${caseId}: candidate pool exceeds theoretical pre-registered maximum of 42: $($poolIds.Count)."
    }

    Write-Host ("  Frozen pool size: {0}" -f $poolIds.Count)

    $fixedA = Invoke-QlooFixedPool `
        -Profile $profileA `
        -EntityIds $poolIds `
        -City $City

    $fixedB = Invoke-QlooFixedPool `
        -Profile $profileB `
        -EntityIds $poolIds `
        -City $City

    $baseline = Invoke-QlooFixedPool `
        -Profile $null `
        -EntityIds $poolIds `
        -City $City `
        -Unsignaled

    if (-not (Test-SameEntitySet -ExpectedIds $poolIds -ActualItems $fixedA.Results)) {
        throw "${caseId}: personalized fixed-pool response for $($profileA.ProfileId) differs from frozen pool."
    }

    if (-not (Test-SameEntitySet -ExpectedIds $poolIds -ActualItems $fixedB.Results)) {
        throw "${caseId}: personalized fixed-pool response for $($profileB.ProfileId) differs from frozen pool."
    }

    if (-not (Test-SameEntitySet -ExpectedIds $poolIds -ActualItems $baseline.Results)) {
        throw "${caseId}: unsignaled baseline response differs from frozen pool."
    }

    $missingAffinityA = @(
        $fixedA.Results |
        Where-Object { $null -eq $_.Affinity }
    ).Count

    $missingAffinityB = @(
        $fixedB.Results |
        Where-Object { $null -eq $_.Affinity }
    ).Count

    if ($missingAffinityA -gt 0 -or $missingAffinityB -gt 0) {
        throw "${caseId}: personalized fixed-pool scoring returned missing affinity values."
    }

    $fixedMetrics = Get-FixedPoolComparison `
        -A $fixedA.Results `
        -B $fixedB.Results `
        -PoolSize $poolIds.Count

    $baselineMetricsA = Get-BaselineRankingComparison `
        -Personalized $fixedA.Results `
        -Baseline $baseline.Results

    $baselineMetricsB = Get-BaselineRankingComparison `
        -Personalized $fixedB.Results `
        -Baseline $baseline.Results

    $semanticBlind = New-SemanticBlindPacket `
        -PairId $PairId `
        -City $City `
        -ProfileA $profileA `
        -ProfileB $profileB `
        -RankingA $fixedA.Results `
        -RankingB $fixedB.Results

    $baselineBlindA = New-BaselineBlindPacket `
        -PairId $PairId `
        -City $City `
        -Profile $profileA `
        -Personalized $fixedA.Results `
        -Baseline $baseline.Results

    $baselineBlindB = New-BaselineBlindPacket `
        -PairId $PairId `
        -City $City `
        -Profile $profileB `
        -Personalized $fixedB.Results `
        -Baseline $baseline.Results

    $caseRecord = [PSCustomObject]@{
        CaseId = $caseId
        PairId = $PairId
        City   = $City
        Profiles = @(
            $profileA,
            $profileB
        )
        FrozenPoolEntityIds = $poolIds
        Retrievals          = $retrievalRecords
        RetrievalMetrics    = $retrievalMetrics
        FixedPool = [PSCustomObject]@{
            ProfileA = [PSCustomObject]@{
                ProfileId  = $profileA.ProfileId
                RequestUrl = $fixedA.RequestUrl
                Results    = $fixedA.Results
            }
            ProfileB = [PSCustomObject]@{
                ProfileId  = $profileB.ProfileId
                RequestUrl = $fixedB.RequestUrl
                Results    = $fixedB.Results
            }
            Baseline = [PSCustomObject]@{
                Condition  = $baseline.Condition
                RequestUrl = $baseline.RequestUrl
                Results    = $baseline.Results
            }
        }
        FixedPoolMetrics = $fixedMetrics
        BaselineMetrics = [PSCustomObject]@{
            ProfileA = [PSCustomObject]@{
                ProfileId = $profileA.ProfileId
                Metrics   = $baselineMetricsA
            }
            ProfileB = [PSCustomObject]@{
                ProfileId = $profileB.ProfileId
                Metrics   = $baselineMetricsB
            }
        }
        BaselineNote = "UNSIGNALED_QLOO_BASELINE provides Qloo's unsignaled/default ranking for the same frozen pool; no baseline affinity values are assumed or required."
    }

    Write-Utf8Json -Value $caseRecord -Path (Join-Path $caseDir "case-record.json")
    Write-Utf8Json -Value $semanticBlind.Packet -Path (Join-Path $caseDir "blind-semantic.json")
    Write-Utf8Json -Value $semanticBlind.AnswerKey -Path (Join-Path $caseDir "blind-semantic-answer-key.json")

    Write-Utf8Json `
        -Value $baselineBlindA.Packet `
        -Path (Join-Path $caseDir ("blind-baseline-{0}.json" -f $profileA.ProfileId.ToLowerInvariant()))

    Write-Utf8Json `
        -Value $baselineBlindA.AnswerKey `
        -Path (Join-Path $caseDir ("blind-baseline-{0}-answer-key.json" -f $profileA.ProfileId.ToLowerInvariant()))

    Write-Utf8Json `
        -Value $baselineBlindB.Packet `
        -Path (Join-Path $caseDir ("blind-baseline-{0}.json" -f $profileB.ProfileId.ToLowerInvariant()))

    Write-Utf8Json `
        -Value $baselineBlindB.AnswerKey `
        -Path (Join-Path $caseDir ("blind-baseline-{0}-answer-key.json" -f $profileB.ProfileId.ToLowerInvariant()))

    return $caseRecord
}

# -----------------------------
# Formal confirmatory execution
# -----------------------------

$gitCommit = $null
try {
    $gitCommit = (git rev-parse HEAD 2>$null).Trim()
} catch {
    $gitCommit = $null
}

$manifest = [PSCustomObject]@{
    RunId              = $runId
    StartedUtc         = (Get-Date).ToUniversalTime().ToString("o")
    Protocol           = "TASTE_TRANSLATION_RETEST"
    ExecutionMode      = "CONFIRMATORY"
    PairIds            = @($PairIds)
    Cities             = @($Cities)
    CategoryTake       = $CategoryTake
    ControlledCategories = @(
        $categories |
        Select-Object Id, Name, Tag
    )
    GitCommit          = $gitCommit
    Baseline           = "UNSIGNALED_QLOO_BASELINE"
    Notes              = @(
        "Pair 2 and Pair 3 are confirmatory.",
        "Istanbul and London are frozen destinations.",
        "Candidate contribution is Top 7 per profile per controlled category.",
        "No FoodSignalShare metric is used.",
        "Unsignaled baseline is evaluated by ranking order and blind semantic fit, not affinity."
    )
}

Write-Utf8Json `
    -Value $manifest `
    -Path (Join-Path $runDir "run-manifest.json")

$caseResults = @()

foreach ($pairId in $PairIds) {
    foreach ($city in $Cities) {
        $caseResults += Invoke-FormalRetestCase `
            -PairId $pairId `
            -City $city
    }
}

$summaryCases = @(
    $caseResults |
    ForEach-Object {
        [PSCustomObject]@{
            CaseId                = $_.CaseId
            PairId                = $_.PairId
            City                  = $_.City
            FrozenPoolSize        = $_.FrozenPoolEntityIds.Count
            FixedTop10Overlap     = $_.FixedPoolMetrics.Top10Overlap
            SpearmanRank          = $_.FixedPoolMetrics.SpearmanRank
            PearsonAffinity       = $_.FixedPoolMetrics.PearsonAffinity
            AffinityDeltaMean     = $_.FixedPoolMetrics.AffinityDeltaMean
            AffinityDeltaStdDev   = $_.FixedPoolMetrics.AffinityDeltaStdDev
        }
    }
)

$runSummary = [PSCustomObject]@{
    RunId          = $runId
    CompletedUtc   = (Get-Date).ToUniversalTime().ToString("o")
    CaseCount      = $caseResults.Count
    Cases          = $summaryCases
    EvaluationGate = "BLIND_EVALUATION_PENDING"
    AnswerKeyWarning = "Do not open or share any *answer-key.json files before all blind evaluator responses are collected."
}

Write-Utf8Json `
    -Value $runSummary `
    -Path (Join-Path $runDir "run-summary.json")

Write-Host ""
Write-Host "FORMAL RETEST RETRIEVAL COMPLETE"
Write-Host ("Run directory: {0}" -f $runDir)
Write-Host ("Cases completed: {0}" -f $caseResults.Count)
Write-Host ""
$summaryCases |
    Format-Table `
        CaseId,
        FrozenPoolSize,
        @{Name="Top10Overlap";Expression={"{0:P1}" -f $_.FixedTop10Overlap}},
        @{Name="Spearman";Expression={if ($null -eq $_.SpearmanRank) {"-"} else {"{0:N3}" -f $_.SpearmanRank}}},
        @{Name="PearsonAffinity";Expression={if ($null -eq $_.PearsonAffinity) {"-"} else {"{0:N3}" -f $_.PearsonAffinity}}} `
        -AutoSize

Write-Host ""
Write-Host "STOP: blind evaluation is pending."
Write-Host "Do not inspect any *answer-key.json files yet."