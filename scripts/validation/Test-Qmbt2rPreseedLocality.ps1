param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

# Offline validator for the QMBT-2R pre-Seed locality authorization.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-Preseed {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "QMBT-2R pre-Seed locality validation failed: $Message" }
}

function Read-Text {
    param([string]$RelativePath)
    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-Preseed (Test-Path -LiteralPath $path -PathType Leaf) "Missing $RelativePath."
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
}

function Assert-ExactValue {
    param($Expected, $Actual, [string]$Location)
    if ($Expected -is [Collections.IDictionary]) {
        Assert-Preseed ($Actual -is [Collections.IDictionary]) "$Location must be an object."
        $expectedKeys = @($Expected.Keys | Sort-Object)
        $actualKeys = @($Actual.Keys | Sort-Object)
        Assert-Preseed (($expectedKeys -join '|') -ceq ($actualKeys -join '|')) "$Location fields changed."
        foreach ($key in $expectedKeys) { Assert-ExactValue $Expected[$key] $Actual[$key] "$Location.$key" }
        return
    }
    if ($Expected -is [array]) {
        Assert-Preseed ($Actual -is [array]) "$Location must be an array."
        Assert-Preseed ($Expected.Count -eq $Actual.Count) "$Location length changed."
        for ($i = 0; $i -lt $Expected.Count; $i++) { Assert-ExactValue $Expected[$i] $Actual[$i] "$Location[$i]" }
        return
    }

    $expectedJson = ConvertTo-Json -InputObject $Expected -Compress
    $actualJson = ConvertTo-Json -InputObject $Actual -Compress
    Assert-Preseed ($expectedJson -ceq $actualJson) "$Location changed."
}

$protocolText = Read-Text 'docs/QMBT_2R_PRESEED_LOCALITY.md'
Assert-Preseed ($protocolText -match '(?m)^Status: FROZEN / LIVE LOOKUP AUTHORIZED AFTER REPOSITORY VALIDATION$') 'Authorization status changed.'

$contractMatch = [regex]::Match($protocolText, '(?ms)^```json\n(.*?)\n```$')
Assert-Preseed $contractMatch.Success 'Expected one JSON static contract.'
$contract = ConvertFrom-Json -InputObject $contractMatch.Groups[1].Value -AsHashtable
$expectedContract = @{
    protocol = 'QMBT-2R-PRESEED-LOCALITY'
    status = 'FROZEN_LIVE_LOOKUP_AUTHORIZED_AFTER_REPOSITORY_VALIDATION'
    parent_protocol = 'QMBT-2R-LOC-v1'
    issue = 4
    candidate_count = 8
    endpoint = 'https://hackathon.api.qloo.com/search'
    http_method = 'GET'
    query_source = 'COMMITTED_LOOKUP_QUERY'
    types = 'urn:entity:locality'
    page = 1
    take = 100
    sort_by = 'match'
    coordinates_operational = $false
    insights_allowed = $false
    recommendation_preflight_allowed = $false
    profile_seed_resolution_allowed = $false
    seed_commit_creation_allowed = $false
    ranking_allowed = $false
    identity_fields_only = $true
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
    manual_live_execution_allowed_after_ci = $true
    post_pass_human_review_required = $true
}
Assert-ExactValue $expectedContract $contract 'contract'

$manifestText = Read-Text 'config/qmbt-2r/preseed-localities.json'
$manifest = ConvertFrom-Json -InputObject $manifestText -AsHashtable
$expectedManifest = @{
    protocol = 'QMBT-2R-PRESEED-LOCALITY'
    version = 1
    candidate_count = 8
    candidates = @(
        @{ canonical_id='city:us:new-york-city'; city_label='New York City'; country_code='US'; country_lookup_name='United States of America'; lookup_query='New York City, United States of America'; accepted_names=@('New York City','New York'); country_aliases=@('United States of America','United States'); latitude=40.7128; longitude=-74.0060 },
        @{ canonical_id='city:jp:tokyo'; city_label='Tokyo'; country_code='JP'; country_lookup_name='Japan'; lookup_query='Tokyo, Japan'; accepted_names=@('Tokyo'); country_aliases=@('Japan'); latitude=35.6762; longitude=139.6503 },
        @{ canonical_id='city:fr:paris'; city_label='Paris'; country_code='FR'; country_lookup_name='France'; lookup_query='Paris, France'; accepted_names=@('Paris'); country_aliases=@('France'); latitude=48.8566; longitude=2.3522 },
        @{ canonical_id='city:mx:mexico-city'; city_label='Mexico City'; country_code='MX'; country_lookup_name='Mexico'; lookup_query='Mexico City, Mexico'; accepted_names=@('Mexico City','Ciudad de México','Ciudad de Mexico'); country_aliases=@('Mexico','México'); latitude=19.4326; longitude=-99.1332 },
        @{ canonical_id='city:br:sao-paulo'; city_label='São Paulo'; country_code='BR'; country_lookup_name='Brazil'; lookup_query='São Paulo, Brazil'; accepted_names=@('São Paulo','Sao Paulo'); country_aliases=@('Brazil','Brasil'); latitude=-23.5505; longitude=-46.6333 },
        @{ canonical_id='city:sg:singapore'; city_label='Singapore'; country_code='SG'; country_lookup_name='Singapore'; lookup_query='Singapore, Singapore'; accepted_names=@('Singapore'); country_aliases=@('Singapore'); latitude=1.3521; longitude=103.8198 },
        @{ canonical_id='city:au:sydney'; city_label='Sydney'; country_code='AU'; country_lookup_name='Australia'; lookup_query='Sydney, Australia'; accepted_names=@('Sydney'); country_aliases=@('Australia'); latitude=-33.8688; longitude=151.2093 },
        @{ canonical_id='city:za:cape-town'; city_label='Cape Town'; country_code='ZA'; country_lookup_name='South Africa'; lookup_query='Cape Town, South Africa'; accepted_names=@('Cape Town'); country_aliases=@('South Africa'); latitude=-33.9249; longitude=18.4241 }
    )
}
Assert-ExactValue $expectedManifest $manifest 'manifest'

