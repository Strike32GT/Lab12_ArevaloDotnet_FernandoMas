# Entrega - Semana 12: Web API REST VetHuellitas

Curso: Desarrollo de Aplicaciones Empresariales Avanzadas
Alumno: Arévalo Sermeño, Edwin William
Sección: 6 - C24 - C - D

## 1. Tema y problema que resuelve

VetHuellitas es una clínica veterinaria pequeña que hasta ahora anotaba a sus clientes en
un cuaderno. El problema es doble: se repiten correos y teléfonos de dueños que ya estaban
registrados, y cuando alguien quiere dar de baja a un dueño se pierde el historial de sus
mascotas porque nadie sabe cuáles le pertenecían. La API resuelve eso con dos entidades
relacionadas: el dueño es el registro principal y cada mascota queda amarrada a un dueño
mediante una clave foránea. Así se puede consultar "las mascotas de Ana" con una sola
petición, se bloquea el registro duplicado de correos y se impide dejar mascotas huérfanas.

Entidades y relación:

- Duenio: DuenioId, Nombre, Apellido, Email (único), Telefono, Ciudad, FechaRegistro, Activo.
- Mascota: MascotaId, DuenioId (FK), Nombre, Especie, Raza, FechaNacimiento, Peso, Activa.
- Relación 1:N. Un dueño tiene muchas mascotas y una mascota pertenece a un solo dueño.
  En la base la FK es `FK_Mascotas_Duenios` con `ON DELETE NO ACTION`.

Reglas de negocio implementadas con respuesta 409:

- El correo de un dueño no se puede repetir. Se valida antes de insertar y además existe el
  índice único `UQ_Duenios_Email` como respaldo en la base.
- No se puede eliminar un dueño que tenga mascotas registradas, para no perder el historial.
- Una mascota no puede repetirse con el mismo nombre dentro del mismo dueño; el índice
  `UQ_Mascotas_Duenio_Nombre` refuerza la regla.

Validaciones que responden 400 automáticamente por `[ApiController]`:

- Campos obligatorios y longitudes con `[Required]` y `[StringLength]`.
- Formato de correo con `[EmailAddress]` y de teléfono con `[RegularExpression]`.
- Peso entre 0.01 y 200 kg con `[Range]`.
- `DuenioId` mayor o igual a 1 con `[Range]`.
- Fecha de nacimiento no futura, validada en `IValidatableObject`.

## 2. Modelo de datos y Scaffold

El script `VetHuellitas/database/VetHuellitas.sql` crea la base, las dos tablas, los
índices, las restricciones y carga cinco dueños con siete mascotas de ejemplo. Para una
base ya creada en la nube se usa `VetHuellitas/database/VetHuellitas_Azure.sql`, que no
incluye `CREATE DATABASE` ni `USE`.

El modelo se generó con Scaffold, no a mano:

```powershell
dotnet ef dbcontext scaffold "<cadena de conexion local>" Microsoft.EntityFrameworkCore.SqlServer -o Models -c VetHuellitasContext --context-dir Data --no-onconfiguring -d -f
```

Luego se ajustaron las anotaciones, se agregó `[JsonIgnore]` a `Duenio.Mascotas` y se dejó
`Mascota.Duenio` como `Duenio?`. Con eso el POST de una mascota solo necesita `duenioId` y
el JSON no entra en ciclo.

## 3. Endpoints y códigos de respuesta

Trece endpoints en total, todos async y con LINQ (`ToListAsync`, `FindAsync`, `AnyAsync`,
`Include`, `AsNoTracking`, `CountAsync`, `GroupBy`).

