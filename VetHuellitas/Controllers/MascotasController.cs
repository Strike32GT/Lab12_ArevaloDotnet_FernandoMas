using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VetHuellitas.Data;
using VetHuellitas.Models;

namespace VetHuellitas.Controllers;

/// <summary>
/// CRUD de mascotas. La relación con dueño es 1:N y la clave foránea es DuenioId.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class MascotasController : ControllerBase
{
    private readonly VetHuellitasContext _context;

    public MascotasController(VetHuellitasContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Lista mascotas con filtros por especie, dueño, nombre, rango de peso y estado.
    /// </summary>
    /// <remarks>GET api/mascotas?especie=perro&amp;duenioId=1&amp;pesoMin=5&amp;pesoMax=30&amp;activa=true</remarks>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Mascota>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<Mascota>>> GetMascotas(
        [FromQuery] string? especie,
        [FromQuery] int? duenioId,
        [FromQuery] string? nombre,
        [FromQuery] decimal? pesoMin,
        [FromQuery] decimal? pesoMax,
        [FromQuery] bool? activa,
        [FromQuery] bool incluirDuenio = true)
    {
        IQueryable<Mascota> query = _context.Mascotas.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(especie))
        {
            var filtro = especie.Trim();
            query = query.Where(m => m.Especie.Contains(filtro));
        }

        if (duenioId.HasValue)
        {
            query = query.Where(m => m.DuenioId == duenioId.Value);
        }

        if (!string.IsNullOrWhiteSpace(nombre))
        {
            var filtro = nombre.Trim();
            query = query.Where(m => m.Nombre.Contains(filtro));
        }

        if (pesoMin.HasValue)
        {
            query = query.Where(m => m.Peso >= pesoMin.Value);
        }

        if (pesoMax.HasValue)
        {
            query = query.Where(m => m.Peso <= pesoMax.Value);
        }

        if (activa.HasValue)
        {
            query = query.Where(m => m.Activa == activa.Value);
        }

        if (incluirDuenio)
        {
            query = query.Include(m => m.Duenio);
        }

        var mascotas = await query
            .OrderBy(m => m.Especie)
            .ThenBy(m => m.Nombre)
            .ToListAsync();

        return Ok(mascotas);
    }

    /// <summary>
    /// Obtiene una mascota por su id e incluye los datos de su dueño.
    /// </summary>
    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(Mascota), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<Mascota>> GetMascota(int id)
    {
        var mascota = await _context.Mascotas
            .AsNoTracking()
            .Include(m => m.Duenio)
            .FirstOrDefaultAsync(m => m.MascotaId == id);

        if (mascota is null)
        {
            return NotFound(new { mensaje = $"No existe una mascota con id {id}." });
        }

        return Ok(mascota);
    }

    /// <summary>
    /// Estadísticas agrupadas por especie, calculadas con LINQ.
    /// </summary>
    [HttpGet("estadisticas")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult> GetEstadisticas()
    {
        var total = await _context.Mascotas.CountAsync();

        var porEspecie = await _context.Mascotas
            .AsNoTracking()
            .GroupBy(m => m.Especie)
            .Select(g => new
            {
                Especie = g.Key,
                Cantidad = g.Count(),
                Activas = g.Count(m => m.Activa),
                PesoPromedio = g.Average(m => m.Peso)
            })
            .OrderByDescending(x => x.Cantidad)
            .ToListAsync();

        return Ok(new { totalMascotas = total, porEspecie });
    }

    /// <summary>
    /// Registra una mascota. Reglas: el dueño debe existir (400) y no puede repetirse
    /// el mismo nombre para el mismo dueño (409).
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(Mascota), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<Mascota>> PostMascota([FromBody] Mascota mascota)
    {
        if (!await _context.Duenios.AnyAsync(d => d.DuenioId == mascota.DuenioId))
        {
            ModelState.AddModelError(nameof(Mascota.DuenioId), "El dueño indicado no existe.");
            return ValidationProblem(ModelState);
        }

        var nombre = mascota.Nombre.Trim();

        if (await _context.Mascotas.AnyAsync(m =>
                m.DuenioId == mascota.DuenioId &&
                m.Nombre.ToLower() == nombre.ToLower()))
        {
            return Conflict(new
            {
                mensaje = $"Ese dueño ya tiene una mascota llamada {nombre}."
            });
        }

        mascota.MascotaId = 0;
        mascota.Nombre = nombre;
        mascota.Especie = mascota.Especie.Trim();
        mascota.Raza = string.IsNullOrWhiteSpace(mascota.Raza) ? null : mascota.Raza.Trim();
        mascota.Duenio = null;

        _context.Mascotas.Add(mascota);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetMascota), new { id = mascota.MascotaId }, mascota);
    }

    /// <summary>
    /// Actualiza una mascota. El id de la ruta debe coincidir con el del cuerpo (400).
    /// </summary>
    [HttpPut("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> PutMascota(int id, [FromBody] Mascota mascota)
    {
        if (id != mascota.MascotaId)
        {
            return BadRequest(new { mensaje = "El id de la ruta no coincide con el id enviado en el cuerpo." });
        }

        var existente = await _context.Mascotas.FindAsync(id);

        if (existente is null)
        {
            return NotFound(new { mensaje = $"No existe una mascota con id {id}." });
        }

        if (!await _context.Duenios.AnyAsync(d => d.DuenioId == mascota.DuenioId))
        {
            ModelState.AddModelError(nameof(Mascota.DuenioId), "El dueño indicado no existe.");
            return ValidationProblem(ModelState);
        }

        var nombre = mascota.Nombre.Trim();

        if (await _context.Mascotas.AnyAsync(m =>
                m.MascotaId != id &&
                m.DuenioId == mascota.DuenioId &&
                m.Nombre.ToLower() == nombre.ToLower()))
        {
            return Conflict(new
            {
                mensaje = $"Ese dueño ya tiene una mascota llamada {nombre}."
            });
        }

        existente.DuenioId = mascota.DuenioId;
        existente.Nombre = nombre;
        existente.Especie = mascota.Especie.Trim();
        existente.Raza = string.IsNullOrWhiteSpace(mascota.Raza) ? null : mascota.Raza.Trim();
        existente.FechaNacimiento = mascota.FechaNacimiento;
        existente.Peso = mascota.Peso;
        existente.Activa = mascota.Activa;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!await _context.Mascotas.AnyAsync(m => m.MascotaId == id))
            {
                return NotFound(new { mensaje = $"No existe una mascota con id {id}." });
            }

            throw;
        }

        return NoContent();
    }

    /// <summary>
    /// Elimina una mascota por su id.
    /// </summary>
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteMascota(int id)
    {
        var mascota = await _context.Mascotas.FindAsync(id);

        if (mascota is null)
        {
            return NotFound(new { mensaje = $"No existe una mascota con id {id}." });
        }

        _context.Mascotas.Remove(mascota);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
