param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

# QMBT-2R pre-Seed locality resolution.
# LIVE LOOKUP AUTHORIZED only after repository validation passes for this exact harness.
# This script MUST NOT call Qloo Insights/recommendation endpoints.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$PolicyId = 'PRESEED_LOCALITY_EXACT_REQUEST_BOUNDED_RETRY_V1'
$SearchBaseUrl = 'https://hackathon.api.qloo.com/search'
$LocalityType = 'urn:entity:locality'
$Page = 1
$Take = 100
$SortBy = 'match'
$MaxAttempts = 3
$FallbackBackoffSeconds = @(2, 8)
$RetryAfterMaxSeconds = 120
$TimeoutSeconds = 30

function Normalize-IdentityText {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }

    $decomposed = $Value.Normalize([Text.NormalizationForm]::FormD)
    $builder = [Text.StringBuilder]::new()
    foreach ($character in $decomposed.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            $null = $builder.Append($character)
        }
    }

    $lower = $builder.ToString().Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
    return ([regex]::Replace($lower, '[^a-z0-9]+', ' ')).Trim()
}

function Test-LocalityType {
    param($Row)

    $observed = @()
    $typesProperty = $Row.PSObject.Properties['types']
    if ($null -ne $typesProperty -and $null -ne $typesProperty.Value) {
        $observed += @($typesProperty.Value | ForEach-Object { [string]$_ })
    }

    $subtypeProperty = $Row.PSObject.Properties['subtype']
    if ($null -ne $subtypeProperty -and $null -ne $subtypeProperty.Value) {
        $observed += [string]$subtypeProperty.Value
    }

    return @($observed | Where-Object { $_ -ceq $LocalityType }).Count -gt 0
}

function Get-IdentityDisambiguation {
    param($Row)

    $direct = $Row.PSObject.Properties['disambiguation']
    if ($null -ne $direct -and -not [string]::IsNullOrWhiteSpace([string]$direct.Value)) {
        return [string]$direct.Value
    }

    $properties = $Row.PSObject.Properties['properties']
    if ($null -ne $properties -and $null -ne $properties.Value) {
        $nested = $properties.Value.PSObject.Properties['disambiguation']
        if ($null -ne $nested -and -not [string]::IsNullOrWhiteSpace([string]$nested.Value)) {
            return [string]$nested.Value
        }
    }

    return ''
}

function Test-NameMatch {
    param($Row, $Candidate)

    $nameProperty = $Row.PSObject.Properties['name']
    if ($null -eq $nameProperty) { return $false }
    $actual = Normalize-IdentityText ([string]$nameProperty.Value)
    if ([string]::IsNullOrWhiteSpace($actual)) { return $false }

    foreach ($accepted in @($Candidate.accepted_names)) {
        if ($actual -ceq (Normalize-IdentityText ([string]$accepted))) { return $true }
    }
    return $false
}

function Test-CountryMatch {
    param($Row, $Candidate)

    $disambiguation = Normalize-IdentityText (Get-IdentityDisambiguation $Row)
    if ([string]::IsNullOrWhiteSpace($disambiguation)) { return $false }

    $padded = ' ' + $disambiguation + ' '
    foreach ($alias in @($Candidate.country_aliases)) {
        $normalizedAlias = Normalize-IdentityText ([string]$alias)
        if (-not [string]::IsNullOrWhiteSpace($normalizedAlias) -and $padded.Contains(' ' + $normalizedAlias + ' ')) {
            return $true
        }
    }
    return $false
}

function Get-RetryAfterSeconds {
    param($Response)

    if (-not $Response.Headers.Contains('Retry-After')) { return $null }
    $raw = [string](@($Response.Headers.GetValues('Retry-After'))[0])

    $delta = 0
    if ([int]::TryParse($raw, [ref]$delta)) {
        if ($delta -lt 0) { return $null }
        return $delta
    }

    $date = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($raw, [ref]$date)) {
        $seconds = [int][Math]::Ceiling(($date.ToUniversalTime() - [DateTimeOffset]::UtcNow).TotalSeconds)
        if ($seconds -lt 0) { $seconds = 0 }
        return $seconds
    }

    return $null
}

function Get-FallbackBackoffSeconds {
    param([int]$Attempt)
    if ($Attempt -eq 1) { return $FallbackBackoffSeconds[0] }
    if ($Attempt -eq 2) { return $FallbackBackoffSeconds[1] }
    return 0
}

function New-FrozenSearchUri {
    param($Candidate)

    $query = [Uri]::EscapeDataString([string]$Candidate.lookup_query)
    $type = [Uri]::EscapeDataString($LocalityType)
    return "${SearchBaseUrl}?query=$query&types=$type&page=$Page&take=$Take&sort_by=$SortBy"
}

