param(
    [string]$BaseUrl = "http://vethuellitas-earevalo.runasp.net",
    [string]$Salida = (Join-Path $PSScriptRoot "..\..\docs\capturas")
)

# Genera evidencia PNG a partir de respuestas reales de la API publicada.
# Cada imagen incluye método, URL, código HTTP y una muestra del cuerpo recibido.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

New-Item -ItemType Directory -Force -Path $Salida | Out-Null
$cliente = [System.Net.Http.HttpClient]::new()
$cliente.BaseAddress = [Uri]$BaseUrl.TrimEnd('/')
$cliente.Timeout = [TimeSpan]::FromSeconds(90)

function Convertir-Texto-Visible([string]$Texto, [int]$Ancho = 104) {
    if ([string]::IsNullOrWhiteSpace($Texto)) { return @("(sin cuerpo de respuesta)") }
    $resultado = [System.Collections.Generic.List[string]]::new()
    foreach ($linea in ($Texto -replace "\r", "" -split "\n")) {
        if ($linea.Length -eq 0) { $resultado.Add(""); continue }
        for ($i = 0; $i -lt $linea.Length; $i += $Ancho) {
            $resultado.Add($linea.Substring($i, [Math]::Min($Ancho, $linea.Length - $i)))
        }
    }
    return $resultado
}