$harness = Read-Text 'scripts/qloo-preseed/16-qmbt-2r-locality-resolution.ps1'
$requiredHarnessFragments = @(
    '$SearchBaseUrl = ''https://hackathon.api.qloo.com/search''',
    '$LocalityType = ''urn:entity:locality''',
    '$Page = 1',
    '$Take = 100',
    '$SortBy = ''match''',
    '$MaxAttempts = 3',
    '$FallbackBackoffSeconds = @(2, 8)',
    '$RetryAfterMaxSeconds = 120',
    '$env:QLOO_API_KEY',
    'HTTP_404_NO_RESULTS',
    'LOCALITY_UNRESOLVED',
    'LOCALITY_AMBIGUOUS',
    'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT'
)
foreach ($fragment in $requiredHarnessFragments) {
    Assert-Preseed ($harness.Contains($fragment)) "Frozen harness fragment missing: $fragment"
}

Assert-Preseed (-not ($harness -match '(?i)/v2/insights')) 'Harness must not call Insights.'
Assert-Preseed (-not ($harness -match '(?i)filter\.location')) 'Harness must not send operational location filters.'
Assert-Preseed (-not ($harness -match '(?i)signal\.location')) 'Harness must not send location signals.'
Assert-Preseed (-not ($harness -match '(?i)popularity')) 'Harness classifier must not use popularity.'
Assert-Preseed (-not ($harness -match '(?i)affinity')) 'Harness classifier must not use affinity.'
Assert-Preseed (-not ($harness -match '(?i)sort_by=popularity')) 'Harness must not sort by popularity.'
Assert-Preseed (($harness -split 'https://hackathon\.api\.qloo\.com/search').Count -eq 2) 'Harness must contain exactly one frozen Qloo Search endpoint literal.'
Assert-Preseed ($harness -match '(?m)^\s*\[string\]\$RepositoryRoot\s*=') 'Harness may expose only repository-root execution plumbing, not experiment overrides.'

$workflowRoot = Join-Path $RepositoryRoot '.github/workflows'
if (Test-Path -LiteralPath $workflowRoot -PathType Container) {
    foreach ($workflow in @(Get-ChildItem -LiteralPath $workflowRoot -Recurse -File | Where-Object { $_.Extension -in @('.yml','.yaml') })) {
        $text = [IO.File]::ReadAllText($workflow.FullName).Replace("`r`n", "`n")
        Assert-Preseed (-not ($text -match '(?im)^\s*(?:-\s*)?run:\s*.*scripts/qloo-preseed/16-qmbt-2r-locality-resolution\.ps1')) "CI must not invoke the live locality harness: $($workflow.Name)."
        Assert-Preseed (-not ($text -match '(?i)QLOO_API_KEY')) "CI must not reference the Qloo API key: $($workflow.Name)."
    }
}

Assert-Preseed ($protocolText -match 'do \*\*not\*\* create the Seed Commit or compute holdout ranking') 'Post-pass stop gate must remain explicit.'
Assert-Preseed ($protocolText -match 'No other Qloo live operation is authorized') 'Authorization scope must remain narrow.'

Write-Output 'QMBT-2R pre-Seed locality validation passed: exact eight-city Search-only plan frozen; CI live execution blocked; manual live lookup authorized only after repository validation; Seed Commit/ranking remain prohibited.'
