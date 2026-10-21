param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

# Offline only: read committed protocol/config/workflow text. Never load a live harness.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-Protocol {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "QMBT-2R validation failed: $Message" }
}

function Read-RepositoryText {
    param([string]$RelativePath)
    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-Protocol (Test-Path -LiteralPath $path -PathType Leaf) "Missing $RelativePath."
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
}

function Assert-NoDuplicateJsonKeys {
    param([System.Text.Json.JsonElement]$Element)
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($property in $Element.EnumerateObject()) {
            Assert-Protocol ($names.Add($property.Name)) "Duplicate contract key: $($property.Name)."
            Assert-NoDuplicateJsonKeys $property.Value
        }
    } elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($item in $Element.EnumerateArray()) { Assert-NoDuplicateJsonKeys $item }
    }
}

function Assert-ContractValue {
    param($Expected, $Actual, [string]$Location = 'contract')
    if ($Expected -is [Collections.IDictionary]) {
        Assert-Protocol ($Actual -is [Collections.IDictionary]) "$Location must be an object."
        $expectedKeys = @($Expected.Keys | Sort-Object)
        $actualKeys = @($Actual.Keys | Sort-Object)
        Assert-Protocol (($expectedKeys -join '|') -ceq ($actualKeys -join '|')) "$Location has missing or unknown fields."
        foreach ($key in $expectedKeys) { Assert-ContractValue $Expected[$key] $Actual[$key] "$Location.$key" }
    } elseif ($Expected -is [array]) {
        Assert-Protocol ($Actual -is [array]) "$Location must be an array."
        Assert-Protocol ($Expected.Count -eq $Actual.Count) "$Location has changed length."
        for ($i = 0; $i -lt $Expected.Count; $i++) { Assert-ContractValue $Expected[$i] $Actual[$i] "$Location[$i]" }
    } else {
        $expectedJson = ConvertTo-Json -InputObject $Expected -Compress
        $actualJson = ConvertTo-Json -InputObject $Actual -Compress
        Assert-Protocol ($expectedJson -ceq $actualJson) "$Location changed from its frozen or unresolved value."
    }
}

function Get-UniqueSection {
    param([string]$Text, [string]$Heading)
    $pattern = '(?ms)^## ' + [regex]::Escape($Heading) + '\n(.*?)(?=^## |\z)'
    $sections = [regex]::Matches($Text, $pattern)
    Assert-Protocol ($sections.Count -eq 1) "Expected exactly one '$Heading' section."
    return $sections[0].Groups[1].Value.Trim()
}

function Get-TextHash {
    param([string]$Text)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()
}

$draft = Read-RepositoryText 'docs/QMBT_2R_PROTOCOL.md'
$statuses = [regex]::Matches($draft, '(?m)^Status: .*$')
Assert-Protocol ($statuses.Count -eq 1 -and $statuses[0].Value -ceq 'Status: DRAFT / NOT YET PRE-REGISTERED') 'Draft must not authorize execution or claim pre-registration.'

$blocks = [regex]::Matches($draft, '(?ms)^```json\n(.*?)\n```$')
Assert-Protocol ($blocks.Count -eq 1) 'Expected exactly one JSON static contract.'
$json = $blocks[0].Groups[1].Value
try {
    $document = [System.Text.Json.JsonDocument]::Parse($json)
    try { Assert-NoDuplicateJsonKeys $document.RootElement } finally { $document.Dispose() }
    $contract = ConvertFrom-Json -InputObject $json -AsHashtable -Depth 100
} catch {
    throw "QMBT-2R validation failed: Invalid static contract. $($_.Exception.Message)"
}

