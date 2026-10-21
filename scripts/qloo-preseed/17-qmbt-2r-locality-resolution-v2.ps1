param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

# QMBT-2R pre-Seed locality resolution V2.
# LIVE LOOKUP REQUIRES repository validation for this exact commit AND explicit human authorization.
# This script MUST NOT call Qloo Insights/recommendation endpoints.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'Qmbt2rLocalityV2.Core.ps1')

$PolicyId = 'PRESEED_LOCALITY_EXACT_REQUEST_BOUNDED_RETRY_V1'
$MaxAttempts = 3
$FallbackBackoffSeconds = @(2, 8)
$RetryAfterMaxSeconds = 120
$TimeoutSeconds = 30

function Get-Qmbt2rV2RetryAfterSeconds {
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

function Get-Qmbt2rV2FallbackBackoffSeconds {
    param([int]$Attempt)
    if ($Attempt -eq 1) { return $FallbackBackoffSeconds[0] }
    if ($Attempt -eq 2) { return $FallbackBackoffSeconds[1] }
    return 0
}

function Save-Qmbt2rV2RawBody {
    param([string]$RawDirectory, [string]$Slug, [int]$Attempt, [string]$Body)
    $path = Join-Path $RawDirectory ("{0}-attempt-{1}.json" -f $Slug, $Attempt)
    [IO.File]::WriteAllText($path, $Body, [Text.UTF8Encoding]::new($false))
    return $path
}

function Invoke-Qmbt2rV2FrozenSearchRequest {
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
                Start-Sleep -Seconds (Get-Qmbt2rV2FallbackBackoffSeconds $attempt)
                continue
            }

            $status = [int]$response.StatusCode
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $null = Save-Qmbt2rV2RawBody -RawDirectory $RawDirectory -Slug $Slug -Attempt $attempt -Body $body

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
                $wait = Get-Qmbt2rV2FallbackBackoffSeconds $attempt
                $retryAfter = $null
                if ($status -eq 429) {
                    $retryAfter = Get-Qmbt2rV2RetryAfterSeconds $response
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
                Start-Sleep -Seconds (Get-Qmbt2rV2FallbackBackoffSeconds $attempt)
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
                Start-Sleep -Seconds (Get-Qmbt2rV2FallbackBackoffSeconds $attempt)
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

$manifestPath = Join-Path $RepositoryRoot 'config/qmbt-2r/preseed-localities-v2.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Frozen V2 locality manifest is missing.'
}

if ([string]::IsNullOrWhiteSpace($env:QLOO_API_KEY)) {
    throw 'QLOO_API_KEY is not set in the process environment. Do not paste or commit the key.'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([int]$manifest.candidate_count -ne 8 -or @($manifest.candidates).Count -ne 8) {
    throw 'Frozen V2 locality manifest must contain exactly eight candidates.'
}
if ([string]$manifest.classifier -cne $script:Qmbt2rV2ClassifierId) {
    throw 'Frozen V2 locality classifier identifier changed.'
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$runDirectory = Join-Path $RepositoryRoot ("artifacts/qmbt-2r-preseed-locality-v2/$timestamp")
$rawDirectory = Join-Path $runDirectory 'raw'
$null = New-Item -ItemType Directory -Path $rawDirectory -Force
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $runDirectory 'preseed-localities-v2.json')

$summary = [ordered]@{
    protocol = 'QMBT-2R-PRESEED-LOCALITY-V2'
    classifier = $script:Qmbt2rV2ClassifierId
    policy_id = $PolicyId
    started_at_utc = [DateTime]::UtcNow.ToString('o')
    status = 'RUNNING'
    candidates = [Collections.Generic.List[object]]::new()
}

function Write-Qmbt2rV2Summary {
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
        $uri = New-Qmbt2rV2SearchUri $candidate
        $slug = ([string]$candidate.canonical_id) -replace '[^a-zA-Z0-9.-]+', '-'

        try {
            $transport = Invoke-Qmbt2rV2FrozenSearchRequest -Client $client -Uri $uri -ApiKey $env:QLOO_API_KEY -RawDirectory $rawDirectory -Slug $slug
        } catch {
            $summary.status = 'PRESEED_LOCALITY_PASS_INCOMPLETE_API_OR_TRANSPORT'
            $summary.failure_candidate = [string]$candidate.canonical_id
            $summary.failure_message = $_.Exception.Message
            Write-Qmbt2rV2Summary
            throw
        }

        $identity = Resolve-Qmbt2rV2CandidateIdentity -Candidate $candidate -Results @($transport.results)
        $record = [ordered]@{
            canonical_id = [string]$candidate.canonical_id
            city_label = [string]$candidate.city_label
            country_code = [string]$candidate.country_code
            lookup_query = [string]$candidate.lookup_query
            request_uri = $uri
            final_http_status = $transport.status_code
            attempts = @($transport.attempts)
            classifier = $script:Qmbt2rV2ClassifierId
            classification = $identity.classification
            qualifying_unique_id_count = $identity.qualifying_unique_id_count
            entity_id = $identity.entity_id
            resolved_name = $identity.name
            disambiguation = $identity.disambiguation
            normalized_disambiguation_segments = @($identity.normalized_segments)
        }
        $summary.candidates.Add($record)

        if ($identity.classification -cne 'LOCALITY_RESOLVED') {
            $summary.status = $identity.classification
            $summary.failure_candidate = [string]$candidate.canonical_id
            Write-Qmbt2rV2Summary
            throw "Pre-Seed locality V2 stopped: $($candidate.canonical_id) => $($identity.classification)."
        }
    }

    $summary.status = 'PRESEED_LOCALITY_V2_RESOLUTION_PASS'
    Write-Qmbt2rV2Summary
    Write-Output "Pre-Seed locality V2 PASS. Review $runDirectory before any Seed Commit or ranking."
} finally {
    $client.Dispose()
    $handler.Dispose()
}
