# Pure helpers for QMBT-2R pre-Seed locality V2.
# This file performs no network calls and reads no secrets.
Set-StrictMode -Version Latest

$script:Qmbt2rV2SearchBaseUrl = 'https://hackathon.api.qloo.com/search'
$script:Qmbt2rV2LocalityType = 'urn:entity:locality'
$script:Qmbt2rV2Page = 1
$script:Qmbt2rV2Take = 100
$script:Qmbt2rV2SortBy = 'match'
$script:Qmbt2rV2ClassifierId = 'ADMIN1_SEGMENT_IDENTITY_V2'

function Normalize-Qmbt2rV2IdentityText {
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

function Test-Qmbt2rV2NormalizedAlias {
    param(
        [string]$NormalizedValue,
        $Aliases
    )

    if ([string]::IsNullOrWhiteSpace($NormalizedValue)) { return $false }
    foreach ($alias in @($Aliases)) {
        if ($NormalizedValue -ceq (Normalize-Qmbt2rV2IdentityText ([string]$alias))) { return $true }
    }
    return $false
}

function Test-Qmbt2rV2LocalityType {
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

    return @($observed | Where-Object { $_ -ceq $script:Qmbt2rV2LocalityType }).Count -gt 0
}

function Get-Qmbt2rV2IdentityDisambiguation {
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

function Get-Qmbt2rV2DisambiguationSegments {
    param($Row)

    $text = Get-Qmbt2rV2IdentityDisambiguation $Row
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }

    $segments = [Collections.Generic.List[string]]::new()
    foreach ($raw in $text.Split(',')) {
        $normalized = Normalize-Qmbt2rV2IdentityText ([string]$raw)
        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
            $segments.Add($normalized)
        }
    }
    return @($segments)
}

function Test-Qmbt2rV2NameMatch {
    param($Row, $Candidate)

    $nameProperty = $Row.PSObject.Properties['name']
    if ($null -eq $nameProperty) { return $false }
    $actual = Normalize-Qmbt2rV2IdentityText ([string]$nameProperty.Value)
    return (Test-Qmbt2rV2NormalizedAlias -NormalizedValue $actual -Aliases @($Candidate.accepted_names))
}

function Test-Qmbt2rV2IdentityPath {
    param($Row, $Candidate)

    $segments = @(Get-Qmbt2rV2DisambiguationSegments $Row)
    if ($segments.Count -lt 2) { return $false }

    if (-not (Test-Qmbt2rV2NormalizedAlias -NormalizedValue $segments[0] -Aliases @($Candidate.accepted_names))) {
        return $false
    }

    if (-not (Test-Qmbt2rV2NormalizedAlias -NormalizedValue $segments[$segments.Count - 1] -Aliases @($Candidate.country_aliases))) {
        return $false
    }

    if ([bool]$Candidate.city_state) {
        return ($segments.Count -eq 2)
    }

    if ($segments.Count -lt 3) { return $false }
    $interior = @($segments[1..($segments.Count - 2)])
    foreach ($segment in $interior) {
        if (Test-Qmbt2rV2NormalizedAlias -NormalizedValue $segment -Aliases @($Candidate.admin1_aliases)) {
            return $true
        }
    }
    return $false
}

function Resolve-Qmbt2rV2CandidateIdentity {
    param($Candidate, [array]$Results)

    $qualifying = [ordered]@{}
    foreach ($row in $Results) {
        if ($null -eq $row) { continue }
        if (-not (Test-Qmbt2rV2LocalityType $row)) { continue }
        if (-not (Test-Qmbt2rV2NameMatch $row $Candidate)) { continue }
        if (-not (Test-Qmbt2rV2IdentityPath $row $Candidate)) { continue }

        $idProperty = $row.PSObject.Properties['entity_id']
        if ($null -eq $idProperty -or [string]::IsNullOrWhiteSpace([string]$idProperty.Value)) { continue }
        $id = [string]$idProperty.Value
        if (-not $qualifying.Contains($id)) {
            $nameProperty = $row.PSObject.Properties['name']
            $qualifying[$id] = [ordered]@{
                entity_id = $id
                name = [string]$nameProperty.Value
                disambiguation = Get-Qmbt2rV2IdentityDisambiguation $row
                normalized_segments = @(Get-Qmbt2rV2DisambiguationSegments $row)
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
            normalized_segments = @($qualifying[$ids[0]].normalized_segments)
            qualifying_unique_id_count = 1
        }
    }
    if ($ids.Count -eq 0) {
        return [ordered]@{
            classification = 'LOCALITY_UNRESOLVED'
            entity_id = $null
            name = $null
            disambiguation = $null
            normalized_segments = @()
            qualifying_unique_id_count = 0
        }
    }
    return [ordered]@{
        classification = 'LOCALITY_AMBIGUOUS'
        entity_id = $null
        name = $null
        disambiguation = $null
        normalized_segments = @()
        qualifying_unique_id_count = $ids.Count
    }
}

function New-Qmbt2rV2SearchUri {
    param($Candidate)

    $query = [Uri]::EscapeDataString([string]$Candidate.lookup_query)
    $type = [Uri]::EscapeDataString($script:Qmbt2rV2LocalityType)
    return "${script:Qmbt2rV2SearchBaseUrl}?query=$query&types=$type&page=$script:Qmbt2rV2Page&take=$script:Qmbt2rV2Take&sort_by=$script:Qmbt2rV2SortBy"
}
