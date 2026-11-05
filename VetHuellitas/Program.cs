using Microsoft.EntityFrameworkCore;
using VetHuellitas.Data;

var builder = WebApplication.CreateBuilder(args);

// Controladores + documento OpenAPI (Swagger UI se monta más abajo).
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// La cadena de conexión nunca vive en el repositorio:
// local -> user secrets; nube -> variable de entorno ConnectionStrings__VetHuellitasDb.
var connectionString = builder.Configuration.GetConnectionString("VetHuellitasDb");

if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "Falta la cadena de conexión 'VetHuellitasDb'. Configure ConnectionStrings__VetHuellitasDb " +
        "como variable de entorno o use 'dotnet user-secrets set' en desarrollo.");
}

builder.Services.AddDbContext<VetHuellitasContext>(options =>
    options.UseSqlServer(connectionString));

// CORS con orígenes concretos tomados de configuración (nunca AllowAnyOrigin).
var origenesPermitidos = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? ["http://localhost:5173"];

builder.Services.AddCors(options =>
{
    options.AddPolicy("VetHuellitasPolicy", policy =>
    {
        policy.WithOrigins(origenesPermitidos)
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

app.MapOpenApi();

app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/openapi/v1.json", "VetHuellitas API v1");
    options.RoutePrefix = "swagger";
    options.DocumentTitle = "VetHuellitas - Clínica Veterinaria";
});

// En la nube el proveedor ya termina TLS; redirigir aquí puede provocar bucles.
if (app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors("VetHuellitasPolicy");

app.UseAuthorization();

app.MapControllers();

app.MapGet("/", () => Results.Redirect("/swagger"))
    .ExcludeFromDescription();

app.MapGet("/health", async (VetHuellitasContext context) =>
{
    var conecta = await context.Database.CanConnectAsync();
    return conecta
        ? Results.Ok(new { estado = "ok", baseDatos = "conectada", utc = DateTime.UtcNow })
        : Results.Problem("No se pudo conectar a la base de datos.", statusCode: StatusCodes.Status503ServiceUnavailable);
})
.WithTags("Diagnóstico");

app.Run();
