# Dependency-free behavioral and mutation checks for JUDGE_EXPERIENCE_V1.
# All fixtures are synthetic/offline. No API request, secret, or holdout is used.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$staticValidator = Join-Path $PSScriptRoot 'Test-JudgeExperienceContract.ps1'
$referenceModel = Join-Path $PSScriptRoot 'JudgeExperienceContract.Reference.ps1'
. $referenceModel

$script:passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)

    if (-not $Condition) {
        throw "Judge Experience invariant failed: $Name"
    }

    $script:passed++
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Name)

    if ([string]$Actual -cne [string]$Expected) {
        throw "Judge Experience invariant failed: $Name. Expected '$Expected', got '$Actual'."
    }

    $script:passed++
}

function Assert-Sequence {
    param([object[]]$Actual, [object[]]$Expected, [string]$Name)

    $actualText = @($Actual | ForEach-Object { [string]$_ }) -join '|'
    $expectedText = @($Expected | ForEach-Object { [string]$_ }) -join '|'

    if ($actualText -cne $expectedText) {
        throw "Judge Experience invariant failed: $Name. Expected '$expectedText', got '$actualText'."
    }

    $script:passed++
}

function New-Retrieval {
    param(
        [string[]]$EntityIds = @(),
        [string]$Status = 'COMPLETE'
    )

    return [pscustomobject]@{
        Status = $Status
        EntityIds = @($EntityIds)
    }
}

function New-EmptyReconciliationMap {
    $map = @{}

    foreach ($category in @(
        'art_gallery',
        'book_store',
        'museum',
        'park',
        'restaurant',
        'shopping_mall'
    )) {
        $map[$category] = [pscustomobject]@{
            Category = $category
            Status = 'NO_SHARED_QLOO_EVIDENCE'
            Candidates = @()
        }
    }

    return $map
}

function New-ExplainedSlotsFromImmutable {
    param([object[]]$Slots)

    $output = @()

    foreach ($slot in $Slots) {
        if ($slot.Status -ceq 'SHARED_PRIMARY') {
            $output += [pscustomobject]@{
                SlotId = $slot.SlotId
                Status = $slot.Status
                EntityId = $slot.Selected.EntityId
                RankA = $slot.Selected.RankA
                RankB = $slot.Selected.RankB
                WhyItWorks = 'Grounded explanation fixture.'
            }
        }
        else {
            $output += [pscustomobject]@{
                SlotId = $slot.SlotId
                Status = $slot.Status
                EntityId = $null
                RankA = $null
                RankB = $null
                WhyItWorks = $null
            }
        }
    }

    return $output
}

# Positive static control.
& $staticValidator -RepositoryRoot $repositoryRoot > $null
$script:passed++

# A/B swap leaves ordering unchanged.
$a = New-Retrieval -EntityIds @('X', 'Y', 'Z')
$b = New-Retrieval -EntityIds @('Y', 'X', 'Z')
$ab = Get-JudgeCategoryReconciliation -Category 'museum' -RetrievalA $a -RetrievalB $b
$ba = Get-JudgeCategoryReconciliation -Category 'museum' -RetrievalA $b -RetrievalB $a
Assert-Sequence `
    -Actual @($ab.Candidates | ForEach-Object { $_.EntityId }) `
    -Expected @($ba.Candidates | ForEach-Object { $_.EntityId }) `
    -Name 'A/B swap leaves ordering unchanged'

# Exact LEXIMIN tie resolves only by entity ID.
$tieA = New-Retrieval -EntityIds @('B', 'A')
$tieB = New-Retrieval -EntityIds @('A', 'B')
$tie = Get-JudgeCategoryReconciliation -Category 'museum' -RetrievalA $tieA -RetrievalB $tieB
Assert-Sequence `
    -Actual @($tie.Candidates | ForEach-Object { $_.EntityId }) `
    -Expected @('A', 'B') `
    -Name 'LEXIMIN final tie-break is deterministic entity ID order'

# Duplicate IDs use first Qloo occurrence for rank evidence.
$dupA = New-Retrieval -EntityIds @('DUP', 'X', 'DUP')
$dupB = New-Retrieval -EntityIds @('X', 'DUP')
$dupRanks = Get-JudgeCategoryReconciliation -Category 'museum' -RetrievalA $dupA -RetrievalB $dupB
$dupCandidate = @($dupRanks.Candidates | Where-Object { $_.EntityId -ceq 'DUP' })[0]
Assert-Equal -Actual $dupCandidate.RankA -Expected 1 -Name 'First Qloo occurrence defines Person A rank'
Assert-Equal -Actual $dupCandidate.RankB -Expected 2 -Name 'First Qloo occurrence defines Person B rank'

