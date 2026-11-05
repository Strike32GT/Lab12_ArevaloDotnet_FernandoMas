param(
    [string]$BaseUrl = "http://localhost:5183"
)

# Pruebas de humo de la API VetHuellitas.
# Uso local:    powershell -ExecutionPolicy Bypass -File .\pruebas\probar-api.ps1
# Uso en nube:  powershell -ExecutionPolicy Bypass -File .\pruebas\probar-api.ps1 -BaseUrl "https://mi-api.ejemplo.com"

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

$client = New-Object System.Net.Http.HttpClient
$client.BaseAddress = [Uri]$BaseUrl.TrimEnd('/')
$client.Timeout = [TimeSpan]::FromSeconds(90)

$resultados = New-Object System.Collections.ArrayList

function Invoke-Api {
    param(
        [string]$Metodo,
        [string]$Ruta,
        $Cuerpo,
        [int]$Esperado,
        [string]$Descripcion
    )

    switch ($Metodo) {
        "GET"    { $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $Ruta) }
        "POST"   { $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $Ruta) }
        "PUT"    { $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Put, $Ruta) }
        "DELETE" { $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Delete, $Ruta) }
        default  { throw "Metodo no soportado: $Metodo" }
    }

    if ($null -ne $Cuerpo) {
        $json = $Cuerpo | ConvertTo-Json -Depth 6 -Compress
        $request.Content = New-Object System.Net.Http.StringContent($json, [System.Text.Encoding]::UTF8, "application/json")
    }

    try {
        $respuesta = $client.SendAsync($request).Result
        $codigo = [int]$respuesta.StatusCode
        $texto = $respuesta.Content.ReadAsStringAsync().Result
    }
    finally {
        if ($null -ne $request) { $request.Dispose() }
    }

    $ok = ($codigo -eq $Esperado)
    $marca = if ($ok) { "OK  " } else { "FALLA" }

    $linea = "{0} esperado {1} | obtenido {2} | {3,-6} {4} | {5}" -f $marca, $Esperado, $codigo, $Metodo, $Ruta, $Descripcion
    Write-Host $linea

    if (-not $ok) {
        Write-Host ("     respuesta: " + $texto)
    }

    [void]$resultados.Add([pscustomobject]@{ Ok = $ok; Codigo = $codigo; Esperado = $Esperado; Metodo = $Metodo; Ruta = $Ruta })

    return [pscustomobject]@{ Codigo = $codigo; Texto = $texto }
}

$sufijo = [DateTime]::Now.ToString("HHmmss")
$emailNuevo = "prueba.$sufijo@correo.com"

Write-Host ""
Write-Host "=== Pruebas contra $BaseUrl ==="
Write-Host ""

# ---------- GET 200 ----------
Invoke-Api -Metodo GET -Ruta "/api/duenios?ciudad=Lima&activo=true" -Esperado 200 -Descripcion "Listado con filtros por query string" | Out-Null
Invoke-Api -Metodo GET -Ruta "/api/duenios/1" -Esperado 200 -Descripcion "Duenio por id con Include de mascotas" | Out-Null
Invoke-Api -Metodo GET -Ruta "/api/duenios/1/mascotas?especie=Gato" -Esperado 200 -Descripcion "Ruta anidada con filtro" | Out-Null
Invoke-Api -Metodo GET -Ruta "/api/duenios/1/resumen" -Esperado 200 -Descripcion "Resumen con agregados LINQ" | Out-Null
Invoke-Api -Metodo GET -Ruta "/api/mascotas?especie=Perro&pesoMin=10&pesoMax=40" -Esperado 200 -Descripcion "Listado de mascotas con filtros" | Out-Null
Invoke-Api -Metodo GET -Ruta "/api/mascotas/1" -Esperado 200 -Descripcion "Mascota por id con su duenio" | Out-Null
Invoke-Api -Metodo GET -Ruta "/api/mascotas/estadisticas" -Esperado 200 -Descripcion "Estadisticas agrupadas por especie" | Out-Null

# ---------- POST 201 ----------
$cuerpoDuenio = @{
    nombre    = "Prueba"
    apellido  = "Automatica"
    email     = $emailNuevo
    telefono  = "999888777"
    ciudad    = "Lima"
    activo    = $true
}
$creado = Invoke-Api -Metodo POST -Ruta "/api/duenios" -Cuerpo $cuerpoDuenio -Esperado 201 -Descripcion "Crear duenio"
$duenioId = ($creado.Texto | ConvertFrom-Json).duenioId

# ---------- POST 400 (validacion automatica) ----------
$cuerpoInvalido = @{
    nombre   = "X"
    apellido = "Y"
    email    = "correo-invalido"
    telefono = "abc"
    ciudad   = ""
}
Invoke-Api -Metodo POST -Ruta "/api/duenios" -Cuerpo $cuerpoInvalido -Esperado 400 -Descripcion "Datos invalidos por Data Annotations" | Out-Null

# ---------- POST 409 (correo repetido) ----------
Invoke-Api -Metodo POST -Ruta "/api/duenios" -Cuerpo $cuerpoDuenio -Esperado 409 -Descripcion "Correo duplicado" | Out-Null

# ---------- PUT 400 (id distinto) ----------
$cuerpoPutMalo = @{
    duenioId = ($duenioId + 500)
    nombre   = "Prueba"
    apellido = "Automatica"
    email    = $emailNuevo
    telefono = "999888777"
    ciudad   = "Lima"
    activo   = $true
}
Invoke-Api -Metodo PUT -Ruta "/api/duenios/$duenioId" -Cuerpo $cuerpoPutMalo -Esperado 400 -Descripcion "Id de ruta distinto del cuerpo" | Out-Null

