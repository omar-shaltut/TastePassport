# TastePassport - QMBT-1 Quota-Matched Broad-Taxonomy Retest
# Confirmatory execution harness for docs/QMBT_1_PROTOCOL.md.
# Pair 2 and Pair 3 x Istanbul and London.
# No agent loop, compliance logic, generated explanations, or post-hoc curation.

param(
    [string[]]$PairIds = @("2", "3"),
    [string[]]$Cities = @("Istanbul", "London"),
    [int]$CategoryTake = 3,
    [string]$OutputRoot = "artifacts/qmbt-1-retest"
)

$ErrorActionPreference = "Stop"
$baseUrl = "https://hackathon.api.qloo.com"

if (-not $headers -or -not $headers["X-Api-Key"]) {
    throw "Qloo authentication header is missing. Create `$headers first."
}

if ($CategoryTake -ne 3) {
    throw "QMBT-1 protocol requires CategoryTake=3."
}


# QMBT-1 EXECUTION UNLOCKED AFTER VALIDATION GATE
$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")

if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    $resolvedOutputRoot = $OutputRoot
} else {
    $resolvedOutputRoot = Join-Path (Get-Location).Path $OutputRoot
}

$runDir = Join-Path $resolvedOutputRoot $runId

$categories = @(
    [PSCustomObject]@{
        Id   = "art_gallery"
        Name = "Art gallery"
        Tag  = "urn:tag:category:place:art_gallery"
    },
    [PSCustomObject]@{
        Id   = "book_store"
        Name = "Book store"
        Tag  = "urn:tag:category:place:book_store"
    },
    [PSCustomObject]@{
        Id   = "museum"
        Name = "Museum"
        Tag  = "urn:tag:category:place:museum"
    },
    [PSCustomObject]@{
        Id   = "park"
        Name = "Park"
        Tag  = "urn:tag:category:place:park"
    },
    [PSCustomObject]@{
        Id   = "restaurant"
        Name = "Restaurant"
        Tag  = "urn:tag:category:place:restaurant"
    },
    [PSCustomObject]@{
        Id   = "shopping_mall"
        Name = "Shopping mall"
        Tag  = "urn:tag:category:place:shopping_mall"
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
        [int]$Take,
        [switch]$Unsignaled
    )

    $tagParam = [uri]::EscapeDataString([string]$Category.Tag)
    $cityParam = [uri]::EscapeDataString($City)

    $url = (
        "$baseUrl/v2/insights" +
        "?filter.type=urn%3Aentity%3Aplace"
    )

    if (-not $Unsignaled) {
        if ($null -eq $Profile) {
            throw "Profile is required for signaled category retrieval."
        }

        $seedIds = Get-ProfileSeedIds -Profile $Profile
        $seedParam = $seedIds -join ","
        $url += "&signal.interests.entities=$seedParam"
    }

    $url += (
        "&filter.tags=$tagParam" +
        "&filter.location.query=$cityParam" +
        "&filter.location.radius=0" +
        "&take=$Take"
    )

    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    $results = @(Convert-QlooResponse -Response $response)

    return [PSCustomObject]@{
        RequestUrl = $url
        Unsignaled = [bool]$Unsignaled
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
        Top3Overlap     = Get-TopKOverlap -A $A -B $B -K 3
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
        Top3Overlap          = Get-TopKOverlap -A $A -B $B -K 3
        SpearmanRank         = Get-SpearmanCorrelation -A $A -B $B
        PearsonAffinity      = $affinity.PearsonAffinity
        SharedAffinityCount  = $affinity.SharedAffinityCount
        AffinityDeltaMean    = $affinity.DeltaMean
        AffinityDeltaStdDev  = $affinity.DeltaStdDev
    }
}

