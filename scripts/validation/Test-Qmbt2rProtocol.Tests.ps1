# Dependency-free mutation checks. Only temporary text fixtures are modified;
# no retrieval harness, secret, API request, or new holdout data is used.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$validator = Join-Path $PSScriptRoot 'Test-Qmbt2rProtocol.ps1'
$script:passed = 0
$fixtureFiles = @(
    'docs/QMBT_2R_PROTOCOL.md',
    'docs/QMBT_1_PROTOCOL.md',
    'docs/QMBT_1_INVALID_RUN_20261020.md',
    'docs/QLOO_FIXED_POOL_DIAGNOSTIC.md',
    'docs/QLOO_FIXED_POOL_DIAGNOSTIC_RESULT_20261020.md',
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
    'intersection_only_selection', 'llm_venue_reordering', 'execution_allowed', 'ci_live_qloo_allowed',
    'baseline_signal_interests_entities')) {
    Assert-Rejected "Enable $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value[$field] = $true }
    }
}

foreach ($field in @('semantic_min_agreement', 'baseline_min_agreement', 'aggregate_min_positive_cases',
    'evaluator_count', 'aggregate_case_count', 'quota_per_category', 'target_entities_per_condition', 'blind_packet_entities')) {
    Assert-Rejected "Change frozen number $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value[$field] = 2 }
    }
}

foreach ($field in @('baseline_both_sides_required', 'aggregate_both_cities_required',
    'aggregate_both_pairs_required', 'answer_key_hidden_until_all_responses', 'requires_new_holdout_set')) {
    Assert-Rejected "Drop requirement $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value[$field] = $false }
    }
}

Assert-Rejected 'Resolve final holdout identities without reviewed selection output' {
    param($root)
    Set-ContractMutation $root {
        param($value)
        $value.human_decisions.final_holdout_identities = 'UNAPPROVED_IDENTITIES'
    }
}

foreach ($field in @('holdout_selection_procedure', 'city_operationalization',
    'seed_commit_anti_grinding_rule', 'live_api_stop_conditions')) {
    Assert-Rejected "Change frozen human decision $field" {
        param($root)
        Set-ContractMutation $root { param($value) $value.human_decisions[$field] = 'UNAPPROVED_DECISION' }
    }
}

Assert-Rejected 'Change frozen retrieval depth K' {
    param($root)
    Set-ContractMutation $root { param($value) $value.human_decisions.retrieval_depth_K = 20 }
}

Assert-Rejected 'Change frozen development validation method' {
    param($root)
    Set-ContractMutation $root { param($value) $value.human_decisions.depth_development_validation_method = 'UNAPPROVED_ALTERNATIVE' }
}

Assert-Rejected 'Change frozen holdout city pool size' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_pool_size = 10 }
}

Assert-Rejected 'Change frozen holdout profile-pair pool size' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.profile_pair_pool_size = 8 }
}

Assert-Rejected 'Change locality operationalization policy' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_operationalization_policy = 'WKT_POINT' }
}

Assert-Rejected 'Change single-shot Seed Commit policy' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.seed_commit_policy = 'MULTI_TRY_SEED' }
}

Assert-Rejected 'Disable pre-Seed locality resolution' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_preseed_resolution_required = $false }
}

Assert-Rejected 'Resolve fewer than all eight city candidates' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_preseed_resolution_scope = 'SELECTED_ONLY' }
}

Assert-Rejected 'Use non-Lookup city resolution API' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_resolution_api = 'INSIGHTS_PREFLIGHT' }
}

Assert-Rejected 'Allow ambiguous locality resolution' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_resolution_requires_single_locality = $false }
}

Assert-Rejected 'Auto-replace unresolved city before Seed Commit' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_resolution_failure_action = 'AUTO_REPLACE' }
}

Assert-Rejected 'Allow Qloo Insights during city resolution' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.qloo_insights_for_city_resolution_allowed = $true }
}

Assert-Rejected 'Allow Qloo Insights during holdout pool construction' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.qloo_insights_for_pool_construction_allowed = $true }
}

Assert-Rejected 'Use coordinates operationally' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.city_coordinates_role = 'OPERATIONAL_FILTER' }
}

Assert-Rejected 'Do not freeze locality IDs before Seed Commit' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.locality_ids_committed_before_seed = $false }
}

Assert-Rejected 'Change confirmatory locality filter source' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.confirmatory_location_filter = 'WKT_POINT' }
}

Assert-Rejected 'Change strict locality radius' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.confirmatory_filter_location_radius = 1000 }
}

Assert-Rejected 'Allow fuzzy filter.location.query confirmatory use' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.confirmatory_filter_location_query_allowed = $true }
}

Assert-Rejected 'Allow signal.location in confirmatory requests' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.confirmatory_signal_location_allowed = $true }
}

Assert-Rejected 'Allow coordinate fallback in confirmatory requests' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.confirmatory_coordinate_filter_allowed = $true }
}