# Cross-category rank strength cannot override fixed slot priority.
$fixed = New-EmptyReconciliationMap
$fixed['museum'] = Get-JudgeCategoryReconciliation `
    -Category 'museum' `
    -RetrievalA (New-Retrieval -EntityIds @('m1','a','b','c','d','e','f','g','M')) `
    -RetrievalB (New-Retrieval -EntityIds @('m2','a2','b2','c2','d2','e2','f2','g2','M'))
$fixed['art_gallery'] = Get-JudgeCategoryReconciliation `
    -Category 'art_gallery' `
    -RetrievalA (New-Retrieval -EntityIds @('G')) `
    -RetrievalB (New-Retrieval -EntityIds @('G'))
$fixed['park'] = Get-JudgeCategoryReconciliation `
    -Category 'park' `
    -RetrievalA (New-Retrieval -EntityIds @('P')) `
    -RetrievalB (New-Retrieval -EntityIds @('P'))
$fixed['restaurant'] = Get-JudgeCategoryReconciliation `
    -Category 'restaurant' `
    -RetrievalA (New-Retrieval -EntityIds @('R')) `
    -RetrievalB (New-Retrieval -EntityIds @('R'))
$fixedSlots = Resolve-JudgeExperienceSlots -Reconciliations $fixed
Assert-Equal -Actual $fixedSlots[0].Selected.EntityId -Expected 'M' -Name 'CULTURE keeps museum priority even when art gallery ranks stronger'
Assert-Sequence -Actual @($fixedSlots | ForEach-Object { $_.SlotId }) -Expected @('CULTURE','OUTDOORS','CITY_LIFE') -Name 'Slot display order is fixed and not rank-derived'

# Fallback category is used only after earlier category has no eligible shared candidate.
$fallback = New-EmptyReconciliationMap
$fallback['art_gallery'] = Get-JudgeCategoryReconciliation `
    -Category 'art_gallery' `
    -RetrievalA (New-Retrieval -EntityIds @('G')) `
    -RetrievalB (New-Retrieval -EntityIds @('G'))
$fallbackSlots = Resolve-JudgeExperienceSlots -Reconciliations $fallback
Assert-Equal -Actual $fallbackSlots[0].ResolvedCategory -Expected 'art_gallery' -Name 'CULTURE falls back from empty museum to art gallery'
Assert-Equal -Actual $fallbackSlots[0].Selected.EntityId -Expected 'G' -Name 'Fallback selects deterministic art gallery winner'

# Global entity deduplication forces the later slot to use its next candidate.
$dedupe = New-EmptyReconciliationMap
$dedupe['museum'] = Get-JudgeCategoryReconciliation `
    -Category 'museum' `
    -RetrievalA (New-Retrieval -EntityIds @('DUP')) `
    -RetrievalB (New-Retrieval -EntityIds @('DUP'))
$dedupe['park'] = Get-JudgeCategoryReconciliation `
    -Category 'park' `
    -RetrievalA (New-Retrieval -EntityIds @('DUP','P2')) `
    -RetrievalB (New-Retrieval -EntityIds @('DUP','P2'))
$dedupeSlots = Resolve-JudgeExperienceSlots -Reconciliations $dedupe
Assert-Equal -Actual $dedupeSlots[0].Selected.EntityId -Expected 'DUP' -Name 'Earlier CULTURE slot owns duplicate entity first'
Assert-Equal -Actual $dedupeSlots[1].Selected.EntityId -Expected 'P2' -Name 'OUTDOORS skips already-used entity and takes next park candidate'

# Retrieval failure is not treated as empty intersection.
$unavailable = Get-JudgeCategoryReconciliation `
    -Category 'museum' `
    -RetrievalA (New-Retrieval -EntityIds @() -Status 'EVIDENCE_UNAVAILABLE') `
    -RetrievalB (New-Retrieval -EntityIds @())
