# Dependency-free mutation checks. Only temporary text fixtures are modified;
# no retrieval harness, secret, API request, or new holdout data is used.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$validator = Join-Path $PSScriptRoot 'Test-Qmbt2rProtocol.ps1'
$script:passed = 0

$fixtureFiles = @(
    'docs/QMBT_2R_PROTOCOL.md',
    'docs/QMBT_2R_LOC_DIRECT_QUERY_V1.md',
    'docs/QMBT_1_PROTOCOL.md',
    'docs/QMBT_1_INVALID_RUN_20261020.md',
    'docs/QLOO_FIXED_POOL_DIAGNOSTIC.md',
    'docs/QLOO_FIXED_POOL_DIAGNOSTIC_RESULT_20261020.md',
    'config/qmbt-2r/direct-location-queries-v1.json',
    'scripts/validation/Test-Qmbt2rDirectLocation.ps1',
    '.github/workflows/validation.yml',
    '.github/workflows/qloo-evidence-audit.yml'
)

function New-ValidationFixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('qmbt2r-static-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $root
    foreach ($relativePath in $fixtureFiles) {
        $destination = Join-Path $root $relativePath
        $null = New-Item -ItemType Directory -Path (Split-Path $destination) -Force
        Copy-Item -LiteralPath (Join-Path $repositoryRoot $relativePath) -Destination $destination
    }
    return $root
}

function Set-ContractMutation {
    param([string]$Root, [scriptblock]$Mutation)
    $path = Join-Path $Root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $block = [regex]::Match($text, '(?ms)^```json\n(.*?)\n```$').Groups[1]
    $value = ConvertFrom-Json -InputObject $block.Value -AsHashtable
    & $Mutation $value
    $json = ConvertTo-Json -InputObject $value -Depth 30
    [IO.File]::WriteAllText($path, $text.Substring(0, $block.Index) + $json + $text.Substring($block.Index + $block.Length))
}

function Set-ManifestMutation {
    param([string]$Root, [scriptblock]$Mutation)
    $path = Join-Path $Root 'config/qmbt-2r/direct-location-queries-v1.json'
    $value = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path)) -AsHashtable
    & $Mutation $value
    [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $value -Depth 20))
}

function Assert-Rejected {
    param([string]$Name, [scriptblock]$Mutation)
    $root = New-ValidationFixture
    try {
        & $Mutation $root
        $rejected = $false
        try { & $validator -RepositoryRoot $root > $null } catch {
            if ($_.Exception.Message -notlike 'QMBT-2R validation failed:*') { throw }
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
    $root = New-ValidationFixture
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

& $validator -RepositoryRoot $repositoryRoot
$script:passed++

foreach ($field in @('fixed_pool_rescoring', 'synthetic_scores', 'zero_imputation',
    'intersection_only_selection', 'llm_venue_reordering', 'execution_allowed',
    'ci_live_qloo_allowed', 'baseline_signal_interests_entities')) {
    Assert-Rejected "Enable $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value[$field] = $true }
    }
}

foreach ($field in @('semantic_min_agreement', 'baseline_min_agreement',
    'aggregate_min_positive_cases', 'evaluator_count', 'aggregate_case_count',
    'quota_per_category', 'target_entities_per_condition', 'blind_packet_entities')) {
    Assert-Rejected "Change frozen number $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value[$field] = 2 }
    }
}

foreach ($field in @('baseline_both_sides_required', 'aggregate_both_cities_required',
    'aggregate_both_pairs_required', 'answer_key_hidden_until_all_responses',
    'requires_new_holdout_set')) {
    Assert-Rejected "Drop requirement $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value[$field] = $false }
    }
}

Assert-Rejected 'Resolve final holdout identities without reviewed selection output' {
    param($root)
    Set-ContractMutation $root { param($value) $value.human_decisions.final_holdout_identities = 'UNAPPROVED_IDENTITIES' }
}

foreach ($field in @('holdout_selection_procedure', 'city_operationalization',
    'seed_commit_anti_grinding_rule', 'live_api_stop_conditions')) {
    Assert-Rejected "Change frozen human decision $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value.human_decisions[$field] = 'UNAPPROVED_DECISION' }
    }
}

Assert-Rejected 'Change retrieval depth K' {
    param($root)
    Set-ContractMutation $root { param($value) $value.human_decisions.retrieval_depth_K = 20 }
}

Assert-Rejected 'Change development validation method' {
    param($root)
    Set-ContractMutation $root { param($value) $value.human_decisions.depth_development_validation_method = 'UNAPPROVED_ALTERNATIVE' }
}

Assert-Rejected 'Reintroduce locality-ID operationalization' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_operationalization_policy = 'QMBT-2R-LOC-v1' }
}

Assert-Rejected 'Re-enable pre-Seed locality resolution' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_preseed_resolution_required = $true }
}

Assert-Rejected 'Change direct-location manifest path' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_direct_query_manifest = 'config/other.json' }
}

Assert-Rejected 'Change direct-location candidate count' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_direct_query_candidate_count = 7 }
}

Assert-Rejected 'Use locality ID for confirmatory geography' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.confirmatory_location_filter = 'FROZEN_QLOO_LOCALITY_ID' }
}

Assert-Rejected 'Change strict location radius' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.confirmatory_filter_location_radius = 1000 }
}

Assert-Rejected 'Make direct query optional' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.confirmatory_filter_location_query_required = $false }
}