Assert-Rejected 'Allow city replacement after Seed Commit' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.post_seed_city_replacement_allowed = $true }
}

Assert-Rejected 'Skip pre-registration of seed branch and parent' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.seed_parent_and_branch_registered_before_commit = $false }
}

Assert-Rejected 'Allow later remote Seed Commit to become seed' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.seed_commit_first_remote_schema_match = $false }
}

Assert-Rejected 'Allow generating alternative candidate Seed Commits' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.seed_alternative_commit_generation_allowed = $true }
}

Assert-Rejected 'Allow ranking before remote Seed confirmation' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.ranking_before_remote_seed_confirmation_allowed = $true }
}

Assert-Rejected 'Allow seed push retry with recreated commit' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.seed_push_retry_requires_same_commit_sha = $false }
}

Assert-Rejected 'Allow holdout seed commit history rewrite' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.seed_commit_history_rewrite_allowed = $true }
}

Assert-Rejected 'Change deterministic holdout ranking hash' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.ranking_hash = 'RANDOM_MANUAL_SELECTION' }
}

Assert-Rejected 'Resolve profile seeds before deterministic selection' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.profile_seed_entity_resolution_after_selection_only = $false }
}

Assert-Rejected 'Allow holdout recommendation preflight' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.qloo_recommendation_preflight_allowed = $true }
}

Assert-Rejected 'Allow single-seed substitution after holdout selection' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.single_seed_substitution_allowed = $true }
}

Assert-Rejected 'Allow post-confirmatory holdout reselection' {
    param($root)
    Set-ContractMutation $root { param($value) $value.holdout_selection_policy.post_first_confirmatory_reselection_allowed = $true }
}

Assert-Rejected 'Replace independent retrieval with fixed-pool mode' {
    param($root)
    Set-ContractMutation $root { param($value) $value.retrieval = 'FIXED_POOL_RESCORING' }
}

Assert-Rejected 'Use old development cases as confirmatory evidence' {
    param($root)
    Set-ContractMutation $root { param($value) $value.prior_case_role = 'CONFIRMATORY' }
}

Assert-Rejected 'Change frozen category framework' {
    param($root)
    Set-ContractMutation $root { param($value) $value.category_ids = @('museum') }
}

Assert-Rejected 'Unknown contract override' {
    param($root)
    Set-ContractMutation $root { param($value) $value['threshold_override'] = 2 }
}

Assert-Rejected 'Duplicate JSON threshold key' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('"semantic_min_agreement": 3,', '"semantic_min_agreement": 2, "semantic_min_agreement": 3,')
    [IO.File]::WriteAllText($path, $text)
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

Assert-Rejected 'Add a contradictory status' {
    param($root)
    Add-Content -LiteralPath (Join-Path $root 'docs/QMBT_2R_PROTOCOL.md') -Value 'Status: PRE-REGISTERED'
}

Assert-Rejected 'Reintroduce fixed-pool rescoring in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('Fixed-pool rescoring is retired.', 'Fixed-pool rescoring is required.')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Change frozen retrieval depth in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('| Retrieval depth K | `18` — **FROZEN HUMAN DECISION** |', '| Retrieval depth K | `20` — **FROZEN HUMAN DECISION** |')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Change frozen development validation method in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('This is one registered structural pass:', 'This is two registered structural passes:')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Change frozen holdout selection procedure in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('The candidate pool contains exactly:', 'The candidate pool may contain:')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Change locality radius in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('- set `filter.location.radius=0`;', '- omit `filter.location.radius`;')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Allow automatic unresolved-city replacement in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('There is no automatic replacement, fallback coordinate, fuzzy', 'Automatic replacement, fallback coordinates, and fuzzy')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Allow Seed Commit alternatives in prose only' {
    param($root)
    $path = Join-Path $root 'docs/QMBT_2R_PROTOCOL.md'
    $text = [IO.File]::ReadAllText($path).Replace('do not generate, score, compare, or discard alternative candidate Seed', 'generate, score, compare, and choose alternative candidate Seed')
    [IO.File]::WriteAllText($path, $text)
}

Assert-Rejected 'Rewrite historical invalid evidence' {
    param($root)
    Add-Content -LiteralPath (Join-Path $root 'docs/QMBT_1_INVALID_RUN_20261020.md') -Value 'REINTERPRETED_AS_SUCCESS'
}

foreach ($command in @(
    'curl https://hackathon.api.qloo.com/v2/insights',
    'echo ${{ secrets.QLOO_API_KEY }}',
    './scripts/qloo-spikes/14-qmbt-1-retest.ps1'
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

Write-Output "QMBT-2R validator tests passed: $script:passed checks, including frozen K=18, development-only structural validation, bounded recommendation retry policy, QMBT-2R-LOC-v1 locality rules, SINGLE_SHOT_REMOTE_SEED_COMMIT, deterministic holdout selection, safe CI evolution, and rejected unsafe mutations. No live calls executed."