$script:Qmbt2rDevBaseUrl = 'https://hackathon.api.qloo.com/v2/insights'
$script:Qmbt2rDevMaxAttempts = 3
$script:Qmbt2rDevBackoffSeconds = @(2, 8)
$script:Qmbt2rDevRetryAfterMaxSeconds = 120
$script:Qmbt2rDevTimeoutSeconds = 30

function New-Qmbt2rDevRequestUri {
    param([string]$LocationQuery, [string]$CategoryTag, [string[]]$SeedIds, [bool]$Unsignaled)

    $uri = $script:Qmbt2rDevBaseUrl + '?filter.type=urn%3Aentity%3Aplace'
    if (-not $Unsignaled) {
        if ($SeedIds.Count -ne 3) { throw 'Personalized request requires exactly three frozen seed entity IDs.' }
        $uri += '&signal.interests.entities=' + ($SeedIds -join ',')
    }
    $uri += '&filter.tags=' + [uri]::EscapeDataString($CategoryTag)
    $uri += '&filter.location.query=' + [uri]::EscapeDataString($LocationQuery)
    $uri += '&filter.location.radius=0&take=18'
    return $uri
}

function Get-Qmbt2rDevRetryAfterSeconds {
    param($Response)
    if (-not $Response.Headers.Contains('Retry-After')) { return $null }
    $raw = [string](@($Response.Headers.GetValues('Retry-After'))[0])
    $seconds = 0
    if ([int]::TryParse($raw, [ref]$seconds)) {
        if ($seconds -lt 0) { return $null }
        return $seconds
    }
    $date = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($raw, [ref]$date)) {
        $seconds = [int][Math]::Ceiling(($date.ToUniversalTime() - [DateTimeOffset]::UtcNow).TotalSeconds)
        if ($seconds -lt 0) { $seconds = 0 }
        return $seconds
    }
    return $null
}

function Invoke-Qmbt2rDevFrozenRequest {
    param(
        [Net.Http.HttpClient]$Client,
        [string]$Uri,
        $Headers,
        [string]$RawDirectory,
        [string]$Slug
    )

    $attempts = [Collections.Generic.List[object]]::new()
    for ($attempt = 1; $attempt -le $script:Qmbt2rDevMaxAttempts; $attempt++) {
        $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, $Uri)
        $request.Headers.Accept.ParseAdd('application/json')
        foreach ($name in @($Headers.Keys)) {
            $request.Headers.TryAddWithoutValidation([string]$name, [string]$Headers[$name]) | Out-Null
        }
        $response = $null
        try {
            try {
                $response = $Client.SendAsync($request).GetAwaiter().GetResult()
            } catch {
                $attempts.Add([ordered]@{ attempt=$attempt; outcome='NETWORK_OR_TIMEOUT'; http_status=$null; retry_after_seconds=$null })
                if ($attempt -ge $script:Qmbt2rDevMaxAttempts) { throw 'INCOMPLETE_EXECUTION_API_OR_TRANSPORT: network/timeout retry budget exhausted.' }
                Start-Sleep -Seconds $script:Qmbt2rDevBackoffSeconds[$attempt - 1]
                continue
            }

            $status = [int]$response.StatusCode
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            [IO.File]::WriteAllText((Join-Path $RawDirectory ("$Slug-attempt-$attempt.json")), $body, [Text.UTF8Encoding]::new($false))

            if ($status -eq 408 -or $status -eq 429 -or ($status -ge 500 -and $status -le 599)) {
                $wait = $script:Qmbt2rDevBackoffSeconds[[Math]::Min($attempt - 1, 1)]
                $retryAfter = $null
                if ($status -eq 429) {
                    $retryAfter = Get-Qmbt2rDevRetryAfterSeconds $response
                    if ($null -ne $retryAfter) {
                        if ($retryAfter -gt $script:Qmbt2rDevRetryAfterMaxSeconds) { throw 'INCOMPLETE_EXECUTION_API_OR_TRANSPORT: Retry-After exceeds 120 seconds.' }
                        $wait = $retryAfter
                    }
                }
                $outcome = if ($status -eq 408) { 'HTTP_408' } elseif ($status -eq 429) { 'HTTP_429' } else { 'HTTP_5XX' }
                $attempts.Add([ordered]@{ attempt=$attempt; outcome=$outcome; http_status=$status; retry_after_seconds=$retryAfter })
                if ($attempt -ge $script:Qmbt2rDevMaxAttempts) { throw 'INCOMPLETE_EXECUTION_API_OR_TRANSPORT: retryable HTTP status exhausted retry budget.' }
                Start-Sleep -Seconds $wait
                continue
            }

            if ($status -ge 300 -and $status -le 499) { throw "INCOMPLETE_EXECUTION_API_OR_TRANSPORT: nonretryable HTTP $status." }
            if ($status -lt 200 -or $status -gt 299) { throw "INCOMPLETE_EXECUTION_API_OR_TRANSPORT: unexpected HTTP $status." }

            $parsed = $null
            try { $parsed = $body | ConvertFrom-Json } catch { $parsed = $null }
            $entitiesProperty = $null
            if ($null -ne $parsed -and $null -ne $parsed.PSObject.Properties['results'] -and $null -ne $parsed.results) {
                $entitiesProperty = $parsed.results.PSObject.Properties['entities']
            }
            if ($null -eq $entitiesProperty) {
                $attempts.Add([ordered]@{ attempt=$attempt; outcome='MALFORMED_OR_TRUNCATED_2XX'; http_status=$status; retry_after_seconds=$null })
                if ($attempt -ge $script:Qmbt2rDevMaxAttempts) { throw 'INCOMPLETE_EXECUTION_API_OR_TRANSPORT: malformed/missing-container 2xx retry budget exhausted.' }
                Start-Sleep -Seconds $script:Qmbt2rDevBackoffSeconds[$attempt - 1]
                continue
            }

            $attempts.Add([ordered]@{ attempt=$attempt; outcome='COMPLETED_VALID_2XX'; http_status=$status; retry_after_seconds=$null })
            return [ordered]@{ status_code=$status; entities=@($entitiesProperty.Value); attempts=@($attempts) }
        } finally {
            if ($null -ne $response) { $response.Dispose() }
            $request.Dispose()
        }
    }
    throw 'INCOMPLETE_EXECUTION_API_OR_TRANSPORT: unreachable retry state.'
}

function Get-Qmbt2rDevEntityIds {
    param([array]$Entities)
    return @($Entities | ForEach-Object { if ($_.entity_id) { [string]$_.entity_id } } | Where-Object { $_ })
}

function Get-Qmbt2rDevQuotaAssembly {
    param([array]$Records)

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($record in $Records) {
        $chosen = [Collections.Generic.List[string]]::new()
        $skips = 0
        foreach ($id in @($record.returned_entity_ids)) {
            if ($seen.Contains($id)) { $skips++; continue }
            if ($chosen.Count -ge 3) { break }
            $null = $seen.Add($id)
            $chosen.Add($id)
        }
        $rows.Add([ordered]@{
            category_id = $record.category_id
            returned_entity_count = $record.returned_entity_count
            distinct_entity_id_count = $record.distinct_entity_id_count
            duplicate_skip_count = $skips
            selected_count = $chosen.Count
            selected_entity_ids = @($chosen)
        })
    }

    return [ordered]@{
        structural_pass = (@($rows | Where-Object { $_.selected_count -ne 3 }).Count -eq 0 -and $seen.Count -eq 18)
        final_unique_entity_count = $seen.Count
        categories = @($rows)
    }
}