foreach ($field in @('confirmatory_locality_id_filter_allowed', 'confirmatory_wkt_filter_allowed',
    'confirmatory_geohash_filter_allowed', 'confirmatory_signal_location_allowed',
    'confirmatory_coordinate_filter_allowed', 'query_mutation_during_registered_run_allowed',
    'content_based_location_retry_allowed', 'post_seed_city_replacement_allowed')) {
    Assert-Rejected "Enable prohibited geography behavior $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value.holdout_selection_policy[$field] = $true }
    }
}

foreach ($field in @('seed_parent_and_branch_registered_before_commit',
    'seed_commit_first_remote_schema_match', 'seed_push_retry_requires_same_commit_sha',
    'rank_ascending', 'canonical_id_collision_tiebreak_ascending',
    'profile_seed_entity_resolution_after_selection_only', 'unresolved_seed_rejects_entire_pair',
    'advance_by_frozen_pair_rank', 'final_holdouts_require_post_resolution_commit')) {
    Assert-Rejected "Drop frozen holdout/seed rule $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value.holdout_selection_policy[$field] = $false }
    }
}

foreach ($field in @('seed_alternative_commit_generation_allowed',
    'ranking_before_remote_seed_confirmation_allowed', 'seed_commit_history_rewrite_allowed',
    'qloo_recommendation_preflight_allowed', 'single_seed_substitution_allowed',
    'pool_expansion_after_resolution_failure_allowed', 'post_first_confirmatory_reselection_allowed')) {
    Assert-Rejected "Enable prohibited holdout/seed behavior $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value.holdout_selection_policy[$field] = $true }
    }
}

Assert-Rejected 'Change deterministic holdout ranking hash' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.ranking_hash = 'RANDOM_MANUAL_SELECTION' }
}

Assert-Rejected 'Change frozen category framework' {
    param($root)
    Set-ContractMutation $root { param($value) $value.category_ids = @('museum') }
}

Assert-Rejected 'Replace independent retrieval with fixed-pool mode' {
    param($root)
    Set-ContractMutation $root { param($value) $value.retrieval = 'FIXED_POOL_RESCORING' }
}

Assert-Rejected 'Use development cases as confirmatory evidence' {
    param($root)
    Set-ContractMutation $root { param($value) $value.prior_case_role = 'CONFIRMATORY' }
}

Assert-Rejected 'Unknown contract override' {
    param($root)
    Set-ContractMutation $root { param($value) $value['threshold_override'] = 2 }
}

Assert-Rejected 'Mutate Tokyo frozen direct query' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.candidates[1].filter_location_query = 'Tokyo' }
}

Assert-Rejected 'Mutate direct-location radius' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.filter_location_radius = 5000 }
}

Assert-Rejected 'Enable geography fallback in manifest' {
    param($root)
    Set-ManifestMutation $root { param($value) $value.fallback_geography_allowed = $true }
}

Assert-Rejected 'Lower evaluator threshold in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('at least 3 of 4 evaluators:', 'at least 2 of 4 evaluators:')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Claim pre-registration in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('Status: DRAFT / NOT YET PRE-REGISTERED', 'Status: PRE-REGISTERED')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Remove direct-query supersession clause' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('`QMBT-2R-LOC-DIRECT-QUERY-V1` supersedes the prior `QMBT-2R-LOC-v1`', '`QMBT-2R-LOC-v1` remains required')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Allow locality ID fallback in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('do not set `filter.location` to a locality UUID, WKT point, polygon, or other', 'set `filter.location` to a locality UUID when convenient; other')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Omit strict radius in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('- set `filter.location.radius=0`;', '- omit `filter.location.radius`;')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Allow signal.location in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('- do not add `signal.location`.', '- add `signal.location` as fallback.')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Rewrite historical invalid evidence' {
    param($root)
    Add-Content -LiteralPath (Join-Path $root 'docs/QMBT_1_INVALID_RUN_20261020.md') -Value 'REINTERPRETED_AS_SUCCESS'
}

foreach ($command in @(
    'curl https://hackathon.api.qloo.com/v2/insights',
    'echo ${{ secrets.QLOO_API_KEY }}',
    './scripts/qloo-preseed/17-qmbt-2r-locality-resolution-v2.ps1'
)) {
    Assert-Rejected 'Add direct live-Qloo indicator to CI' {
        param($root)
        Add-Content -LiteralPath (Join-Path $root '.github/workflows/validation.yml') -Value "`n      - run: $command"
    }
}

Assert-Accepted 'Add unrelated safe workflow' {
    param($root)
    $path = Join-Path $root '.github/workflows/unrelated-safe.yml'
    [IO.File]::WriteAllText($path, "name: Safe Lint`non:`n  workflow_dispatch:`njobs:`n  lint:`n    runs-on: ubuntu-latest`n    steps:`n      - run: echo safe`n")
}

Assert-Accepted 'Modify unrelated workflow without live-Qloo indicators' {
    param($root)
    Add-Content -LiteralPath (Join-Path $root '.github/workflows/qloo-evidence-audit.yml') -Value "`n# harmless documentation-only workflow edit"
}

Write-Output "QMBT-2R validator tests passed: $script:passed checks, including QMBT-2R-LOC-DIRECT-QUERY-V1, exact manifest/radius/fallback guards, K=18, bounded retry, SINGLE_SHOT_REMOTE_SEED_COMMIT, deterministic holdout selection, evaluator thresholds, historical evidence, and safe CI evolution. No live calls executed."