function New-QmbtQuotaList {
    param(
        [hashtable]$RankingsByCategory,
        [array]$Categories,
        [int]$QuotaPerCategory = 3
    )

    if ($QuotaPerCategory -ne 3) {
        throw "QMBT-1 requires exactly 3 entities per category."
    }

    $expectedOrder = @(
        "art_gallery",
        "book_store",
        "museum",
        "park",
        "restaurant",
        "shopping_mall"
    )

    $actualOrder = @($Categories | ForEach-Object { [string]$_.Id })

    if (($actualOrder -join "|") -ne ($expectedOrder -join "|")) {
        throw "QMBT-1 category priority/order differs from the frozen protocol."
    }

    $usedEntityIds = @{}
    $finalList = @()
    $categoryCounts = @()

    foreach ($category in $Categories) {
        $categoryId = [string]$category.Id
        $categoryName = [string]$category.Name

        if (-not $RankingsByCategory.ContainsKey($categoryId)) {
            throw "Missing ranking for QMBT-1 category: $categoryId"
        }

        $ranking = @($RankingsByCategory[$categoryId])
        $selected = @()
        $duplicatesSkipped = 0

        foreach ($item in $ranking) {
            $entityId = [string]$item.EntityId

            if (-not $entityId) {
                continue
            }

            if ($usedEntityIds.ContainsKey($entityId)) {
                $duplicatesSkipped++
                continue
            }

            $selected += [PSCustomObject]@{
                CategoryId   = $categoryId
                CategoryName = $categoryName
                CategoryRank = [int]$item.Rank
                EntityId     = $entityId
                Name         = $item.Name
                Affinity     = $item.Affinity
                Address      = $item.Address
                PrimaryGenre = $item.PrimaryGenre
                Tags         = $item.Tags
            }

            $usedEntityIds[$entityId] = $true

            if ($selected.Count -eq $QuotaPerCategory) {
                break
            }
        }

        if ($selected.Count -ne $QuotaPerCategory) {
            throw "QMBT-1 category '$categoryId' could not fill its quota of $QuotaPerCategory unique entities after cross-category deduplication/backfill. Selected: $($selected.Count)."
        }

        $finalList += $selected

        $backfillSelections = @(
            $selected |
            Where-Object { $_.CategoryRank -gt $QuotaPerCategory }
        ).Count


        $categoryCounts += [PSCustomObject]@{
            CategoryId = $categoryId
            Count      = $selected.Count
            CrossCategoryDuplicatesSkipped = $duplicatesSkipped
            BackfillSelections             = $backfillSelections
        }
    }

    $expectedTotal = $Categories.Count * $QuotaPerCategory

    if ($finalList.Count -ne $expectedTotal) {
        throw "QMBT-1 final list expected $expectedTotal entities; produced $($finalList.Count)."
    }

    if (@($finalList.EntityId | Select-Object -Unique).Count -ne $expectedTotal) {
        throw "QMBT-1 final list contains duplicate entity IDs."
    }

    $totalDuplicateSkips = [int]((
        $categoryCounts |
        Measure-Object -Property CrossCategoryDuplicatesSkipped -Sum
    ).Sum)

    $totalBackfillSelections = [int]((
        $categoryCounts |
        Measure-Object -Property BackfillSelections -Sum
    ).Sum)

    return [PSCustomObject]@{
        Places         = $finalList
        CategoryCounts = $categoryCounts
        TotalCount     = $finalList.Count
        DuplicateSkipCount     = $totalDuplicateSkips
        BackfillSelectionCount = $totalBackfillSelections
    }
}
function Select-BlindPlaceFields {
    param([array]$Items)

    return @(
        $Items |
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
        Top3Overlap       = Get-TopKOverlap -A $Personalized -B $Baseline -K 3
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
    $categoryRecords = @()

    $rankingsA = @{}
    $rankingsB = @{}
    $rankingsBaseline = @{}

    foreach ($category in $categories) {
        $categoryId = [string]$category.Id

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

        Write-Host ("  Retrieval {0} / UNSIGNALED_QLOO_BASELINE" -f $category.Name)
        $retrievalBaseline = Invoke-QlooCategoryRetrieval `
            -Profile $null `
            -Category $category `
            -City $City `
            -Take $CategoryTake `
            -Unsignaled

        foreach ($retrievalCheck in @(
            [PSCustomObject]@{
                Label   = $profileA.ProfileId
                Results = $retrievalA.Results
            },
            [PSCustomObject]@{
                Label   = $profileB.ProfileId
                Results = $retrievalB.Results
            },
            [PSCustomObject]@{
                Label   = "UNSIGNALED_QLOO_BASELINE"
                Results = $retrievalBaseline.Results
            }
        )) {
            if ($retrievalCheck.Results.Count -ne $CategoryTake) {
                throw "$caseId / $categoryId / $($retrievalCheck.Label): expected $CategoryTake candidates; received $($retrievalCheck.Results.Count)."
            }

            $uniqueRetrievedIds = @(
                Get-EntityIds -Items $retrievalCheck.Results |
                Where-Object { $_ } |
                Select-Object -Unique
            )

            if ($uniqueRetrievedIds.Count -ne $CategoryTake) {
                throw "$caseId / $categoryId / $($retrievalCheck.Label): retrieval did not contain exactly $CategoryTake unique entity IDs."
            }
        }

        $retrievalRecords += [PSCustomObject]@{
            CategoryId   = $categoryId
            CategoryName = $category.Name
            Condition    = $profileA.ProfileId
            RequestUrl   = $retrievalA.RequestUrl
            Results      = $retrievalA.Results
        }

        $retrievalRecords += [PSCustomObject]@{
            CategoryId   = $categoryId
            CategoryName = $category.Name
            Condition    = $profileB.ProfileId
            RequestUrl   = $retrievalB.RequestUrl
            Results      = $retrievalB.Results
        }

        $retrievalRecords += [PSCustomObject]@{
            CategoryId   = $categoryId
            CategoryName = $category.Name
            Condition    = "UNSIGNALED_QLOO_BASELINE"
            RequestUrl   = $retrievalBaseline.RequestUrl
            Results      = $retrievalBaseline.Results
        }

        $retrievalMetrics += [PSCustomObject]@{
            CategoryId = $categoryId

            ProfileA_vs_ProfileB = Get-RetrievalComparison `
                -A $retrievalA.Results `
                -B $retrievalB.Results `
                -CategoryId $categoryId

            ProfileA_vs_Baseline = Get-RetrievalComparison `
                -A $retrievalA.Results `
                -B $retrievalBaseline.Results `
                -CategoryId $categoryId

            ProfileB_vs_Baseline = Get-RetrievalComparison `
                -A $retrievalB.Results `
                -B $retrievalBaseline.Results `
                -CategoryId $categoryId
        }

        $poolIds = @(
            @(
                Get-EntityIds -Items $retrievalA.Results
                Get-EntityIds -Items $retrievalB.Results
                Get-EntityIds -Items $retrievalBaseline.Results
            ) |
            Where-Object { $_ } |
            Select-Object -Unique
        )

        if ($poolIds.Count -lt $CategoryTake) {
            throw "$caseId / ${categoryId}: frozen category pool has fewer than $CategoryTake unique candidates."
        }

        if ($poolIds.Count -gt 9) {
            throw "$caseId / ${categoryId}: frozen category pool exceeds QMBT-1 maximum of 9 candidates: $($poolIds.Count)."
        }

        Write-Host ("  Frozen category pool {0}: {1}" -f $categoryId, $poolIds.Count)

        $fixedA = Invoke-QlooFixedPool `
            -Profile $profileA `
            -EntityIds $poolIds `
            -City $City

        $fixedB = Invoke-QlooFixedPool `
            -Profile $profileB `
            -EntityIds $poolIds `
            -City $City

        $fixedBaseline = Invoke-QlooFixedPool `
            -Profile $null `
            -EntityIds $poolIds `
            -City $City `
            -Unsignaled

        if (-not (Test-SameEntitySet -ExpectedIds $poolIds -ActualItems $fixedA.Results)) {
            throw "$caseId / ${categoryId}: personalized fixed-pool response for $($profileA.ProfileId) differs from frozen category pool."
        }

        if (-not (Test-SameEntitySet -ExpectedIds $poolIds -ActualItems $fixedB.Results)) {
            throw "$caseId / ${categoryId}: personalized fixed-pool response for $($profileB.ProfileId) differs from frozen category pool."
        }

        if (-not (Test-SameEntitySet -ExpectedIds $poolIds -ActualItems $fixedBaseline.Results)) {
            throw "$caseId / ${categoryId}: unsignaled fixed-pool response differs from frozen category pool."
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
            throw "$caseId / ${categoryId}: personalized fixed-pool scoring returned missing affinity values."
        }

        $fixedMetrics = Get-FixedPoolComparison `
            -A $fixedA.Results `
            -B $fixedB.Results `
            -PoolSize $poolIds.Count

        $baselineMetricsA = Get-BaselineRankingComparison `
            -Personalized $fixedA.Results `
            -Baseline $fixedBaseline.Results

        $baselineMetricsB = Get-BaselineRankingComparison `
            -Personalized $fixedB.Results `
            -Baseline $fixedBaseline.Results

        $rankingsA[$categoryId] = @($fixedA.Results)
        $rankingsB[$categoryId] = @($fixedB.Results)
        $rankingsBaseline[$categoryId] = @($fixedBaseline.Results)

        $categoryRecords += [PSCustomObject]@{
            CategoryId          = $categoryId
            CategoryName        = $category.Name
            CategoryTag         = $category.Tag
            FrozenPoolEntityIds = $poolIds
            FrozenPoolSize      = $poolIds.Count

            Retrieval = [PSCustomObject]@{
                ProfileA = [PSCustomObject]@{
                    ProfileId  = $profileA.ProfileId
                    RequestUrl = $retrievalA.RequestUrl
                    Results    = $retrievalA.Results
                }

                ProfileB = [PSCustomObject]@{
                    ProfileId  = $profileB.ProfileId
                    RequestUrl = $retrievalB.RequestUrl
                    Results    = $retrievalB.Results
                }

                Baseline = [PSCustomObject]@{
                    Condition  = "UNSIGNALED_QLOO_BASELINE"
                    RequestUrl = $retrievalBaseline.RequestUrl
                    Results    = $retrievalBaseline.Results
                }
            }

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
                    Condition  = $fixedBaseline.Condition
                    RequestUrl = $fixedBaseline.RequestUrl
                    Results    = $fixedBaseline.Results
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
        }
    }

    $finalA = New-QmbtQuotaList `
        -RankingsByCategory $rankingsA `
        -Categories $categories `
        -QuotaPerCategory 3

    $finalB = New-QmbtQuotaList `
        -RankingsByCategory $rankingsB `
        -Categories $categories `
        -QuotaPerCategory 3

    $finalBaseline = New-QmbtQuotaList `
        -RankingsByCategory $rankingsBaseline `
        -Categories $categories `
        -QuotaPerCategory 3

    if (
        $finalA.TotalCount -ne 18 -or
        $finalB.TotalCount -ne 18 -or
        $finalBaseline.TotalCount -ne 18
    ) {
        throw "${caseId}: QMBT-1 final lists must each contain exactly 18 unique places."
    }

    $semanticBlind = New-SemanticBlindPacket `
        -PairId $PairId `
        -City $City `
        -ProfileA $profileA `
        -ProfileB $profileB `
        -RankingA $finalA.Places `
        -RankingB $finalB.Places

    $baselineBlindA = New-BaselineBlindPacket `
        -PairId $PairId `
        -City $City `
        -Profile $profileA `
        -Personalized $finalA.Places `
        -Baseline $finalBaseline.Places

    $baselineBlindB = New-BaselineBlindPacket `
        -PairId $PairId `
        -City $City `
        -Profile $profileB `
        -Personalized $finalB.Places `
        -Baseline $finalBaseline.Places

    $caseRecord = [PSCustomObject]@{
        CaseId = $caseId
        PairId = $PairId
        City   = $City

        Profiles = @(
            $profileA,
            $profileB
        )

        CategoryPools     = $categoryRecords
        Retrievals       = $retrievalRecords
        RetrievalMetrics = $retrievalMetrics

        FinalLists = [PSCustomObject]@{
            ProfileA = [PSCustomObject]@{
                ProfileId      = $profileA.ProfileId
                TotalCount     = $finalA.TotalCount
                CategoryCounts = $finalA.CategoryCounts
                Places         = $finalA.Places
            }

            ProfileB = [PSCustomObject]@{
                ProfileId      = $profileB.ProfileId
                TotalCount     = $finalB.TotalCount
                CategoryCounts = $finalB.CategoryCounts
                Places         = $finalB.Places
            }

            Baseline = [PSCustomObject]@{
                Condition      = "UNSIGNALED_QLOO_BASELINE"
                TotalCount     = $finalBaseline.TotalCount
                CategoryCounts = $finalBaseline.CategoryCounts
                Places         = $finalBaseline.Places
            }
        }

        BaselineNote = "UNSIGNALED_QLOO_BASELINE uses the same category-specific frozen pools and the same 3-per-category final-list composition as both personalized conditions."
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
# Formal QMBT-1 confirmatory execution
# -----------------------------

$gitCommit = $null
try {
    $gitCommit = (git rev-parse HEAD 2>$null).Trim()
} catch {
    $gitCommit = $null
}

$manifest = [PSCustomObject]@{
    RunId         = $runId
    StartedUtc    = (Get-Date).ToUniversalTime().ToString("o")
    Protocol      = "QMBT_1"
    ExecutionMode = "CONFIRMATORY"
    PairIds       = @($PairIds)
    Cities        = @($Cities)
    CategoryTake  = $CategoryTake

    ControlledCategories = @(
        $categories |
        Select-Object Id, Name, Tag
    )

    GitCommit = $gitCommit
    Baseline  = "UNSIGNALED_QLOO_BASELINE"

    Notes = @(
        "Pair 2 and Pair 3 are frozen confirmatory pairs.",
        "Istanbul and London are frozen destinations.",
        "Each category retrieval contributes Top 3 from Profile A, Top 3 from Profile B, and Top 3 from the unsignaled Qloo baseline.",
        "Each category-specific frozen pool is the deduplicated union of those three retrievals and may contain at most 9 entities.",
        "Profile A, Profile B, and the unsignaled baseline are scored over the exact same entity IDs inside each category pool.",
        "Final lists contain exactly 3 unique entities per frozen category, 18 total, using the pre-registered category priority and deterministic cross-category deduplication/backfill rule.",
        "Blind semantic and baseline packets include all 18 final-list entities.",
        "Unsignaled baseline affinity values are not assumed or required."
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
        $categorySummaries = @(
            $_.CategoryPools |
            ForEach-Object {
                [PSCustomObject]@{
                    CategoryId          = $_.CategoryId
                    FrozenPoolSize      = $_.FrozenPoolSize
                    FixedTop3Overlap    = $_.FixedPoolMetrics.Top3Overlap
                    SpearmanRank        = $_.FixedPoolMetrics.SpearmanRank
                    PearsonAffinity     = $_.FixedPoolMetrics.PearsonAffinity
                    BaselineTop3OverlapA = $_.BaselineMetrics.ProfileA.Metrics.Top3Overlap
                    BaselineTop3OverlapB = $_.BaselineMetrics.ProfileB.Metrics.Top3Overlap
                }
            }
        )

        $poolSizes = @(
            $_.CategoryPools |
            ForEach-Object { [int]$_.FrozenPoolSize }
        )

        [PSCustomObject]@{
            CaseId              = $_.CaseId
            PairId              = $_.PairId
            City                = $_.City
            CategoryPoolCount   = $_.CategoryPools.Count
            MinCategoryPoolSize = ($poolSizes | Measure-Object -Minimum).Minimum
            MaxCategoryPoolSize = ($poolSizes | Measure-Object -Maximum).Maximum
            FinalProfileACount  = $_.FinalLists.ProfileA.TotalCount
            FinalProfileBCount  = $_.FinalLists.ProfileB.TotalCount
            FinalBaselineCount  = $_.FinalLists.Baseline.TotalCount
            CategoryMetrics     = $categorySummaries
        }
    }
)

$runSummary = [PSCustomObject]@{
    RunId            = $runId
    Protocol         = "QMBT_1"
    CompletedUtc     = (Get-Date).ToUniversalTime().ToString("o")
    CaseCount        = $caseResults.Count
    Cases            = $summaryCases
    EvaluationGate   = "BLIND_EVALUATION_PENDING"
    AnswerKeyWarning = "Do not open or share any *answer-key.json files before all blind evaluator responses are collected."
}

Write-Utf8Json `
    -Value $runSummary `
    -Path (Join-Path $runDir "run-summary.json")

Write-Host ""
Write-Host "QMBT-1 RETRIEVAL AND FIXED-POOL SCORING COMPLETE"
Write-Host ("Run directory: {0}" -f $runDir)
Write-Host ("Cases completed: {0}" -f $caseResults.Count)
Write-Host ""

$summaryCases |
    Format-Table `
        CaseId,
        CategoryPoolCount,
        MinCategoryPoolSize,
        MaxCategoryPoolSize,
        FinalProfileACount,
        FinalProfileBCount,
        FinalBaselineCount `
        -AutoSize

Write-Host ""
Write-Host "STOP: blind evaluation is pending."
Write-Host "Do not inspect any *answer-key.json files yet."
