# ============================================================
#  雨滴插件 - 每日一语（傲娇毒舌版）
#  需要 PowerShell 3.0+，Rainmeter 调用请加 -STA 参数
#  示例：powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "quote.ps1"
# ============================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------- 【修改这里 1】API 地址 ----------
# 填你使用的服务商的 chat/completions 完整地址。
# 必须是 OpenAI 兼容格式，且以 /chat/completions 结尾，
# 脚本会自动把这段替换成 /models 来拉取模型列表。
$url = "https://你的服务商域名/v1/chat/completions"

# ---------- 【修改这里 2】API Key ----------
# 千万不要把真实 key 提交到 GitHub！
# 推荐改成读环境变量或本地 config.json（见 README / .gitignore）
$apiKey = "sk-在这里填你的API-Key"

# ---------- 【修改这里 3】默认模型 ----------
# 第一次运行（没有 model.txt 时）会使用这个模型。
# 注意：必须填【完整的模型全称】，包括服务商要求的前缀、后缀、版本号等。
#   例如："[反重力-0.025]gemini-3.7-flash"
#   而不是："gemini-3.7-flash"
# 全称写错会直接 404 model not found，脚本会弹窗让你换。
$defaultModel = "你的-默认模型-全称"

# ---------- 【修改这里 4】人设 / Prompt ----------
# 在下面 @' ... '@ 之间写你想要的 system prompt。
#
# ⚠️ 注意事项：
#   1. 一定要明确要求"只输出一句话，不要解释、不要署名、不要加引号"，
#      否则模型很容易返回"好的，这是今天的话：……"这种前缀，
#      直接显示在雨滴上会很难看。
#   2. 如果要限制字数，记得写清楚（比如"40字以内"），
#      并在雨滴的皮肤里把文本区域高度调够，避免溢出。
#   3. 不要在这里粘贴你的私人信息（真实姓名、住址等），
#      这个文件是会公开的。
#   4. 提示词里出现 @' 或 '@ 会截断字符串，需要的话请换成别的引号写法。
$systemPrompt = @'
在这里写你的人设和任务描述。

示例要求（可按需保留或删除）：
1. 每次只回复一句极短的句子，字数严格控制在40字以内。
2. 不要解释，不要署名，不要加引号，直接输出你要说的话。
'@

# ---------- 【修改这里 5】输出文件（一般不用动） ----------
# 输出的每日一语写入 quote.txt，雨滴皮肤去读这个文件即可。
$file      = Join-Path $PSScriptRoot "quote.txt"
# 上次选择的模型会存在这里，下次启动优先读取；删掉即恢复默认模型。
$modelFile = Join-Path $PSScriptRoot "model.txt"

# ---------- 以下一般无需修改 ----------
$utf8 = New-Object System.Text.UTF8Encoding($false)

# 模型不可用时是否弹窗让用户选择新模型。
# 如果你把这个脚本挂在后台定时执行，不想被打断，可以改成 $false，
# 那样失败时只把错误信息写进 quote.txt，不弹窗。
$allowPrompt = $true

# ---------- 读取上次保存的模型 ----------
$currentModel = $defaultModel
if (Test-Path $modelFile) {
    $saved = ([System.IO.File]::ReadAllText($modelFile, [System.Text.Encoding]::UTF8)).Trim()
    if (-not [string]::IsNullOrWhiteSpace($saved)) { $currentModel = $saved }
}

$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type"  = "application/json"
}

# ---------- 拉取模型列表 ----------
function Get-ModelList {
    param([string]$ChatUrl, [hashtable]$Headers)
    $modelsUrl = $ChatUrl -replace '/chat/completions', '/models'
    try {
        $r = Invoke-RestMethod -Uri $modelsUrl -Method Get -Headers $Headers -TimeoutSec 30
        $ids = @()
        if ($r.data) {
            $ids = @($r.data | ForEach-Object { $_.id } | Where-Object { $_ })
        } elseif ($r.models) {
            $ids = @($r.models | ForEach-Object { $_.id } | Where-Object { $_ })
        }
        return $ids
    } catch {
        return @()
    }
}

# ---------- 提取错误详情 ----------
function Get-ErrorDetail {
    param($ErrorRecord)
    $msg = $ErrorRecord.Exception.Message
    try {
        $resp = $ErrorRecord.Exception.Response
        if ($resp) {
            $stream = $resp.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $body   = $reader.ReadToEnd()
                $reader.Close()
                if ($body) {
                    try {
                        $j = $body | ConvertFrom-Json
                        if ($j.error.message) { $msg = "$msg | $($j.error.message)" }
                        else                   { $msg = "$msg | $body" }
                    } catch {
                        $msg = "$msg | $body"
                    }
                }
            }
        }
    } catch { }
    if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) + "..." }
    return $msg
}