$expected = @{
    protocol = 'QMBT-2R'
    status = 'DRAFT / NOT YET PRE-REGISTERED'
    execution_allowed = $false
    ci_live_qloo_allowed = $false
    estimand = 'END_TO_END_PROFILE_CONDITIONED_RETRIEVAL_VS_UNSIGNALED'
    retrieval = 'QUOTA_MATCHED_INDEPENDENT_RETRIEVAL'
    recommendation_source = 'QLOO'
    fixed_pool_rescoring = $false
    synthetic_scores = $false
    zero_imputation = $false
    intersection_only_selection = $false
    llm_venue_reordering = $false
    category_ids = @('art_gallery', 'book_store', 'museum', 'park', 'restaurant', 'shopping_mall')
    quota_per_category = 3
    target_entities_per_condition = 18
    within_category_order = 'QLOO_RETURN_ORDER'
    baseline = 'UNSIGNALED_QLOO_BASELINE'
    baseline_signal_interests_entities = $false
    evaluator_count = 4
    semantic_min_agreement = 3
    baseline_min_agreement = 3
    baseline_both_sides_required = $true
    aggregate_min_positive_cases = 3
    aggregate_case_count = 4
    aggregate_both_cities_required = $true
    aggregate_both_pairs_required = $true
    blind_packet_entities = 18
    answer_key_hidden_until_all_responses = $true
    requires_new_holdout_set = $true
    prior_case_role = 'DEVELOPMENT_DIAGNOSTIC_ONLY'
    holdout_selection_policy = @{
        policy_id = 'COMMIT_SEEDED_FROZEN_POOL_SELECTION_V1'
        city_operationalization_policy = 'QMBT-2R-LOC-DIRECT-QUERY-V1'
        seed_commit_policy = 'SINGLE_SHOT_REMOTE_SEED_COMMIT'
        city_pool_size = 8
        profile_pair_pool_size = 6
        selected_city_count = 2
        selected_profile_pair_count = 2
        confirmatory_cross_product_case_count = 4
        exclude_prior_development_cities = $true
        exclude_prior_seed_entities = $true
        unique_seed_entities_across_pool = $true
        prohibited_theme_exclusion_required = $true
        city_coordinates_role = 'AUDIT_METADATA_ONLY'
        city_preseed_resolution_required = $false
        city_direct_query_manifest = 'config/qmbt-2r/direct-location-queries-v1.json'
        city_direct_query_candidate_count = 8
        confirmatory_location_filter = 'FROZEN_FILTER_LOCATION_QUERY'
        confirmatory_filter_location_radius = 0
        confirmatory_filter_location_query_required = $true
        confirmatory_locality_id_filter_allowed = $false
        confirmatory_wkt_filter_allowed = $false
        confirmatory_geohash_filter_allowed = $false
        confirmatory_signal_location_allowed = $false
        confirmatory_coordinate_filter_allowed = $false
        query_mutation_during_registered_run_allowed = $false
        content_based_location_retry_allowed = $false
        post_seed_city_replacement_allowed = $false
        seed_parent_and_branch_registered_before_commit = $true
        seed_commit_first_remote_schema_match = $true
        seed_alternative_commit_generation_allowed = $false
        ranking_before_remote_seed_confirmation_allowed = $false
        seed_push_retry_requires_same_commit_sha = $true
        seed_commit_history_rewrite_allowed = $false
        ranking_hash = 'SHA256(seed_commit_sha | QMBT-2R | candidate_type | canonical_id)'
        rank_ascending = $true
        canonical_id_collision_tiebreak_ascending = $true
        profile_seed_entity_resolution_after_selection_only = $true
        qloo_recommendation_preflight_allowed = $false
        unresolved_seed_rejects_entire_pair = $true
        single_seed_substitution_allowed = $false
        advance_by_frozen_pair_rank = $true
        pool_expansion_after_resolution_failure_allowed = $false
        final_holdouts_require_post_resolution_commit = $true
        post_first_confirmatory_reselection_allowed = $false
    }
    live_api_policy = @{
        policy_id = 'EXACT_REQUEST_BOUNDED_RETRY_V1'
        max_attempts_per_request = 3
        retryable_outcomes = @('NETWORK_OR_TIMEOUT', 'HTTP_408', 'HTTP_429', 'HTTP_5XX', 'MALFORMED_OR_TRUNCATED_2XX')
        fallback_backoff_seconds = @(2, 8)
        retry_after_max_seconds = 120
        nonretryable_http_4xx_except = @(408, 429)
        retry_payload_mutation_allowed = $false
        accept_first_valid_response = $true
        retry_completed_valid_response = $false
        abort_entire_run_on_nonretryable_or_exhausted = $true
        partial_results_evaluable = $false
        fresh_run_requires_human_authorization = $true
        completed_quota_shortfall_retryable = $false
        development_quota_shortfall_classification = 'DEVELOPMENT_K_NOT_FEASIBLE'
        confirmatory_quota_shortfall_classification = 'CONFIRMATORY_CASE_STRUCTURAL_FAIL'
        exhausted_or_nonretryable_classification = 'INCOMPLETE_EXECUTION_API_OR_TRANSPORT'
    }
    human_decisions = @{
        holdout_selection_procedure = 'COMMIT_SEEDED_FROZEN_POOL_SELECTION_V1'
        city_operationalization = 'QMBT-2R-LOC-DIRECT-QUERY-V1'
        seed_commit_anti_grinding_rule = 'SINGLE_SHOT_REMOTE_SEED_COMMIT'
        final_holdout_identities = 'HUMAN_DECISION_REQUIRED'
        retrieval_depth_K = 18
        depth_development_validation_method = 'PRIOR_CASES_SINGLE_PASS_STRUCTURAL_QUOTA_FEASIBILITY'
        live_api_stop_conditions = 'EXACT_REQUEST_BOUNDED_RETRY_V1'
    }
}
Assert-ContractValue $expected $contract

