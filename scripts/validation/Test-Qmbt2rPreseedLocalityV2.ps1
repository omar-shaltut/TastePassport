param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

# Offline validator for QMBT-2R pre-Seed locality V2.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-V2 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "QMBT-2R pre-Seed locality V2 validation failed: $Message" }
}

function Read-V2Text {
    param([string]$RelativePath)
    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-V2 (Test-Path -LiteralPath $path -PathType Leaf) "Missing $RelativePath."
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
}

function Assert-V2ExactValue {
    param($Expected, $Actual, [string]$Location)
    if ($Expected -is [Collections.IDictionary]) {
        Assert-V2 ($Actual -is [Collections.IDictionary]) "$Location must be an object."
        $expectedKeys = @($Expected.Keys | Sort-Object)
        $actualKeys = @($Actual.Keys | Sort-Object)
        Assert-V2 (($expectedKeys -join '|') -ceq ($actualKeys -join '|')) "$Location fields changed."
        foreach ($key in $expectedKeys) { Assert-V2ExactValue $Expected[$key] $Actual[$key] "$Location.$key" }
        return
    }
    if ($Expected -is [array]) {
        Assert-V2 ($Actual -is [array]) "$Location must be an array."
        Assert-V2 ($Expected.Count -eq $Actual.Count) "$Location length changed."
        for ($i = 0; $i -lt $Expected.Count; $i++) { Assert-V2ExactValue $Expected[$i] $Actual[$i] "$Location[$i]" }
        return
    }

    $expectedJson = ConvertTo-Json -InputObject $Expected -Compress
    $actualJson = ConvertTo-Json -InputObject $Actual -Compress
    Assert-V2 ($expectedJson -ceq $actualJson) "$Location changed."
}

$protocolText = Read-V2Text 'docs/QMBT_2R_PRESEED_LOCALITY_V2.md'
Assert-V2 ($protocolText -match '(?m)^Status: FROZEN DESIGN / LIVE LOOKUP REQUIRES REPOSITORY VALIDATION \+ EXPLICIT HUMAN AUTHORIZATION$') 'V2 status changed.'

$contractMatch = [regex]::Match($protocolText, '(?ms)^```json\n(.*?)\n```$')
Assert-V2 $contractMatch.Success 'Expected one V2 JSON static contract.'
$contract = ConvertFrom-Json -InputObject $contractMatch.Groups[1].Value -AsHashtable
$expectedContract = @{
    protocol = 'QMBT-2R-PRESEED-LOCALITY-V2'
    status = 'FROZEN_DESIGN_LIVE_REQUIRES_CI_AND_EXPLICIT_HUMAN_AUTHORIZATION'
    parent_protocol = 'QMBT-2R-LOC-v1'
    predecessor = 'QMBT-2R-PRESEED-LOCALITY'
    issue = 6
    candidate_count = 8
    endpoint = 'https://hackathon.api.qloo.com/search'
    http_method = 'GET'
    query_source = 'COMMITTED_CITY_ADMIN1_COUNTRY_LOOKUP_QUERY'
    types = 'urn:entity:locality'
    page = 1
    take = 100
    sort_by = 'match'
    classifier = 'ADMIN1_SEGMENT_IDENTITY_V2'
    disambiguation_split_before_normalization = $true
    admin1_required_for_non_city_state = $true
    city_state_exact_two_segment_rule = $true
    observed_entity_id_allowlist_allowed = $false
    coordinates_operational = $false
    insights_allowed = $false
    recommendation_preflight_allowed = $false
    profile_seed_resolution_allowed = $false
    seed_commit_creation_allowed = $false
    ranking_allowed = $false
    result_order_selects_winner = $false
    retry_policy = 'PRESEED_LOCALITY_EXACT_REQUEST_BOUNDED_RETRY_V1'
    max_attempts = 3
    fallback_backoff_seconds = @(2, 8)
    retry_after_max_seconds = 120
    http_404_is_unresolved_no_retry = $true
    completed_content_retry_allowed = $false
    stop_on_first_identity_failure = $true
    automatic_city_replacement_allowed = $false
    ci_live_execution_allowed = $false
    ci_success_auto_authorizes_live = $false
    explicit_human_live_authorization_required = $true
    post_pass_human_review_required = $true
}
Assert-V2ExactValue $expectedContract $contract 'contract'

