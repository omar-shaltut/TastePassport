# TastePassport - Taste Translation Validation Spike
# Isolates cross-domain taste translation from agentic refinement and compliance logic.

param(
    [string]$City = "Istanbul",
    [int]$Take = 25,
    [string]$OutputRoot = "artifacts/taste-translation-validation"
)

if (-not $headers -or -not $headers["X-Api-Key"]) {
    throw "Qloo authentication header is missing. Create `$headers first."
}

$ErrorActionPreference = "Stop"
$baseUrl = "https://hackathon.api.qloo.com"
$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$runDir = Join-Path $OutputRoot $runId
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

function Test-QlooEntityType {
    param($Entity, [string]$ExpectedType)
    $types = @()
    if ($Entity.types) { $types += @($Entity.types | ForEach-Object { [string]$_ }) }
    if ($Entity.subtype) { $types += [string]$Entity.subtype }
    if ($Entity.type -and $Entity.type -ne "urn:entity") { $types += [string]$Entity.type }
    return ($types -contains $ExpectedType)
}

function Resolve-TasteSeedStrict {
    param([string]$Name, [string]$ExpectedType)

    $encodedName = [uri]::EscapeDataString($Name)
    $response = Invoke-RestMethod -Uri "$baseUrl/search?query=$encodedName&take=20" -Headers $headers -Method Get
    $results = @($response.results)
    $matches = @($results | Where-Object { $_.name -ieq $Name -and (Test-QlooEntityType $_ $ExpectedType) })

    if ($matches.Count -eq 1) {
        return [PSCustomObject]@{
            InputName = $Name
            ResolvedName = [string]$matches[0].name
            ExpectedType = $ExpectedType
            EntityId = [string]$matches[0].entity_id
            Status = "RESOLVED"
            Candidates = @()
        }
    }

    $candidates = @(
        $results |
        Where-Object { Test-QlooEntityType $_ $ExpectedType } |
        Select-Object -First 10 |
        ForEach-Object { [PSCustomObject]@{ Name = [string]$_.name; EntityId = [string]$_.entity_id } }
    )

    return [PSCustomObject]@{
        InputName = $Name
        ResolvedName = $null
        ExpectedType = $ExpectedType
        EntityId = $null
        Status = if ($matches.Count -gt 1) { "AMBIGUOUS_EXACT_MATCH" } else { "UNRESOLVED" }
        Candidates = $candidates
    }
}

