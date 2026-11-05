# VetHuellitas - Web API REST de clínica veterinaria

Trabajo de la semana 12 del curso Desarrollo de Aplicaciones Empresariales Avanzadas.
Es una Web API REST hecha con ASP.NET Core (.NET 10), controladores, Entity Framework Core
y SQL Server, generada con la modalidad base de datos primero (script SQL + Scaffold).

La API administra dueños y sus mascotas. Sirve para que una veterinaria registre a sus
clientes sin duplicar correos, controle que cada mascota pertenezca a un dueño real y
evite borrar dueños que todavía tienen mascotas atendidas.

## Estructura

```
Lab12/
├─ GLAB-S12-EAREVALO-2026-2.md      enunciado
├─ VetHuellitas.sln
├─ README.md
├─ ENTREGABLES.md                   informe para la entrega
├─ CONCL.md / OBSERV.md / QST.md    conclusiones, observaciones y preguntas
└─ VetHuellitas/
   ├─ Controllers/                  DueniosController, MascotasController
   ├─ Data/VetHuellitasContext.cs   DbContext generado con Scaffold
   ├─ Models/                       Duenio, Mascota (con Data Annotations)
   ├─ database/
   │  ├─ VetHuellitas.sql           crea la base local y carga datos de ejemplo
   │  └─ VetHuellitas_Azure.sql     mismo esquema para una base ya creada en la nube
   ├─ pruebas/
   │  ├─ probar-api.ps1             27 pruebas de humo con los códigos 200/201/204/400/404/409
   │  └─ VetHuellitas.http          colección de peticiones para VS Code / Visual Studio
   ├─ Dockerfile                    imagen lista para hosting con contenedores
   └─ Program.cs                    DI, CORS, Swagger UI, OpenAPI
```

## Requisitos

- .NET SDK 10
- SQL Server (LocalDB, Express o una instancia en la nube)
- dotnet-ef instalado: `dotnet tool install --global dotnet-ef`

## Puesta en marcha local

1. Crear la base y cargar datos de ejemplo:

   ```powershell
   sqlcmd -S "(localdb)\MSSQLLocalDB" -E -i .\database\VetHuellitas.sql -b
   ```

2. Guardar la cadena de conexión en user secrets, nunca en appsettings:

   ```powershell
   cd VetHuellitas
   dotnet user-secrets init
   dotnet user-secrets set "ConnectionStrings:VetHuellitasDb" "<tu cadena de conexion local>"
   ```

   Con LocalDB la cadena usa autenticacion de Windows (`Trusted_Connection=True`), por
   eso no lleva usuario ni contrasena y no se versiona de todos modos.

3. Ejecutar:

   ```powershell
   dotnet run --launch-profile http
   ```

   Swagger queda en http://localhost:5183/swagger y el diagnóstico en /health.

## Modelo generado con Scaffold

```powershell
dotnet ef dbcontext scaffold "<tu cadena de conexion local>" Microsoft.EntityFrameworkCore.SqlServer -o Models -c VetHuellitasContext --context-dir Data --no-onconfiguring -d -f
```

Después del Scaffold se agregaron las validaciones (`[Required]`, `[StringLength]`,
`[Range]`, `[EmailAddress]`), el `[JsonIgnore]` en la colección de mascotas y se dejó
la navegación `Duenio?` como opcional para que el POST de mascotas solo envíe `duenioId`.

## Endpoints

| Método | Ruta | Códigos esperados |
|---|---|---|
| GET | /api/duenios?nombre=&ciudad=&activo=&incluirMascotas= | 200 |
| GET | /api/duenios/{id} | 200, 404 |
| GET | /api/duenios/{id}/mascotas?especie=&activa= | 200, 404 |
| GET | /api/duenios/{id}/resumen | 200, 404 |
| POST | /api/duenios | 201, 400, 409 |
| PUT | /api/duenios/{id} | 204, 400, 404, 409 |
| DELETE | /api/duenios/{id} | 204, 404, 409 |
| GET | /api/mascotas?especie=&duenioId=&nombre=&pesoMin=&pesoMax=&activa= | 200 |
| GET | /api/mascotas/{id} | 200, 404 |
| GET | /api/mascotas/estadisticas | 200 |
| POST | /api/mascotas | 201, 400, 409 |
| PUT | /api/mascotas/{id} | 204, 400, 404, 409 |
| DELETE | /api/mascotas/{id} | 204, 404 |

## Pruebas

```powershell
powershell -ExecutionPolicy Bypass -File .\pruebas\probar-api.ps1 -BaseUrl "https://tu-api-en-la-nube"
```

El script imprime el código obtenido y el esperado de cada petición, y termina con el
conteo de fallas. Sirve igual contra localhost y contra la API publicada.

## Configuración en la nube

La cadena de conexión se pasa como variable de entorno, no se sube al repositorio:

```
ConnectionStrings__VetHuellitasDb = Server=...;Database=...;User Id=...;Password=...;Encrypt=True;TrustServerCertificate=False;
```

Los orígenes permitidos por CORS también se pueden ajustar sin recompilar:

```
Cors__AllowedOrigins__0 = https://tu-frontend.ejemplo.com
```

En `ENTREGABLES.md` están las alternativas gratuitas evaluadas y el paso a paso del
despliegue.