function Save-RawBody {
    param([string]$RawDirectory, [string]$Slug, [int]$Attempt, [string]$Body)
    $path = Join-Path $RawDirectory ("{0}-attempt-{1}.json" -f $Slug, $Attempt)
    [IO.File]::WriteAllText($path, $Body, [Text.UTF8Encoding]::new($false))
    return $path
}

function Invoke-FrozenSearchRequest {
    param(
        [Net.Http.HttpClient]$Client,
        [string]$Uri,
        [string]$ApiKey,
        [string]$RawDirectory,
        [string]$Slug
    )

    $attemptLog = [Collections.Generic.List[object]]::new()

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, $Uri)
        $request.Headers.Accept.ParseAdd('application/json')
        $request.Headers.Add('X-Api-Key', $ApiKey)
        $response = $null

        try {
            try {
                $response = $Client.SendAsync($request).GetAwaiter().GetResult()
            } catch {
                $attemptLog.Add([ordered]@{
                    attempt = $attempt
                    outcome = 'NETWORK_OR_TIMEOUT'
                    http_status = $null
                    retry_after_seconds = $null
                })
                if ($attempt -ge $MaxAttempts) {
                    throw 'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT: network/timeout retry budget exhausted.'
                }
                Start-Sleep -Seconds (Get-FallbackBackoffSeconds $attempt)
                continue
            }

            $status = [int]$response.StatusCode
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $null = Save-RawBody -RawDirectory $RawDirectory -Slug $Slug -Attempt $attempt -Body $body

            if ($status -eq 404) {
                $attemptLog.Add([ordered]@{
                    attempt = $attempt
                    outcome = 'HTTP_404_NO_RESULTS'
                    http_status = $status
                    retry_after_seconds = $null
                })
                return [ordered]@{ status_code = $status; results = @(); attempts = @($attemptLog) }
            }

            $retryableStatus = ($status -eq 408 -or $status -eq 429 -or ($status -ge 500 -and $status -le 599))
            if ($retryableStatus) {
                $wait = Get-FallbackBackoffSeconds $attempt
                $retryAfter = $null
                if ($status -eq 429) {
                    $retryAfter = Get-RetryAfterSeconds $response
                    if ($null -ne $retryAfter) {
                        if ($retryAfter -gt $RetryAfterMaxSeconds) {
                            throw 'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT: Retry-After exceeds 120 seconds.'
                        }
                        $wait = $retryAfter
                    }
                }

                $attemptLog.Add([ordered]@{
                    attempt = $attempt
                    outcome = if ($status -eq 408) { 'HTTP_408' } elseif ($status -eq 429) { 'HTTP_429' } else { 'HTTP_5XX' }
                    http_status = $status
                    retry_after_seconds = $retryAfter
                })

                if ($attempt -ge $MaxAttempts) {
                    throw 'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT: retryable HTTP status exhausted retry budget.'
                }
                Start-Sleep -Seconds $wait
                continue
            }

            if ($status -ge 300 -and $status -le 499) {
                throw "PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT: nonretryable HTTP $status."
            }

            if ($status -lt 200 -or $status -gt 299) {
                throw "PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT: unexpected HTTP $status."
            }

            $parsed = $null
            try {
                $parsed = $body | ConvertFrom-Json
            } catch {
                $attemptLog.Add([ordered]@{
                    attempt = $attempt
                    outcome = 'MALFORMED_OR_TRUNCATED_2XX'
                    http_status = $status
                    retry_after_seconds = $null
                })
                if ($attempt -ge $MaxAttempts) {
                    throw 'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT: malformed 2xx retry budget exhausted.'
                }
                Start-Sleep -Seconds (Get-FallbackBackoffSeconds $attempt)
                continue
            }

            $resultsProperty = $parsed.PSObject.Properties['results']
            if ($null -eq $resultsProperty) {
                $attemptLog.Add([ordered]@{
                    attempt = $attempt
                    outcome = 'MALFORMED_OR_TRUNCATED_2XX'
                    http_status = $status
                    retry_after_seconds = $null
                })
                if ($attempt -ge $MaxAttempts) {
                    throw 'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT: 2xx missing results container after retry budget.'
                }
                Start-Sleep -Seconds (Get-FallbackBackoffSeconds $attempt)
                continue
            }

            $attemptLog.Add([ordered]@{
                attempt = $attempt
                outcome = 'COMPLETED_VALID_2XX'
                http_status = $status
                retry_after_seconds = $null
            })
            return [ordered]@{ status_code = $status; results = @($resultsProperty.Value); attempts = @($attemptLog) }
        } finally {
            if ($null -ne $response) { $response.Dispose() }
            $request.Dispose()
        }
    }

    throw 'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT: unreachable retry state.'
}