function Get-CategoryText {
    param($Place)
    $parts = @([string]$Place.name)

    if ($Place.tags) {
        $parts += @($Place.tags | ForEach-Object { if ($_.name) { [string]$_.name } })
    }

    foreach ($field in @('category','categories','type','types','subtype','subtypes')) {
        if ($Place.PSObject.Properties[$field]) { $parts += [string]$Place.$field }
        if ($Place.properties -and $Place.properties.PSObject.Properties[$field]) { $parts += [string]$Place.properties.$field }
    }

    return (($parts -join ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
}

function Test-FoodSignal {
    param($Place)
    $text = Get-CategoryText $Place
    return ($text -match '\brestaurant\b|\bcafe\b|\bcoffee\b|\bbakery\b|\bfood\b|\bdessert\b|\bice cream\b|\bdining\b|\bkebab\b')
}

function Get-QlooPlaces {
    param([array]$Seeds, [string]$City, [int]$Take)

    $ids = @($Seeds | ForEach-Object { $_.EntityId })
    $encodedEntities = [uri]::EscapeDataString(($ids -join ','))
    $encodedCity = [uri]::EscapeDataString($City)
    $url = "$baseUrl/v2/insights?filter.type=urn%3Aentity%3Aplace&signal.interests.entities=$encodedEntities&filter.location.query=$encodedCity&filter.location.radius=0&take=$Take"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

    $output = @()
    $rank = 1
    foreach ($place in @($response.results.entities)) {
        $affinity = $null
        if ($place.query -and $null -ne $place.query.affinity) { $affinity = [double]$place.query.affinity }
        $address = $null
        if ($place.properties -and $place.properties.address) { $address = [string]$place.properties.address }

        $output += [PSCustomObject]@{
            Rank = $rank
            Name = [string]$place.name
            EntityId = [string]$place.entity_id
            Affinity = $affinity
            Address = $address
            FoodSignal = [bool](Test-FoodSignal $place)
            CategoryText = Get-CategoryText $place
        }
        $rank++
    }

    return [PSCustomObject]@{ RequestUrl = $url; Candidates = $output }
}

function Get-Jaccard {
    param([array]$A, [array]$B)
    $a = @($A | ForEach-Object { $_.EntityId } | Where-Object { $_ } | Sort-Object -Unique)
    $b = @($B | ForEach-Object { $_.EntityId } | Where-Object { $_ } | Sort-Object -Unique)
    $shared = @($a | Where-Object { $b -contains $_ })
    $union = @($a + $b | Sort-Object -Unique)
    if ($union.Count -eq 0) { return 0.0 }
    return [double]($shared.Count / $union.Count)
}

function Get-Top10Overlap {
    param([array]$A, [array]$B)
    $a = @($A | Select-Object -First 10 | ForEach-Object { $_.EntityId })
    $b = @($B | Select-Object -First 10 | ForEach-Object { $_.EntityId })
    $denominator = [math]::Max(1, [math]::Min(10, [math]::Max($a.Count, $b.Count)))
    $shared = @($a | Where-Object { $b -contains $_ } | Sort-Object -Unique)
    return [double]($shared.Count / $denominator)
}

$profiles = @{
    A = @(
        [PSCustomObject]@{ Name='Interstellar'; Type='urn:entity:movie' },
        [PSCustomObject]@{ Name='MUJI'; Type='urn:entity:brand' },
        [PSCustomObject]@{ Name='The Martian'; Type='urn:entity:book' }
    )
    B = @(
        [PSCustomObject]@{ Name='Ratatouille'; Type='urn:entity:movie' },
        [PSCustomObject]@{ Name='Anthropologie'; Type='urn:entity:brand' },
        [PSCustomObject]@{ Name='The Little Prince'; Type='urn:entity:book' }
    )
}

$resolved = @{}
$failures = @()
foreach ($profileId in @('A','B')) {
    $resolved[$profileId] = @()
    foreach ($seed in $profiles[$profileId]) {
        $item = Resolve-TasteSeedStrict -Name $seed.Name -ExpectedType $seed.Type
        $resolved[$profileId] += $item
        Write-Host ("[{0}] {1} -> {2}" -f $profileId, $seed.Name, $item.Status)
        if ($item.Status -ne 'RESOLVED') { $failures += $item }
    }
}

$resolutionPath = Join-Path $runDir 'seed-resolution.json'
$resolved | ConvertTo-Json -Depth 10 | Set-Content -Path $resolutionPath -Encoding UTF8

if ($failures.Count -gt 0) {
    Write-Host "VALIDATION STOPPED: strict seed resolution failed."
    Write-Host "Inspect:" $resolutionPath
    $failures | Format-Table InputName, ExpectedType, Status -AutoSize
    exit 2
}

$arms = @()
foreach ($profileId in @('A','B')) {
    $target = @($resolved[$profileId])
    $otherId = if ($profileId -eq 'A') { 'B' } else { 'A' }
    $arms += [PSCustomObject]@{ ProfileId=$profileId; ArmId='TARGET'; Seeds=$target }
    $arms += [PSCustomObject]@{ ProfileId=$profileId; ArmId='COUNTERPROFILE'; Seeds=@($resolved[$otherId]) }

    for ($i = 0; $i -lt $target.Count; $i++) {
        $ablated = @()
        for ($j = 0; $j -lt $target.Count; $j++) { if ($j -ne $i) { $ablated += $target[$j] } }
        $arms += [PSCustomObject]@{ ProfileId=$profileId; ArmId=("ABLATE_{0}" -f ($i+1)); Seeds=$ablated }
        $arms += [PSCustomObject]@{ ProfileId=$profileId; ArmId=("SINGLE_{0}" -f ($i+1)); Seeds=@($target[$i]) }
    }
}

$results = @()
foreach ($arm in $arms) {
    Write-Host ("Running {0}/{1}..." -f $arm.ProfileId, $arm.ArmId)
    try {
        $qloo = Get-QlooPlaces -Seeds $arm.Seeds -City $City -Take $Take
        $candidates = @($qloo.Candidates)
        $foodCount = @($candidates | Where-Object FoodSignal).Count
        $foodShare = if ($candidates.Count -gt 0) { [double]($foodCount / $candidates.Count) } else { 0.0 }
        $result = [PSCustomObject]@{
            ProfileId=$arm.ProfileId; ArmId=$arm.ArmId; Status='OK'; City=$City
            Seeds=@($arm.Seeds | Select-Object InputName,ResolvedName,ExpectedType,EntityId)
            CandidateCount=$candidates.Count; FoodSignalShare=$foodShare
            RequestUrl=$qloo.RequestUrl; Candidates=$candidates; Error=$null
        }
    } catch {
        $result = [PSCustomObject]@{
            ProfileId=$arm.ProfileId; ArmId=$arm.ArmId; Status='FAILED'; City=$City
            Seeds=@($arm.Seeds | Select-Object InputName,ResolvedName,ExpectedType,EntityId)
            CandidateCount=0; FoodSignalShare=$null
            RequestUrl=$null; Candidates=@(); Error=$_.Exception.Message
        }
    }
    $results += $result
    $filename = ("{0}-{1}.json" -f $arm.ProfileId,$arm.ArmId).ToLowerInvariant()
    $result | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $runDir $filename) -Encoding UTF8
}

$comparisons = @()
foreach ($profileId in @('A','B')) {
    $target = $results | Where-Object { $_.ProfileId -eq $profileId -and $_.ArmId -eq 'TARGET' -and $_.Status -eq 'OK' } | Select-Object -First 1
    if (-not $target) { continue }

    foreach ($other in @($results | Where-Object { $_.ProfileId -eq $profileId -and $_.ArmId -ne 'TARGET' -and $_.Status -eq 'OK' })) {
        $comparisons += [PSCustomObject]@{
            ProfileId=$profileId
            AgainstArm=$other.ArmId
            Jaccard=(Get-Jaccard -A $target.Candidates -B $other.Candidates)
            Top10Overlap=(Get-Top10Overlap -A $target.Candidates -B $other.Candidates)
        }
    }
}

$answerKey = @()
foreach ($profileId in @('A','B')) {
    $target = $results | Where-Object { $_.ProfileId -eq $profileId -and $_.ArmId -eq 'TARGET' -and $_.Status -eq 'OK' } | Select-Object -First 1
    $counter = $results | Where-Object { $_.ProfileId -eq $profileId -and $_.ArmId -eq 'COUNTERPROFILE' -and $_.Status -eq 'OK' } | Select-Object -First 1
    if (-not $target -or -not $counter) { continue }

    $lists = @(
        [PSCustomObject]@{ Arm='TARGET'; Places=@($target.Candidates | Select-Object -First 10 | Select-Object Name,Address) },
        [PSCustomObject]@{ Arm='COUNTERPROFILE'; Places=@($counter.Candidates | Select-Object -First 10 | Select-Object Name,Address) }
    ) | Sort-Object { Get-Random }

    $publicLists = @()
    for ($i = 0; $i -lt $lists.Count; $i++) {
        $label = [char]([byte][char]'A' + $i)
        $publicLists += [PSCustomObject]@{ Label=[string]$label; Places=$lists[$i].Places }
        $answerKey += [PSCustomObject]@{ ProfileId=$profileId; Label=[string]$label; Arm=$lists[$i].Arm }
    }

    [PSCustomObject]@{
        ProfileId=$profileId
        Seeds=@($resolved[$profileId] | Select-Object InputName,ExpectedType)
        Lists=$publicLists
    } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $runDir ("blind-{0}.json" -f $profileId.ToLowerInvariant())) -Encoding UTF8
}

$summary = [PSCustomObject]@{
    RunId=$runId; City=$City; Take=$Take
    FailedArms=@($results | Where-Object Status -eq 'FAILED' | Select-Object ProfileId,ArmId,Error)
    ArmSummary=@($results | Select-Object ProfileId,ArmId,Status,CandidateCount,FoodSignalShare)
    Comparisons=$comparisons
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $runDir 'summary.json') -Encoding UTF8
$answerKey | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $runDir 'blind-answer-key.json') -Encoding UTF8

Write-Host ""
Write-Host "Taste translation validation run complete."
Write-Host "Output:" $runDir
Write-Host ""
$summary.ArmSummary | Format-Table ProfileId,ArmId,Status,CandidateCount,@{Name='FoodShare';Expression={if ($null -eq $_.FoodSignalShare) {'-'} else {'{0:P0}' -f $_.FoodSignalShare}}} -AutoSize
Write-Host ""
$comparisons | Format-Table ProfileId,AgainstArm,@{Name='Jaccard';Expression={'{0:P1}' -f $_.Jaccard}},@{Name='Top10Overlap';Expression={'{0:P1}' -f $_.Top10Overlap}} -AutoSize
Write-Host ""
Write-Host "Do not show blind-answer-key.json to evaluators."
