param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

# Offline-only validation for JUDGE_EXPERIENCE_V1.
# No API request, secret, or holdout access is permitted here.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-JudgeContract {
    param([bool]$Condition, [string]$Message)

    if (-not $Condition) {
        throw "Judge Experience contract validation failed: $Message"
    }
}

function Read-RepoText {
    param([string]$RelativePath)

    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-JudgeContract (Test-Path -LiteralPath $path -PathType Leaf) "Missing $RelativePath."
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
}

$doc = Read-RepoText 'docs/JUDGE_EXPERIENCE_STATE_MACHINE_V1.md'
$schemaText = Read-RepoText 'contracts/judge-experience-v1.schema.json'
$reference = Read-RepoText 'scripts/validation/JudgeExperienceContract.Reference.ps1'
$tests = Read-RepoText 'scripts/validation/Test-JudgeExperienceContract.Tests.ps1'
$workflow = Read-RepoText '.github/workflows/validation.yml'

try {
    $schema = $schemaText | ConvertFrom-Json
}
catch {
    throw "Judge Experience contract validation failed: Invalid JSON Schema document. $($_.Exception.Message)"
}

Assert-JudgeContract (
    [string]$schema.properties.contract_version.const -ceq 'JUDGE_EXPERIENCE_V1'
) 'Contract version changed.'

Assert-JudgeContract (
    [string]$schema.properties.selector_policy_id.const -ceq 'LEXIMIN_RANK_V1'
) 'Selector policy changed.'

Assert-JudgeContract (
    [string]$schema.properties.slot_contract_id.const -ceq 'CROSS_CATEGORY_SLOT_CONTRACT_V1'
) 'Slot contract changed.'

$defs = $schema.PSObject.Properties['$defs'].Value
$expectedStates = @(
    'IDLE',
    'INPUT_READY',
    'RESOLVING_PROFILES',
    'RETRIEVING_QLOO',
    'RECONCILING',
    'ASSEMBLING_SLOTS',
    'EXPLAINING',
    'VALIDATING',
    'READY',
    'PARTIAL_READY',
    'FAILED'
)
$actualStates = @($defs.runState.enum | ForEach-Object { [string]$_ })
Assert-JudgeContract (
    ($actualStates -join '|') -ceq ($expectedStates -join '|')
) 'Run-state enum or order changed.'

$expectedCategories = @(
    'art_gallery',
    'book_store',
    'museum',
    'park',
    'restaurant',
    'shopping_mall'
)
$actualCategories = @($defs.category.enum | ForEach-Object { [string]$_ })
Assert-JudgeContract (
    ($actualCategories -join '|') -ceq ($expectedCategories -join '|')
) 'Frozen category set changed.'

$slotRefs = @(
    $schema.properties.slots.prefixItems |
    ForEach-Object { [string]$_.PSObject.Properties['$ref'].Value }
)
Assert-JudgeContract (
    ($slotRefs -join '|') -ceq '#/$defs/cultureSlot|#/$defs/outdoorsSlot|#/$defs/cityLifeSlot'
) 'Slot display order changed.'