Assert-Equal -Actual $unavailable.Status -Expected 'EVIDENCE_UNAVAILABLE' -Name 'Missing retrieval evidence remains EVIDENCE_UNAVAILABLE'
$empty = Get-JudgeCategoryReconciliation `
    -Category 'museum' `
    -RetrievalA (New-Retrieval -EntityIds @('A')) `
    -RetrievalB (New-Retrieval -EntityIds @('B'))
Assert-Equal -Actual $empty.Status -Expected 'NO_SHARED_QLOO_EVIDENCE' -Name 'Completed disjoint lists become NO_SHARED_QLOO_EVIDENCE'

# LLM cannot inject an unknown venue.
$immutable = $dedupeSlots
$validExplanation = New-ExplainedSlotsFromImmutable -Slots $immutable
Assert-True `
    -Condition (Test-JudgeExplanationPayload -ImmutableSlots $immutable -ExplainedSlots $validExplanation) `
    -Name 'Unchanged explanation payload validates'
$invented = @($validExplanation | ForEach-Object { $_.PSObject.Copy() })
$invented[0].EntityId = 'LLM-INVENTED-VENUE'
Assert-True `
    -Condition (-not (Test-JudgeExplanationPayload -ImmutableSlots $immutable -ExplainedSlots $invented)) `
    -Name 'LLM cannot inject an unknown venue'

# LLM cannot reorder immutable slots.
$reordered = @($validExplanation[1], $validExplanation[0], $validExplanation[2])
Assert-True `
    -Condition (-not (Test-JudgeExplanationPayload -ImmutableSlots $immutable -ExplainedSlots $reordered)) `
    -Name 'LLM cannot reorder selected slots'

# Empty slots must remain empty in explanation output.
$emptyMutation = @($validExplanation | ForEach-Object { $_.PSObject.Copy() })
$emptyIndex = -1
for ($i = 0; $i -lt $immutable.Count; $i++) {
    if ($immutable[$i].Status -cne 'SHARED_PRIMARY') {
        $emptyIndex = $i
        break
    }
}
Assert-True -Condition ($emptyIndex -ge 0) -Name 'Synthetic fixture contains an honest empty slot'
$emptyMutation[$emptyIndex].EntityId = 'LLM-BACKFILL'
Assert-True `
    -Condition (-not (Test-JudgeExplanationPayload -ImmutableSlots $immutable -ExplainedSlots $emptyMutation)) `
    -Name 'Empty shared evidence cannot trigger LLM venue creation'

# READY requires exactly three filled slots; honest shortfall is PARTIAL_READY.
$readyMap = New-EmptyReconciliationMap
$readyMap['museum'] = Get-JudgeCategoryReconciliation -Category 'museum' -RetrievalA (New-Retrieval -EntityIds @('M')) -RetrievalB (New-Retrieval -EntityIds @('M'))
$readyMap['park'] = Get-JudgeCategoryReconciliation -Category 'park' -RetrievalA (New-Retrieval -EntityIds @('P')) -RetrievalB (New-Retrieval -EntityIds @('P'))
$readyMap['restaurant'] = Get-JudgeCategoryReconciliation -Category 'restaurant' -RetrievalA (New-Retrieval -EntityIds @('R')) -RetrievalB (New-Retrieval -EntityIds @('R'))
$readySlots = Resolve-JudgeExperienceSlots -Reconciliations $readyMap
Assert-Equal -Actual (Get-JudgeTerminalState -Slots $readySlots -ValidationPassed $true) -Expected 'READY' -Name 'Three filled validated slots produce READY'
Assert-Equal -Actual (Get-JudgeTerminalState -Slots $dedupeSlots -ValidationPassed $true) -Expected 'PARTIAL_READY' -Name 'Honest slot shortfall produces PARTIAL_READY'

$failedMap = New-EmptyReconciliationMap
$failedMap['museum'] = [pscustomobject]@{ Category='museum'; Status='EVIDENCE_UNAVAILABLE'; Candidates=@() }
$failedSlots = Resolve-JudgeExperienceSlots -Reconciliations $failedMap
Assert-Equal -Actual (Get-JudgeTerminalState -Slots $failedSlots -ValidationPassed $true) -Expected 'FAILED' -Name 'Unavailable required evidence fails closed'
Assert-Equal -Actual (Get-JudgeTerminalState -Slots $readySlots -ValidationPassed $false) -Expected 'FAILED' -Name 'Explanation validation failure produces FAILED'

# Judge-visible checkmarks represent completed states only.
$completedAtReconcile = Get-JudgeCompletedProgressSteps -State 'RECONCILING'
Assert-Sequence -Actual $completedAtReconcile -Expected @('RESOLVING_PROFILES','RETRIEVING_QLOO') -Name 'Active RECONCILING step is not prematurely checkmarked'
$completedAtReady = Get-JudgeCompletedProgressSteps -State 'READY'
Assert-Sequence -Actual $completedAtReady -Expected @('RESOLVING_PROFILES','RETRIEVING_QLOO','RECONCILING','ASSEMBLING_SLOTS','EXPLAINING','VALIDATING') -Name 'READY checkmarks all completed operational states'

# Static mutation guards.
$fixtureFiles = @(
    'docs/JUDGE_EXPERIENCE_STATE_MACHINE_V1.md',
    'contracts/judge-experience-v1.schema.json',
    'scripts/validation/JudgeExperienceContract.Reference.ps1',
    'scripts/validation/Test-JudgeExperienceContract.Tests.ps1',
    '.github/workflows/validation.yml'
)

function New-ValidationFixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) (
        'judge-experience-contract-' + [guid]::NewGuid().ToString('N')
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

    [IO.File]::WriteAllText(
        $path,
        $text.Replace($Old, $New),
        [Text.UTF8Encoding]::new($false)
    )
}

function Assert-StaticRejected {
    param([string]$Name, [scriptblock]$Mutation)

    $root = New-ValidationFixture

    try {
        & $Mutation $root
        $rejected = $false

        try {
            & $staticValidator -RepositoryRoot $root > $null
        }
        catch {
            if ($_.Exception.Message -notlike 'Judge Experience contract validation failed:*') {
                throw
            }
            $rejected = $true
        }

        if (-not $rejected) {
            throw "Unsafe Judge Experience mutation was accepted: $Name"
        }

        $script:passed++
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}

Assert-StaticRejected 'Change selector policy identifier' {
    param($root)
    Set-TextMutation -Root $root -RelativePath 'contracts/judge-experience-v1.schema.json' -Old '"selector_policy_id": { "const": "LEXIMIN_RANK_V1" }' -New '"selector_policy_id": { "const": "GLOBAL_BORDA_V1" }'
}

Assert-StaticRejected 'Add redundant rank-gap field to schema' {
    param($root)
    $old = '"why_it_works": { "type": ["string", "null"], "maxLength": 500 }'
    $new = '"rank_gap": { "type": "integer" },' + "`n        " + $old
    Set-TextMutation -Root $root -RelativePath 'contracts/judge-experience-v1.schema.json' -Old $old -New $new
}