$directValidator = Join-Path $RepositoryRoot 'scripts/validation/Test-Qmbt2rDirectLocation.ps1'
Assert-Protocol (Test-Path -LiteralPath $directValidator -PathType Leaf) 'Missing direct-location validator.'
try { & $directValidator -RepositoryRoot $RepositoryRoot > $null } catch {
    throw "QMBT-2R validation failed: Direct-location contract failed. $($_.Exception.Message)"
}

$evidencePins = @{
    'docs/QMBT_1_PROTOCOL.md' = '2ca54524c33e45237034dcb76f252e7ff7bba23f8bfee2901e9631099f21f7f6'
    'docs/QMBT_1_INVALID_RUN_20261020.md' = 'f0e098bcccb2222a83460d1b8becf8216b162a34f941d6b2946ac71c88d304b6'
    'docs/QLOO_FIXED_POOL_DIAGNOSTIC.md' = 'e4ac05b9291b28585b55807647dfc85e22ef5b5b74057fcc178ce5f5403c0fed'
    'docs/QLOO_FIXED_POOL_DIAGNOSTIC_RESULT_20261020.md' = '18d44a8ac82f3df78910e9c431b01c5d4ac31782f66d4b81fe8ff7789dd77832'
}
foreach ($relativePath in $evidencePins.Keys) {
    $text = Read-RepositoryText $relativePath
    Assert-Protocol ((Get-TextHash $text) -ceq $evidencePins[$relativePath]) "Protected historical evidence changed: $relativePath. Human review required."
}

$requiredProse = @(
    '`QMBT-2R-LOC-DIRECT-QUERY-V1` supersedes the prior `QMBT-2R-LOC-v1`',
    'No pre-Seed Qloo locality-ID resolution is required.',
    'set `filter.location.query=<frozen direct query>`;',
    'set `filter.location.radius=0`;',
    'do not set `filter.location` to a locality UUID, WKT point, polygon, or other',
    'do not use latitude/longitude or geohash as the operational filter;',
    'do not add `signal.location`.',
    'No recommendation preflight is allowed.',
    'No failed or weak confirmatory output may trigger replacement or reselection.',
    'No live development request is authorized by this protocol amendment.'
)
$draftNormalized = [regex]::Replace($draft, '\s+', ' ')
foreach ($fragment in $requiredProse) {
    $fragmentNormalized = [regex]::Replace($fragment, '\s+', ' ')
    Assert-Protocol ($draftNormalized.Contains($fragmentNormalized)) "Required normative prose changed or disappeared: $fragment"
}

$workflowRoot = Join-Path $RepositoryRoot '.github/workflows'
if (Test-Path -LiteralPath $workflowRoot -PathType Container) {
    $workflows = @(Get-ChildItem -LiteralPath $workflowRoot -Recurse -File |
        Where-Object { $_.Extension -in @('.yml', '.yaml') })
    $forbiddenWorkflowPatterns = @(
        [PSCustomObject]@{ Name = 'Qloo hackathon API host'; Pattern = '(?i)hackathon\.api\.qloo\.com' },
        [PSCustomObject]@{ Name = 'Qloo API key'; Pattern = '(?i)\bQLOO_API_KEY\b' },
        [PSCustomObject]@{ Name = 'Qloo live harness execution'; Pattern = '(?im)^\s*(?:-\s*)?(?:run:\s*)?(?:&\s*)?(?:pwsh\s+)?(?:\.\/)?scripts\/qloo-(?:spikes|preseed)\/[^\r\n]*\.ps1\b' }
    )
    foreach ($workflow in $workflows) {
        $relativePath = [IO.Path]::GetRelativePath($RepositoryRoot, $workflow.FullName).Replace('\', '/')
        $workflowText = [IO.File]::ReadAllText($workflow.FullName).Replace("`r`n", "`n")
        foreach ($rule in $forbiddenWorkflowPatterns) {
            Assert-Protocol (-not [regex]::IsMatch($workflowText, $rule.Pattern)) "Live-Qloo CI indicator '$($rule.Name)' found in $relativePath."
        }
    }
}

$historical = Read-RepositoryText 'docs/QMBT_1_PROTOCOL.md'
foreach ($heading in @('Blind semantic evaluation', 'Baseline evaluation', 'Aggregate success rule')) {
    $frozenSection = Get-UniqueSection $historical $heading
    $draftSection = Get-UniqueSection $draft $heading
    Assert-Protocol ($draftSection -ceq $frozenSection) "Frozen evaluator text changed in '$heading'."
}

Write-Output 'QMBT-2R static validation passed: draft only; K=18, quota-matched independent retrieval, QMBT-2R-LOC-DIRECT-QUERY-V1, radius=0, no geography fallbacks, bounded retry policy, SINGLE_SHOT_REMOTE_SEED_COMMIT, deterministic holdout selection, evaluator rules, historical evidence, and offline-only CI are preserved. No live calls executed.'