function Guardar-Captura {
    param([int]$Numero, [string]$Nombre, [string]$Metodo, [string]$Ruta, [int]$Esperado, [int]$Obtenido, [string]$Solicitud, [string]$Respuesta)

    $estado = if ($Esperado -eq $Obtenido) { "CORRECTO" } else { "REVISAR" }
    $lineas = [System.Collections.Generic.List[string]]::new()
    $lineas.Add("VetHuellitas API | Evidencia de prueba publicada")
    $lineas.Add(("Caso {0:D2}: {1}" -f $Numero, $Nombre))
    $lineas.Add("")
    $lineas.Add("Solicitud")
    $lineas.Add(("{0} {1}" -f $Metodo, $Ruta))
    if ($Solicitud) { foreach ($lineaSolicitud in @(Convertir-Texto-Visible $Solicitud)) { $lineas.Add($lineaSolicitud) } }
    $lineas.Add("")
    $lineas.Add(("Resultado: HTTP {0} | esperado {1} | {2}" -f $Obtenido, $Esperado, $estado))
    $lineas.Add("Respuesta")
    $muestra = if ($Respuesta.Length -gt 2600) { $Respuesta.Substring(0, 2600) + "`n... (respuesta truncada para la evidencia)" } else { $Respuesta }
    foreach ($lineaRespuesta in @(Convertir-Texto-Visible $muestra)) { $lineas.Add($lineaRespuesta) }
    $lineas.Add("")
    $lineas.Add("URL base: $BaseUrl | Fecha: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")

    $alto = [Math]::Max(520, 54 + ($lineas.Count * 22))
    $bitmap = [System.Drawing.Bitmap]::new(1400, $alto)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.Clear([System.Drawing.Color]::White)
    $titulo = [System.Drawing.Font]::new("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $normal = [System.Drawing.Font]::new("Consolas", 11)
    $negrita = [System.Drawing.Font]::new("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $azul = [System.Drawing.Brushes]::MidnightBlue
    $negro = [System.Drawing.Brushes]::Black
    $verde = [System.Drawing.Brushes]::ForestGreen
    $rojo = [System.Drawing.Brushes]::Firebrick
    $y = 20
    for ($i = 0; $i -lt $lineas.Count; $i++) {
        $texto = $lineas[$i]
        $fuente = if ($i -eq 0) { $titulo } elseif ($texto -in @('Solicitud', 'Respuesta')) { $negrita } else { $normal }
        $brocha = if ($i -eq 0) { $azul } elseif ($texto -like 'Resultado:*') { if ($estado -eq 'CORRECTO') { $verde } else { $rojo } } else { $negro }
        $g.DrawString($texto, $fuente, $brocha, 24, $y)
        $y += if ($i -eq 0) { 34 } else { 22 }
    }
    $archivo = Join-Path $Salida ("{0:D2}-{1}.png" -f $Numero, $Nombre.ToLower().Replace(' ', '-'))
    $bitmap.Save($archivo, [System.Drawing.Imaging.ImageFormat]::Png)
    $titulo.Dispose(); $normal.Dispose(); $negrita.Dispose(); $g.Dispose(); $bitmap.Dispose()
    Write-Host ("[{0:D2}] HTTP {1} -> {2}" -f $Numero, $Obtenido, (Split-Path $archivo -Leaf))
}

function Invocar-Caso {
    param([int]$Numero, [string]$Nombre, [string]$Metodo, [string]$Ruta, [int]$Esperado, $Cuerpo = $null, [hashtable]$Encabezados = @{})
    $metodoHttp = [System.Net.Http.HttpMethod]::$Metodo
    $peticion = [System.Net.Http.HttpRequestMessage]::new($metodoHttp, $Ruta)
    $json = ""
    if ($null -ne $Cuerpo) {
        $json = $Cuerpo | ConvertTo-Json -Depth 6
        $peticion.Content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
    }
    foreach ($clave in $Encabezados.Keys) { [void]$peticion.Headers.TryAddWithoutValidation($clave, $Encabezados[$clave]) }
    $respuesta = $cliente.SendAsync($peticion).GetAwaiter().GetResult()
    $texto = $respuesta.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if ($Encabezados.ContainsKey('Origin')) {
        $origenDevuelto = '(ausente)'
        if ($respuesta.Headers.Contains('Access-Control-Allow-Origin')) {
            $origenDevuelto = $respuesta.Headers.GetValues('Access-Control-Allow-Origin') -join ','
        }
        $texto += "`naccess-control-allow-origin: " + $origenDevuelto
    }
    Guardar-Captura $Numero $Nombre $Metodo $Ruta $Esperado ([int]$respuesta.StatusCode) $json $texto
    $peticion.Dispose(); $respuesta.Dispose()
    return $texto
}

try {
    $marca = (Get-Date).ToString('HHmmss')
    $email = "evidencia.$marca@correo.com"

    Invocar-Caso 1 'health-200' 'GET' '/health' 200 | Out-Null
    Invocar-Caso 2 'get-duenios-200' 'GET' '/api/duenios?ciudad=Lima&activo=true' 200 | Out-Null
    Invocar-Caso 3 'get-duenio-200' 'GET' '/api/duenios/1' 200 | Out-Null
    Invocar-Caso 4 'get-duenio-mascotas-200' 'GET' '/api/duenios/1/mascotas?especie=Gato' 200 | Out-Null
    Invocar-Caso 5 'get-duenio-resumen-200' 'GET' '/api/duenios/1/resumen' 200 | Out-Null
    Invocar-Caso 6 'get-mascotas-200' 'GET' '/api/mascotas?especie=Perro&pesoMin=10&pesoMax=40' 200 | Out-Null
    Invocar-Caso 7 'get-mascota-200' 'GET' '/api/mascotas/1' 200 | Out-Null
    Invocar-Caso 8 'get-estadisticas-200' 'GET' '/api/mascotas/estadisticas' 200 | Out-Null

    $duenio = @{ nombre='Evidencia'; apellido='Swagger'; email=$email; telefono='999888777'; ciudad='Lima'; activo=$true }
    $creado = Invocar-Caso 9 'post-duenio-201' 'POST' '/api/duenios' 201 $duenio
    $duenioId = ($creado | ConvertFrom-Json).duenioId
    Invocar-Caso 10 'post-duenio-400' 'POST' '/api/duenios' 400 @{nombre='X'; apellido='Y'; email='invalido'; telefono='abc'; ciudad=''} | Out-Null
    Invocar-Caso 11 'post-duenio-409' 'POST' '/api/duenios' 409 $duenio | Out-Null
    Invocar-Caso 12 'put-duenio-400' 'PUT' "/api/duenios/$duenioId" 400 @{duenioId=($duenioId+1); nombre='Evidencia'; apellido='Swagger'; email=$email; telefono='999888777'; ciudad='Lima'; activo=$true} | Out-Null
    $duenioActualizado = @{duenioId=$duenioId; nombre='Evidencia'; apellido='Actualizada'; email=$email; telefono='999888777'; ciudad='Callao'; activo=$true}
    Invocar-Caso 13 'put-duenio-204' 'PUT' "/api/duenios/$duenioId" 204 $duenioActualizado | Out-Null

    $mascota = @{duenioId=$duenioId; nombre='Kira'; especie='Perro'; raza='Mestiza'; fechaNacimiento='2023-04-15'; peso=9.4; activa=$true}
    $mascotaCreada = Invocar-Caso 14 'post-mascota-201' 'POST' '/api/mascotas' 201 $mascota
    $mascotaId = ($mascotaCreada | ConvertFrom-Json).mascotaId
    Invocar-Caso 15 'post-mascota-fk-400' 'POST' '/api/mascotas' 400 @{duenioId=999999; nombre='Fantasma'; especie='Perro'; peso=5.0} | Out-Null
    Invocar-Caso 16 'post-mascota-409' 'POST' '/api/mascotas' 409 @{duenioId=$duenioId; nombre='Kira'; especie='Gato'; peso=4.0} | Out-Null
    Invocar-Caso 17 'put-mascota-400' 'PUT' "/api/mascotas/$mascotaId" 400 @{mascotaId=($mascotaId+1); duenioId=$duenioId; nombre='Kira'; especie='Perro'; peso=10.5} | Out-Null
    $mascotaActualizada = @{mascotaId=$mascotaId; duenioId=$duenioId; nombre='Kira'; especie='Perro'; raza='Mestiza'; fechaNacimiento='2023-04-15'; peso=10.5; activa=$true}
    Invocar-Caso 18 'put-mascota-204' 'PUT' "/api/mascotas/$mascotaId" 204 $mascotaActualizada | Out-Null
    Invocar-Caso 19 'delete-duenio-409' 'DELETE' "/api/duenios/$duenioId" 409 | Out-Null
    Invocar-Caso 20 'delete-mascota-204' 'DELETE' "/api/mascotas/$mascotaId" 204 | Out-Null
    Invocar-Caso 21 'delete-mascota-404' 'DELETE' "/api/mascotas/$mascotaId" 404 | Out-Null
    Invocar-Caso 22 'delete-duenio-204' 'DELETE' "/api/duenios/$duenioId" 204 | Out-Null
    Invocar-Caso 23 'delete-duenio-404' 'DELETE' "/api/duenios/$duenioId" 404 | Out-Null
    Invocar-Caso 24 'get-duenio-404' 'GET' '/api/duenios/999999' 404 | Out-Null
    Invocar-Caso 25 'get-mascota-404' 'GET' '/api/mascotas/999999' 404 | Out-Null
    Invocar-Caso 26 'swagger-200' 'GET' '/swagger/index.html' 200 | Out-Null
    Invocar-Caso 27 'openapi-200' 'GET' '/openapi/v1.json' 200 | Out-Null
    Invocar-Caso 28 'cors-200' 'GET' '/api/mascotas' 200 $null @{Origin='http://localhost:5173'} | Out-Null
}
finally {
    $cliente.Dispose()
}