Assert-StaticRejected 'Change frozen CULTURE category priority' {
    param($root)
    Set-TextMutation -Root $root -RelativePath 'docs/JUDGE_EXPERIENCE_STATE_MACHINE_V1.md' -Old '- `CULTURE`: `museum -> art_gallery -> book_store`' -New '- `CULTURE`: `art_gallery -> museum -> book_store`'
}

Assert-StaticRejected 'Change reference CULTURE chain to rank-driven preference' {
    param($root)
    Set-TextMutation -Root $root -RelativePath 'scripts/validation/JudgeExperienceContract.Reference.ps1' -Old "Categories = @('museum', 'art_gallery', 'book_store')" -New "Categories = @('art_gallery', 'museum', 'book_store')"
}

Assert-StaticRejected 'Change slot display order in schema' {
    param($root)
    Set-TextMutation -Root $root -RelativePath 'contracts/judge-experience-v1.schema.json' -Old '{ "$ref": "#/$defs/cultureSlot" }' -New '{ "$ref": "#/$defs/cityLifeSlot" }'
}

Assert-StaticRejected 'Remove behavioral acceptance suite from CI' {
    param($root)
    Set-TextMutation -Root $root -RelativePath '.github/workflows/validation.yml' -Old 'run: ./scripts/validation/Test-JudgeExperienceContract.Tests.ps1' -New 'run: ./scripts/validation/Test-Qmbt2rDirectLocationDevelopment.Tests.ps1'
}

Write-Output (
    'Judge Experience contract invariant tests passed: ' +
    "$script:passed checks across symmetry, LEXIMIN ordering, slot priority, dedupe, failure semantics, LLM immutability, terminal states, progress, and mutation guards."
)
