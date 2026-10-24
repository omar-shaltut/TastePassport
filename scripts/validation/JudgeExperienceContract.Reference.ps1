# Offline reference model for JUDGE_EXPERIENCE_V1 contract acceptance tests.
# This file performs no network I/O and contains no production orchestration.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function New-FirstOccurrenceRankMap {
    param([string[]]$EntityIds)

    $map = @{}

    for ($i = 0; $i -lt $EntityIds.Count; $i++) {
        $id = [string]$EntityIds[$i]
        if (-not $map.ContainsKey($id)) {
            $map[$id] = $i + 1
        }
    }

    return $map
}

function Get-JudgeCategoryReconciliation {
    param(
        [string]$Category,
        [pscustomobject]$RetrievalA,
        [pscustomobject]$RetrievalB
    )

    if (
        [string]$RetrievalA.Status -cne 'COMPLETE' -or
        [string]$RetrievalB.Status -cne 'COMPLETE'
    ) {
        return [pscustomobject]@{
            Category = $Category
            Status = 'EVIDENCE_UNAVAILABLE'
            Candidates = @()
        }
    }

    $rankA = New-FirstOccurrenceRankMap -EntityIds @($RetrievalA.EntityIds)
    $rankB = New-FirstOccurrenceRankMap -EntityIds @($RetrievalB.EntityIds)
    $candidates = @()

    foreach ($entityId in $rankA.Keys) {
        if (-not $rankB.ContainsKey($entityId)) {
            continue
        }

        $a = [int]$rankA[$entityId]
        $b = [int]$rankB[$entityId]

        $candidates += [pscustomobject]@{
            EntityId = [string]$entityId
            Category = $Category
            RankA = $a
            RankB = $b
            WorstRank = [Math]::Max($a, $b)
            TotalRank = $a + $b
        }
    }

    $ordered = @(
        $candidates |
        Sort-Object `
            @{ Expression = { $_.WorstRank }; Ascending = $true }, `
            @{ Expression = { $_.TotalRank }; Ascending = $true }, `
            @{ Expression = { $_.EntityId }; Ascending = $true }
    )

    if ($ordered.Count -eq 0) {
        return [pscustomobject]@{
            Category = $Category
            Status = 'NO_SHARED_QLOO_EVIDENCE'
            Candidates = @()
        }
    }

    return [pscustomobject]@{
        Category = $Category
        Status = 'SHARED_CANDIDATES_AVAILABLE'
        Candidates = $ordered
    }
}

function Resolve-JudgeExperienceSlots {
    param([hashtable]$Reconciliations)

    $slotDefinitions = @(
        [pscustomobject]@{
            SlotId = 'CULTURE'
            Categories = @('museum', 'art_gallery', 'book_store')
        },
        [pscustomobject]@{
            SlotId = 'OUTDOORS'
            Categories = @('park')
        },
        [pscustomobject]@{
            SlotId = 'CITY_LIFE'
            Categories = @('restaurant', 'shopping_mall')
        }
    )

    $used = New-Object 'System.Collections.Generic.HashSet[string]'
    $slots = @()

    foreach ($definition in $slotDefinitions) {
        $selected = $null
        $resolvedCategory = $null
        $evidenceUnavailable = $false

        foreach ($category in $definition.Categories) {
            if (-not $Reconciliations.ContainsKey($category)) {
                $evidenceUnavailable = $true
                break
            }

            $reconciliation = $Reconciliations[$category]

            if ([string]$reconciliation.Status -ceq 'EVIDENCE_UNAVAILABLE') {
                $evidenceUnavailable = $true
                break
            }

            if ([string]$reconciliation.Status -ceq 'NO_SHARED_QLOO_EVIDENCE') {
                continue
            }

            foreach ($candidate in @($reconciliation.Candidates)) {
                if ($used.Contains([string]$candidate.EntityId)) {
                    continue
                }

                $selected = $candidate
                $resolvedCategory = $category
                $null = $used.Add([string]$candidate.EntityId)
                break
            }

            if ($null -ne $selected) {
                break
            }
        }

        if ($evidenceUnavailable) {
            $slots += [pscustomobject]@{
                SlotId = $definition.SlotId
                Status = 'EVIDENCE_UNAVAILABLE'
                ResolvedCategory = $null
                Selected = $null
            }
            continue
        }

        if ($null -eq $selected) {
            $slots += [pscustomobject]@{
                SlotId = $definition.SlotId
                Status = 'NO_SHARED_QLOO_EVIDENCE'
                ResolvedCategory = $null
                Selected = $null
            }
            continue
        }

        $slots += [pscustomobject]@{
            SlotId = $definition.SlotId
            Status = 'SHARED_PRIMARY'
            ResolvedCategory = $resolvedCategory
            Selected = $selected
        }
    }

    return $slots
}

function Test-JudgeExplanationPayload {
    param(
        [object[]]$ImmutableSlots,
        [object[]]$ExplainedSlots
    )

    if ($ImmutableSlots.Count -ne $ExplainedSlots.Count) {
        return $false
    }

    for ($i = 0; $i -lt $ImmutableSlots.Count; $i++) {
        $expected = $ImmutableSlots[$i]
        $actual = $ExplainedSlots[$i]

        if ([string]$expected.SlotId -cne [string]$actual.SlotId) {
            return $false
        }

        if ([string]$expected.Status -cne [string]$actual.Status) {
            return $false
        }

        if ([string]$expected.Status -cne 'SHARED_PRIMARY') {
            if ($null -ne $actual.EntityId) {
                return $false
            }
            continue
        }

        if ($null -eq $expected.Selected) {
            return $false
        }

        if ([string]$expected.Selected.EntityId -cne [string]$actual.EntityId) {
            return $false
        }

        if ([int]$expected.Selected.RankA -ne [int]$actual.RankA) {
            return $false
        }

        if ([int]$expected.Selected.RankB -ne [int]$actual.RankB) {
            return $false
        }
    }

    return $true
}

function Get-JudgeTerminalState {
    param(
        [object[]]$Slots,
        [bool]$ValidationPassed
    )

    if (-not $ValidationPassed) {
        return 'FAILED'
    }

    if (@($Slots | Where-Object { $_.Status -ceq 'EVIDENCE_UNAVAILABLE' }).Count -gt 0) {
        return 'FAILED'
    }

    $filled = @($Slots | Where-Object { $_.Status -ceq 'SHARED_PRIMARY' }).Count

    if ($filled -eq 3) {
        return 'READY'
    }

    return 'PARTIAL_READY'
}

function Get-JudgeCompletedProgressSteps {
    param([string]$State)

    $operationalStates = @(
        'RESOLVING_PROFILES',
        'RETRIEVING_QLOO',
        'RECONCILING',
        'ASSEMBLING_SLOTS',
        'EXPLAINING',
        'VALIDATING'
    )

    if ($State -in @('READY', 'PARTIAL_READY')) {
        return $operationalStates
    }

    $index = [Array]::IndexOf($operationalStates, $State)

    if ($index -le 0) {
        return @()
    }

    return @($operationalStates[0..($index - 1)])
}