$manifestText = Read-V2Text 'config/qmbt-2r/preseed-localities-v2.json'
$manifest = ConvertFrom-Json -InputObject $manifestText -AsHashtable
$expectedManifest = @{
    protocol = 'QMBT-2R-PRESEED-LOCALITY-V2'
    version = 2
    classifier = 'ADMIN1_SEGMENT_IDENTITY_V2'
    candidate_count = 8
    candidates = @(
        @{ canonical_id='city:us:new-york-city'; city_label='New York City'; country_code='US'; admin1_lookup_name='New York'; country_lookup_name='United States of America'; lookup_query='New York City, New York, United States of America'; accepted_names=@('New York City','New York'); admin1_aliases=@('New York'); country_aliases=@('United States of America','United States'); city_state=$false; latitude=40.7128; longitude=-74.006 },
        @{ canonical_id='city:jp:tokyo'; city_label='Tokyo'; country_code='JP'; admin1_lookup_name='Tokyo'; country_lookup_name='Japan'; lookup_query='Tokyo, Tokyo, Japan'; accepted_names=@('Tokyo'); admin1_aliases=@('Tokyo'); country_aliases=@('Japan'); city_state=$false; latitude=35.6762; longitude=139.6503 },
        @{ canonical_id='city:fr:paris'; city_label='Paris'; country_code='FR'; admin1_lookup_name='Île-de-France'; country_lookup_name='France'; lookup_query='Paris, Île-de-France, France'; accepted_names=@('Paris'); admin1_aliases=@('Île-de-France','Ile-de-France','Ile de France'); country_aliases=@('France'); city_state=$false; latitude=48.8566; longitude=2.3522 },
        @{ canonical_id='city:mx:mexico-city'; city_label='Mexico City'; country_code='MX'; admin1_lookup_name='Mexico City'; country_lookup_name='Mexico'; lookup_query='Mexico City, Mexico City, Mexico'; accepted_names=@('Mexico City','Ciudad de México','Ciudad de Mexico'); admin1_aliases=@('Mexico City','Ciudad de México','Ciudad de Mexico'); country_aliases=@('Mexico','México'); city_state=$false; latitude=19.4326; longitude=-99.1332 },
        @{ canonical_id='city:br:sao-paulo'; city_label='São Paulo'; country_code='BR'; admin1_lookup_name='São Paulo'; country_lookup_name='Brazil'; lookup_query='São Paulo, São Paulo, Brazil'; accepted_names=@('São Paulo','Sao Paulo'); admin1_aliases=@('São Paulo','Sao Paulo'); country_aliases=@('Brazil','Brasil'); city_state=$false; latitude=-23.5505; longitude=-46.6333 },
        @{ canonical_id='city:sg:singapore'; city_label='Singapore'; country_code='SG'; admin1_lookup_name=$null; country_lookup_name='Singapore'; lookup_query='Singapore, Singapore'; accepted_names=@('Singapore'); admin1_aliases=@(); country_aliases=@('Singapore'); city_state=$true; latitude=1.3521; longitude=103.8198 },
        @{ canonical_id='city:au:sydney'; city_label='Sydney'; country_code='AU'; admin1_lookup_name='New South Wales'; country_lookup_name='Australia'; lookup_query='Sydney, New South Wales, Australia'; accepted_names=@('Sydney'); admin1_aliases=@('New South Wales','NSW'); country_aliases=@('Australia'); city_state=$false; latitude=-33.8688; longitude=151.2093 },
        @{ canonical_id='city:za:cape-town'; city_label='Cape Town'; country_code='ZA'; admin1_lookup_name='Western Cape'; country_lookup_name='South Africa'; lookup_query='Cape Town, Western Cape, South Africa'; accepted_names=@('Cape Town'); admin1_aliases=@('Western Cape'); country_aliases=@('South Africa'); city_state=$false; latitude=-33.9249; longitude=18.4241 }
    )
}
Assert-V2ExactValue $expectedManifest $manifest 'manifest'

foreach ($candidate in @($manifest.candidates)) {
    Assert-V2 (-not $candidate.ContainsKey('entity_id')) "Manifest must not pin a Qloo entity ID for $($candidate.canonical_id)."
    Assert-V2 (-not $candidate.ContainsKey('expected_entity_id')) "Manifest must not contain expected entity IDs for $($candidate.canonical_id)."
    Assert-V2 (-not $candidate.ContainsKey('allowed_entity_ids')) "Manifest must not contain an ID allowlist for $($candidate.canonical_id)."
}