# ---------- PUT 204 ----------
$cuerpoPut = @{
    duenioId = $duenioId
    nombre   = "Prueba"
    apellido = "Actualizada"
    email    = $emailNuevo
    telefono = "999888777"
    ciudad   = "Callao"
    activo   = $true
}
Invoke-Api -Metodo PUT -Ruta "/api/duenios/$duenioId" -Cuerpo $cuerpoPut -Esperado 204 -Descripcion "Actualizar duenio" | Out-Null

# ---------- Mascota: POST 201, 400, 409 ----------
$cuerpoMascota = @{
    duenioId        = $duenioId
    nombre          = "Kira"
    especie         = "Perro"
    raza            = "Mestiza"
    fechaNacimiento = "2023-04-15"
    peso            = 9.4
    activa          = $true
}
$creada = Invoke-Api -Metodo POST -Ruta "/api/mascotas" -Cuerpo $cuerpoMascota -Esperado 201 -Descripcion "Crear mascota solo con la FK"
$mascotaId = ($creada.Texto | ConvertFrom-Json).mascotaId

$cuerpoMascotaSinDuenio = @{
    duenioId = 999999
    nombre   = "Fantasma"
    especie  = "Perro"
    peso     = 5.0
}
Invoke-Api -Metodo POST -Ruta "/api/mascotas" -Cuerpo $cuerpoMascotaSinDuenio -Esperado 400 -Descripcion "Clave foranea inexistente" | Out-Null

$cuerpoMascotaDuplicada = @{
    duenioId = $duenioId
    nombre   = "Kira"
    especie  = "Gato"
    peso     = 4.0
}
Invoke-Api -Metodo POST -Ruta "/api/mascotas" -Cuerpo $cuerpoMascotaDuplicada -Esperado 409 -Descripcion "Nombre repetido para el mismo duenio" | Out-Null

# ---------- Mascota: PUT 400, PUT 204 ----------
$cuerpoPutMascotaMalo = @{
    mascotaId = ($mascotaId + 500)
    duenioId  = $duenioId
    nombre    = "Kira"
    especie   = "Perro"
    peso      = 10.5
}
Invoke-Api -Metodo PUT -Ruta "/api/mascotas/$mascotaId" -Cuerpo $cuerpoPutMascotaMalo -Esperado 400 -Descripcion "Mascota con id de ruta distinto" | Out-Null

$cuerpoPutMascota = @{
    mascotaId       = $mascotaId
    duenioId        = $duenioId
    nombre          = "Kira"
    especie         = "Perro"
    raza            = "Mestiza"
    fechaNacimiento = "2023-04-15"
    peso            = 10.5
    activa          = $true
}
Invoke-Api -Metodo PUT -Ruta "/api/mascotas/$mascotaId" -Cuerpo $cuerpoPutMascota -Esperado 204 -Descripcion "Actualizar mascota" | Out-Null

# ---------- DELETE 409: duenio con mascotas ----------
Invoke-Api -Metodo DELETE -Ruta "/api/duenios/$duenioId" -Esperado 409 -Descripcion "No se puede borrar duenio con mascotas" | Out-Null

# ---------- DELETE 204 y 404 ----------
Invoke-Api -Metodo DELETE -Ruta "/api/mascotas/$mascotaId" -Esperado 204 -Descripcion "Eliminar mascota" | Out-Null
Invoke-Api -Metodo DELETE -Ruta "/api/mascotas/$mascotaId" -Esperado 404 -Descripcion "Mascota ya eliminada" | Out-Null
Invoke-Api -Metodo DELETE -Ruta "/api/duenios/$duenioId" -Esperado 204 -Descripcion "Eliminar duenio sin mascotas" | Out-Null
Invoke-Api -Metodo DELETE -Ruta "/api/duenios/$duenioId" -Esperado 404 -Descripcion "Duenio ya eliminado" | Out-Null
Invoke-Api -Metodo GET -Ruta "/api/duenios/999999" -Esperado 404 -Descripcion "Duenio inexistente" | Out-Null
Invoke-Api -Metodo GET -Ruta "/api/mascotas/999999" -Esperado 404 -Descripcion "Mascota inexistente" | Out-Null

# ---------- Swagger y OpenAPI ----------
Invoke-Api -Metodo GET -Ruta "/swagger/index.html" -Esperado 200 -Descripcion "Swagger UI publicado" | Out-Null
Invoke-Api -Metodo GET -Ruta "/openapi/v1.json" -Esperado 200 -Descripcion "Documento OpenAPI" | Out-Null

# ---------- CORS ----------
$requestCors = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, "/api/mascotas")
$requestCors.Headers.Add("Origin", "http://localhost:5173")
$respuestaCors = $client.SendAsync($requestCors).Result
$origenDevuelto = ($respuestaCors.Headers.GetValues("Access-Control-Allow-Origin") -join ",")
$corsOk = ($origenDevuelto -eq "http://localhost:5173")
$marca = if ($corsOk) { "OK  " } else { "FALLA" }
Write-Host ("{0} CORS        | origen devuelto: {1}" -f $marca, $origenDevuelto)
[void]$resultados.Add([pscustomobject]@{ Ok = $corsOk; Codigo = "CORS"; Esperado = "origen concreto"; Metodo = "GET"; Ruta = "/api/mascotas" })
$requestCors.Dispose()

# ---------- Resumen ----------
$total = $resultados.Count
$fallas = ($resultados | Where-Object { -not $_.Ok }).Count

Write-Host ""
Write-Host ("Pruebas ejecutadas: {0} | Correctas: {1} | Fallidas: {2}" -f $total, ($total - $fallas), $fallas)

$client.Dispose()

if ($fallas -gt 0) { exit 1 }