function Resolve-CandidateIdentity {
    param($Candidate, [array]$Results)

    $qualifying = [ordered]@{}
    foreach ($row in $Results) {
        if ($null -eq $row) { continue }
        if (-not (Test-LocalityType $row)) { continue }
        if (-not (Test-NameMatch $row $Candidate)) { continue }
        if (-not (Test-CountryMatch $row $Candidate)) { continue }

        $idProperty = $row.PSObject.Properties['entity_id']
        if ($null -eq $idProperty -or [string]::IsNullOrWhiteSpace([string]$idProperty.Value)) { continue }
        $id = [string]$idProperty.Value
        if (-not $qualifying.Contains($id)) {
            $nameProperty = $row.PSObject.Properties['name']
            $qualifying[$id] = [ordered]@{
                entity_id = $id
                name = [string]$nameProperty.Value
                disambiguation = Get-IdentityDisambiguation $row
            }
        }
    }

    $ids = @($qualifying.Keys)
    if ($ids.Count -eq 1) {
        return [ordered]@{
            classification = 'LOCALITY_RESOLVED'
            entity_id = $ids[0]
            name = $qualifying[$ids[0]].name
            disambiguation = $qualifying[$ids[0]].disambiguation
            qualifying_unique_id_count = 1
        }
    }
    if ($ids.Count -eq 0) {
        return [ordered]@{
            classification = 'LOCALITY_UNRESOLVED'
            entity_id = $null
            name = $null
            disambiguation = $null
            qualifying_unique_id_count = 0
        }
    }
    return [ordered]@{
        classification = 'LOCALITY_AMBIGUOUS'
        entity_id = $null
        name = $null
        disambiguation = $null
        qualifying_unique_id_count = $ids.Count
    }
}

$manifestPath = Join-Path $RepositoryRoot 'config/qmbt-2r/preseed-localities.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Frozen locality manifest is missing.'
}

if ([string]::IsNullOrWhiteSpace($env:QLOO_API_KEY)) {
    throw 'QLOO_API_KEY is not set in the process environment. Do not paste or commit the key.'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([int]$manifest.candidate_count -ne 8 -or @($manifest.candidates).Count -ne 8) {
    throw 'Frozen locality manifest must contain exactly eight candidates.'
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$runDirectory = Join-Path $RepositoryRoot ("artifacts/qmbt-2r-preseed-locality/$timestamp")
$rawDirectory = Join-Path $runDirectory 'raw'
$null = New-Item -ItemType Directory -Path $rawDirectory -Force
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $runDirectory 'preseed-localities.json')

$summary = [ordered]@{
    protocol = 'QMBT-2R-PRESEED-LOCALITY'
    policy_id = $PolicyId
    started_at_utc = [DateTime]::UtcNow.ToString('o')
    status = 'RUNNING'
    candidates = [Collections.Generic.List[object]]::new()
}

function Write-Summary {
    $summary.completed_at_utc = [DateTime]::UtcNow.ToString('o')
    $json = ConvertTo-Json -InputObject $summary -Depth 20
    [IO.File]::WriteAllText((Join-Path $runDirectory 'summary.json'), $json, [Text.UTF8Encoding]::new($false))
}

Add-Type -AssemblyName System.Net.Http
$handler = [Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $false
$client = [Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)

try {
    foreach ($candidate in @($manifest.candidates)) {
        $uri = New-FrozenSearchUri $candidate
        $slug = ([string]$candidate.canonical_id) -replace '[^a-zA-Z0-9.-]+', '-'

        try {
            $transport = Invoke-FrozenSearchRequest -Client $client -Uri $uri -ApiKey $env:QLOO_API_KEY -RawDirectory $rawDirectory -Slug $slug
        } catch {
            $summary.status = 'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT'
            $summary.failure_candidate = [string]$candidate.canonical_id
            $summary.failure_message = $_.Exception.Message
            Write-Summary
            throw
        }

        $identity = Resolve-CandidateIdentity -Candidate $candidate -Results @($transport.results)
        $record = [ordered]@{
            canonical_id = [string]$candidate.canonical_id
            city_label = [string]$candidate.city_label
            country_code = [string]$candidate.country_code
            lookup_query = [string]$candidate.lookup_query
            request_uri = $uri
            final_http_status = $transport.status_code
            attempts = @($transport.attempts)
            classification = $identity.classification
            qualifying_unique_id_count = $identity.qualifying_unique_id_count
            entity_id = $identity.entity_id
            resolved_name = $identity.name
            disambiguation = $identity.disambiguation
        }
        $summary.candidates.Add($record)

        if ($identity.classification -cne 'LOCALITY_RESOLVED') {
            $summary.status = $identity.classification
            $summary.failure_candidate = [string]$candidate.canonical_id
            Write-Summary
            throw "Pre-Seed locality resolution stopped: $($candidate.canonical_id) => $($identity.classification)."
        }
    }

    $summary.status = 'PRESEED_LOCALITY_RESOLUTION_PASS'
    Write-Summary
    Write-Output "Pre-Seed locality resolution PASS. Review $runDirectory before any Seed Commit or ranking."
} finally {
    $client.Dispose()
    $handler.Dispose()
}