$core = Read-V2Text 'scripts/qloo-preseed/Qmbt2rLocalityV2.Core.ps1'
$requiredCoreFragments = @(
    "`$script:Qmbt2rV2SearchBaseUrl = 'https://hackathon.api.qloo.com/search'",
    "`$script:Qmbt2rV2LocalityType = 'urn:entity:locality'",
    "`$script:Qmbt2rV2Take = 100",
    "`$script:Qmbt2rV2SortBy = 'match'",
    "`$script:Qmbt2rV2ClassifierId = 'ADMIN1_SEGMENT_IDENTITY_V2'",
    "`$text.Split(',')",
    'Candidate.admin1_aliases',
    'Candidate.city_state',
    'Resolve-Qmbt2rV2CandidateIdentity',
    'New-Qmbt2rV2SearchUri'
)
foreach ($fragment in $requiredCoreFragments) {
    Assert-V2 ($core.Contains($fragment)) "Frozen V2 core fragment missing: $fragment"
}

$harness = Read-V2Text 'scripts/qloo-preseed/17-qmbt-2r-locality-resolution-v2.ps1'
$requiredHarnessFragments = @(
    'Qmbt2rLocalityV2.Core.ps1',
    "`$PolicyId = 'PRESEED_LOCALITY_EXACT_REQUEST_BOUNDED_RETRY_V1'",
    '$MaxAttempts = 3',
    '$FallbackBackoffSeconds = @(2, 8)',
    '$RetryAfterMaxSeconds = 120',
    '$env:QLOO_API_KEY',
    'preseed-localities-v2.json',
    'qmbt-2r-preseed-locality-v2',
    'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT'
)
foreach ($fragment in $requiredHarnessFragments) {
    Assert-V2 ($harness.Contains($fragment)) "Frozen V2 harness fragment missing: $fragment"
}

$combinedRuntime = $core + "`n" + $harness
Assert-V2 ($combinedRuntime.Contains('LOCALITY_UNRESOLVED')) 'V2 runtime must preserve unresolved classification.'
Assert-V2 ($combinedRuntime.Contains('LOCALITY_AMBIGUOUS')) 'V2 runtime must preserve ambiguous classification.'
Assert-V2 (-not ($combinedRuntime -match '(?i)/v2/insights')) 'V2 runtime must not call Insights.'
Assert-V2 (-not ($combinedRuntime -match '(?i)filter\.location')) 'V2 runtime must not send operational location filters.'
Assert-V2 (-not ($combinedRuntime -match '(?i)signal\.location')) 'V2 runtime must not send location signals.'
Assert-V2 (-not ($combinedRuntime -match '(?i)sort_by=popularity')) 'V2 runtime must not change Search sorting.'
Assert-V2 (($core -split 'https://hackathon\.api\.qloo\.com/search').Count -eq 2) 'V2 core must contain exactly one frozen Search endpoint literal.'
Assert-V2 ($harness -match '(?m)^\s*\[string\]\$RepositoryRoot\s*=') 'V2 harness may expose only repository-root execution plumbing.'

$workflowRoot = Join-Path $RepositoryRoot '.github/workflows'
if (Test-Path -LiteralPath $workflowRoot -PathType Container) {
    foreach ($workflow in @(Get-ChildItem -LiteralPath $workflowRoot -Recurse -File | Where-Object { $_.Extension -in @('.yml','.yaml') })) {
        $text = [IO.File]::ReadAllText($workflow.FullName).Replace("`r`n", "`n")
        Assert-V2 (-not ($text -match '(?im)^\s*(?:-\s*)?run:\s*.*scripts/qloo-preseed/17-qmbt-2r-locality-resolution-v2\.ps1')) "CI must not invoke the V2 live harness: $($workflow.Name)."
        Assert-V2 (-not ($text -match '(?i)QLOO_API_KEY')) "CI must not reference the Qloo API key: $($workflow.Name)."
    }
}

Assert-V2 ($protocolText -match 'Passing CI does \*\*not\*\* itself authorize a live V2 lookup') 'Explicit post-CI human authorization gate must remain.'
Assert-V2 ($protocolText -match 'stop for explicit human review before any Seed Commit or ranking') 'Post-pass Seed/ranking stop gate must remain.'

Write-Output 'QMBT-2R pre-Seed locality V2 validation passed: admin-path identity rule frozen; observed IDs not pinned; CI live execution blocked; explicit human live authorization still required.'