| # | Método | Ruta | Códigos | Notas |
|---|---|---|---|---|
| 1 | GET | /api/duenios | 200 | Filtros `nombre`, `ciudad`, `activo`, `incluirMascotas` |
| 2 | GET | /api/duenios/{id} | 200, 404 | Incluye mascotas |
| 3 | GET | /api/duenios/{id}/mascotas | 200, 404 | Ruta anidada con filtros `especie`, `activa` |
| 4 | GET | /api/duenios/{id}/resumen | 200, 404 | Conteos y peso promedio |
| 5 | POST | /api/duenios | 201, 400, 409 | `CreatedAtAction` |
| 6 | PUT | /api/duenios/{id} | 204, 400, 404, 409 | `NoContent` |
| 7 | DELETE | /api/duenios/{id} | 204, 404, 409 | Regla de mascotas dependientes |
| 8 | GET | /api/mascotas | 200 | Filtros `especie`, `duenioId`, `nombre`, `pesoMin`, `pesoMax`, `activa` |
| 9 | GET | /api/mascotas/{id} | 200, 404 | Incluye dueño |
| 10 | GET | /api/mascotas/estadisticas | 200 | Agrupación por especie |
| 11 | POST | /api/mascotas | 201, 400, 409 | Valida dueño y nombre repetido |
| 12 | PUT | /api/mascotas/{id} | 204, 400, 404, 409 | `NoContent` |
| 13 | DELETE | /api/mascotas/{id} | 204, 404 | |

Además hay dos rutas de apoyo: `/health` para comprobar la conexión a la base y `/`, que
redirige a Swagger.

Uso de `ActionResult`:

| Resultado | Código | Dónde está |
|---|---|---|
| `Ok(...)` | 200 | Los siete GET |
| `CreatedAtAction(...)` | 201 | POST de dueños y mascotas |
| `NoContent()` | 204 | PUT y DELETE correctos |
| `BadRequest(...)` / `ValidationProblem(...)` | 400 | Id de ruta distinto, FK inexistente, datos inválidos |
| `NotFound(...)` | 404 | Recurso inexistente en GET, PUT y DELETE |
| `Conflict(...)` | 409 | Correo repetido, dueño con mascotas, mascota repetida |

## 4. Swagger y CORS

Swagger UI se publica siempre, no solo en desarrollo, en `/swagger`, y el documento
OpenAPI en `/openapi/v1.json`. CORS usa la política `VetHuellitasPolicy` con orígenes
concretos tomados de `Cors:AllowedOrigins` (por defecto `http://localhost:5173` y
`http://localhost:3000`); no se usa `AllowAnyOrigin`. En la nube se puede cambiar sin
recompilar con la variable `Cors__AllowedOrigins__0`.

## 5. Despliegue en la nube

### Alternativas evaluadas

Hosting para ASP.NET Core con plan gratuito:

- Azure App Service, plan F1. Integración directa con .NET 10, despliegue por Git o por
  Visual Studio y variables de entorno en el portal. La cuota gratuita es limitada en CPU,
  pero sobra para la corrección.
- MonsterASP.NET. Hosting gratuito para ASP.NET Core en Windows, incluye una base SQL
  Server pequeña, así que se mantiene el mismo proveedor de EF Core sin tocar código.
- Render, Koyeb o Fly.io con contenedor. Se usa el `Dockerfile` incluido y la cadena de
  conexión se pasa como variable de entorno. El plan gratuito duerme la aplicación, por eso
  el primer request tarda.
- Somee y otros hostings clásicos con SQL Server, más antiguos pero funcionales.

Base de datos gratuita:

- Azure SQL Database, oferta gratuita. Es SQL Server, así que el script y el proveedor
  actual funcionan tal cual.
- SQL Server incluido en el plan gratuito de MonsterASP.NET o Somee.
- Neon o Supabase con PostgreSQL, y Aiven o TiDB con MySQL. Son buenas opciones, pero
  obligan a cambiar el proveedor de EF Core y a adaptar el script.

### Elección y justificación

La primera opción es MonsterASP.NET, porque entrega hosting y SQL Server en el mismo plan
gratuito y permite mantener `Microsoft.EntityFrameworkCore.SqlServer` y el script tal como
está. La segunda es Azure App Service F1 con Azure SQL Database, porque también es SQL
Server y la configuración de secretos es la más ordenada. Si ninguna de las dos está
disponible, se usa Render con el `Dockerfile` y Neon como base; en ese caso hay que cambiar
a Npgsql, como se explica en las conclusiones.

### Pasos del despliegue

1. Crear la base de datos en el proveedor elegido y ejecutar `VetHuellitas_Azure.sql`
   conectado a esa base (con SSMS, Azure Data Studio o el editor SQL del panel).