$cultureCategories = @($defs.cultureSlot.properties.resolved_category.enum | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
$outdoorCategories = @($defs.outdoorsSlot.properties.resolved_category.enum | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
$cityLifeCategories = @($defs.cityLifeSlot.properties.resolved_category.enum | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })

Assert-JudgeContract (
    ($cultureCategories -join '|') -ceq 'museum|art_gallery|book_store'
) 'CULTURE category membership changed.'
Assert-JudgeContract (
    ($outdoorCategories -join '|') -ceq 'park'
) 'OUTDOORS category membership changed.'
Assert-JudgeContract (
    ($cityLifeCategories -join '|') -ceq 'restaurant|shopping_mall'
) 'CITY_LIFE category membership changed.'

Assert-JudgeContract (
    $schemaText -notmatch '(?i)rankGap|rank_gap'
) 'Redundant rank-gap field was added to the machine-readable contract.'
Assert-JudgeContract (
    $reference -notmatch '(?i)rankGap|rank_gap'
) 'Reference behavior must not implement a rank-gap key.'

Assert-JudgeContract (
    $doc -match 'CULTURE`: `museum -> art_gallery -> book_store`'
) 'CULTURE priority chain changed in the frozen document.'
Assert-JudgeContract (
    $doc -match 'OUTDOORS`: `park`'
) 'OUTDOORS priority chain changed in the frozen document.'
Assert-JudgeContract (
    $doc -match 'CITY_LIFE`: `restaurant -> shopping_mall`'
) 'CITY_LIFE priority chain changed in the frozen document.'
Assert-JudgeContract (
    $doc -match '1\. max\(rank_a, rank_b\) ASC' -and
    $doc -match '2\. rank_a \+ rank_b ASC' -and
    $doc -match '3\. entity_id ASC'
) 'LEXIMIN_RANK_V1 ordering changed in the frozen document.'
Assert-JudgeContract (
    $doc -match 'No cross-category arithmetic is permitted\.'
) 'Cross-category arithmetic prohibition is missing.'
Assert-JudgeContract (
    $doc -match 'An `entity_id` may appear on at most one final card\.'
) 'Global entity deduplication invariant is missing.'
Assert-JudgeContract (
    $doc -match '`NO_SHARED_QLOO_EVIDENCE` means valid retrievals completed but their intersection was empty\.' -and
    $doc -match '`EVIDENCE_UNAVAILABLE` means required retrieval evidence is missing or invalid\.'
) 'Evidence-unavailable and empty-intersection statuses are no longer distinguished.'
Assert-JudgeContract (
    $doc -match 'The LLM must not:' -and
    $doc -match 'add a venue' -and
    $doc -match 'reorder slots' -and
    $doc -match 'alter ranks'
) 'LLM recommendation-authority restrictions changed.'
Assert-JudgeContract (
    $doc -match '`READY` requires three filled slots; honest shortfall produces `PARTIAL_READY`\.'
) 'READY/PARTIAL_READY invariant changed.'

Assert-JudgeContract (
    $reference -match "SlotId = 'CULTURE'[\s\S]*Categories = @\('museum', 'art_gallery', 'book_store'\)"
) 'Reference CULTURE priority chain changed.'
Assert-JudgeContract (
    $reference -match "SlotId = 'OUTDOORS'[\s\S]*Categories = @\('park'\)"
) 'Reference OUTDOORS priority chain changed.'
Assert-JudgeContract (
    $reference -match "SlotId = 'CITY_LIFE'[\s\S]*Categories = @\('restaurant', 'shopping_mall'\)"
) 'Reference CITY_LIFE priority chain changed.'
Assert-JudgeContract (
    $reference -match 'Sort-Object[\s\S]*WorstRank[\s\S]*TotalRank[\s\S]*EntityId'
) 'Reference LEXIMIN ordering changed.'
Assert-JudgeContract (
    $reference -match "Status = 'EVIDENCE_UNAVAILABLE'" -and
    $reference -match "Status = 'NO_SHARED_QLOO_EVIDENCE'"
) 'Reference model conflates unavailable evidence with empty shared evidence.'

Assert-JudgeContract (
    $tests -match "A/B swap leaves ordering unchanged" -and
    $tests -match "Cross-category rank strength cannot override fixed slot priority" -and
    $tests -match "LLM cannot inject an unknown venue"
) 'Required behavioral acceptance cases are missing.'

Assert-JudgeContract (
    $workflow -match 'run: \./scripts/validation/Test-JudgeExperienceContract\.ps1'
) 'CI does not invoke Judge Experience static contract validation.'
Assert-JudgeContract (
    $workflow -match 'run: \./scripts/validation/Test-JudgeExperienceContract\.Tests\.ps1'
) 'CI does not invoke Judge Experience behavioral/mutation tests.'
Assert-JudgeContract (
    $workflow -notmatch '(?i)QLOO_API_KEY|X-Api-Key|hackathon\.api\.qloo\.com'
) 'Repository CI must not wire Qloo credentials or live endpoints.'

Write-Output 'Judge Experience static contract validation passed: state machine, LEXIMIN_RANK_V1, fixed slots, evidence semantics, LLM authority boundary, and offline CI wiring are preserved.'