# ---------- 弹窗选择模型 ----------
function Show-ModelPicker {
    param(
        [string[]]$Models,
        [string]$Current,
        [string]$ErrorText
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $form = New-Object System.Windows.Forms.Form
        $form.Text            = "模型不可用 - 请选择"
        $form.ClientSize      = New-Object System.Drawing.Size(430, 200)
        $form.StartPosition   = "CenterScreen"
        $form.TopMost         = $true
        $form.FormBorderStyle = "FixedDialog"
        $form.MaximizeBox     = $false
        $form.MinimizeBox     = $false

        $lblErr = New-Object System.Windows.Forms.Label
        $lblErr.Location = New-Object System.Drawing.Point(12, 10)
        $lblErr.Size     = New-Object System.Drawing.Size(406, 50)
        $lblErr.Text     = "当前模型 [$Current] 不可用。`r`n$ErrorText"
        $form.Controls.Add($lblErr)

        $lblPick = New-Object System.Windows.Forms.Label
        $lblPick.Location = New-Object System.Drawing.Point(12, 66)
        $lblPick.Size     = New-Object System.Drawing.Size(260, 20)
        $lblPick.Text     = "选择可用模型（也可以手动输入）："
        $form.Controls.Add($lblPick)

        $combo = New-Object System.Windows.Forms.ComboBox
        $combo.Location      = New-Object System.Drawing.Point(12, 90)
        $combo.Size          = New-Object System.Drawing.Size(406, 25)
        $combo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
        if ($Models -and $Models.Count -gt 0) {
            [void]$combo.Items.AddRange($Models)
            $idx = [Array]::IndexOf($Models, $Current)
            if ($idx -ge 0) { $combo.SelectedIndex = $idx } else { $combo.SelectedIndex = 0 }
        } else {
            $combo.Text = $Current
        }
        $form.Controls.Add($combo)

        $ok = New-Object System.Windows.Forms.Button
        $ok.Text         = "使用此模型"
        $ok.Location     = New-Object System.Drawing.Point(235, 135)
        $ok.Size         = New-Object System.Drawing.Size(90, 32)
        $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Controls.Add($ok)

        $cancel = New-Object System.Windows.Forms.Button
        $cancel.Text         = "取消"
        $cancel.Location     = New-Object System.Drawing.Point(331, 135)
        $cancel.Size         = New-Object System.Drawing.Size(90, 32)
        $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Controls.Add($cancel)

        $form.AcceptButton = $ok
        $form.CancelButton = $cancel

        $result   = $form.ShowDialog()
        $selected = $combo.Text.Trim()
        $form.Dispose()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $selected) {
            return $selected
        }
        return $null
    } catch {
        return $null
    }
}

# ---------- 发请求 ----------
function Invoke-Chat {
    param([string]$Model)
    $payload = @{
        model = $Model
        messages = @(
            @{ role = "system"; content = $systemPrompt }
            @{ role = "user";   content = "给我留一句今天的话" }
        )
    }
    $body      = $payload | ConvertTo-Json -Depth 10 -Compress
    $bodyBytes = $utf8.GetBytes($body)
    return Invoke-RestMethod `
        -Uri $url `
        -Method Post `
        -Headers $headers `
        -Body $bodyBytes `
        -TimeoutSec 60
}

# ================== 主流程 ==================
try {
    $response = $null
    $lastErr  = $null

    try {
        $response = Invoke-Chat -Model $currentModel
    } catch {
        $lastErr = $_
    }

    # 失败（异常或结构不对）→ 弹窗换模型
    if (-not $response -or -not $response.choices) {

        $errDetail = if ($lastErr) { Get-ErrorDetail $lastErr } else { "API 返回内容为空" }

        if (-not $allowPrompt) {
            throw "模型不可用：$errDetail"
        }

        $models = @(Get-ModelList -ChatUrl $url -Headers $headers)
        $chosen = Show-ModelPicker -Models $models -Current $currentModel -ErrorText $errDetail

        if (-not $chosen) {
            throw "模型不可用且用户未选择新模型：$errDetail"
        }

        $currentModel = $chosen
        [System.IO.File]::WriteAllText($modelFile, $currentModel, $utf8)

        $response = Invoke-Chat -Model $currentModel
    }

    $text = $response.choices[0].message.content.Trim()
    $text = [System.Text.Encoding]::UTF8.GetString(
        [System.Text.Encoding]::GetEncoding(28591).GetBytes($text)
    )

    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "API 返回内容为空"
    }

    [System.IO.File]::WriteAllText($file, $text, $utf8)
}
catch {
    [System.IO.File]::WriteAllText(
        $file,
        "请求失败：" + $_.Exception.Message,
        $utf8
    )
}