2. Publicar la API. Con Visual Studio, clic derecho en el proyecto, Publicar, destino
   Azure o carpeta y luego Web Deploy. Con contenedor, `docker build` y desplegar el
   `Dockerfile`; la aplicación escucha en el puerto que entregue la plataforma.
3. Configurar `ConnectionStrings__VetHuellitasDb` como variable de entorno o secreto del
   proveedor. La cadena no va en `appsettings.json` ni en el repositorio.
4. Configurar `Cors__AllowedOrigins__0` con la URL del frontend si corresponde.
5. Abrir `/swagger` de la API publicada y `/health` para confirmar la conexión.
6. Ejecutar las pruebas contra la URL pública, no contra localhost.

## 6. Pruebas sobre la API publicada

Las pruebas se hacen con Swagger, Postman o con el script incluido:

```powershell
powershell -ExecutionPolicy Bypass -File .\VetHuellitas\pruebas\probar-api.ps1 -BaseUrl "https://URL_DE_LA_API"
```

El script ejecuta 27 comprobaciones y cubre los seis códigos exigidos. La tabla sirve como
lista de capturas; cada fila debe tener su imagen en `docs/capturas/`.

| Código | Petición | Caso | Captura |
|---|---|---|---|
| 200 | GET /api/duenios?ciudad=Lima&activo=true | Filtros por query string | `01-get-200-duenios-filtro.png` |
| 200 | GET /api/duenios/1 | Dueño con mascotas | `02-get-200-duenio.png` |
| 200 | GET /api/duenios/1/mascotas?especie=Gato | Ruta anidada | `03-get-200-anidada.png` |
| 200 | GET /api/duenios/1/resumen | Agregados LINQ | `04-get-200-resumen.png` |
| 200 | GET /api/mascotas?especie=Perro&pesoMin=10 | Filtros de mascotas | `05-get-200-mascotas.png` |
| 200 | GET /api/mascotas/1 | Mascota con su dueño | `06-get-200-mascota.png` |
| 200 | GET /api/mascotas/estadisticas | Agrupación por especie | `07-get-200-estadisticas.png` |
| 201 | POST /api/duenios | Crear dueño | `08-post-201-duenio.png` |
| 201 | POST /api/mascotas | Crear mascota con solo la FK | `09-post-201-mascota.png` |
| 204 | PUT /api/duenios/{id} | Actualizar dueño | `10-put-204-duenio.png` |
| 204 | PUT /api/mascotas/{id} | Actualizar mascota | `11-put-204-mascota.png` |
| 204 | DELETE /api/mascotas/{id} | Eliminar mascota | `12-delete-204-mascota.png` |
| 204 | DELETE /api/duenios/{id} | Eliminar dueño sin mascotas | `13-delete-204-duenio.png` |
| 400 | POST /api/duenios | Datos inválidos por anotaciones | `14-post-400-validacion.png` |
| 400 | POST /api/mascotas | Dueño inexistente | `15-post-400-fk.png` |
| 400 | PUT /api/duenios/{id} | Id de ruta distinto del cuerpo | `16-put-400-id.png` |
| 404 | GET /api/duenios/999999 | Recurso inexistente | `17-get-404.png` |
| 404 | DELETE /api/mascotas/{id} | Recurso ya eliminado | `18-delete-404.png` |
| 409 | POST /api/duenios | Correo repetido | `19-post-409-email.png` |
| 409 | POST /api/mascotas | Nombre repetido para el mismo dueño | `20-post-409-mascota.png` |
| 409 | DELETE /api/duenios/1 | Dueño con mascotas | `21-delete-409-dependientes.png` |
| 200 | GET /swagger/index.html | Swagger publicado | `22-swagger.png` |
| 200 | GET /health | Base de datos conectada | `23-health.png` |
| CORS | GET /api/mascotas con Origin permitido | Origen concreto devuelto | `24-cors.png` |

## 7. Enlaces de la entrega

- Repositorio: PENDIENTE_COMPLETAR (sin cadena de conexión, con el script SQL incluido).
- API publicada (Swagger): PENDIENTE_COMPLETAR/swagger
- Hosting usado: PENDIENTE_COMPLETAR
- Base de datos usada: PENDIENTE_COMPLETAR

## 8. Observaciones y conclusiones

Están desarrolladas en `OBSERV.md` y `CONCL.md`.
