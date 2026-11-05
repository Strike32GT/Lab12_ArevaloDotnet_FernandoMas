using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using VetHuellitas.Data;
using VetHuellitas.Models;

namespace VetHuellitas.Controllers;

/// <summary>
/// CRUD de dueños de mascotas. Toda la consulta se resuelve con LINQ sobre el DbContext.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class DueniosController : ControllerBase
{
    private readonly VetHuellitasContext _context;

    public DueniosController(VetHuellitasContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Lista dueños con filtros opcionales por nombre, ciudad, estado y datos de mascotas.
    /// </summary>
    /// <remarks>GET api/duenios?nombre=ana&amp;ciudad=Lima&amp;activo=true&amp;incluirMascotas=true</remarks>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Duenio>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<Duenio>>> GetDuenios(
        [FromQuery] string? nombre,
        [FromQuery] string? ciudad,
        [FromQuery] bool? activo,
        [FromQuery] bool incluirMascotas = false)
    {
        IQueryable<Duenio> query = _context.Duenios.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(nombre))
        {
            var filtro = nombre.Trim();
            query = query.Where(d => (d.Nombre + " " + d.Apellido).Contains(filtro));
        }

        if (!string.IsNullOrWhiteSpace(ciudad))
        {
            var filtro = ciudad.Trim();
            query = query.Where(d => d.Ciudad.Contains(filtro));
        }

        if (activo.HasValue)
        {
            query = query.Where(d => d.Activo == activo.Value);
        }

        if (incluirMascotas)
        {
            query = query.Include(d => d.Mascotas);
        }

        var duenios = await query
            .OrderBy(d => d.Apellido)
            .ThenBy(d => d.Nombre)
            .ToListAsync();

        return Ok(duenios);
    }

    /// <summary>
    /// Obtiene un dueño por su id, junto con sus mascotas.
    /// </summary>
    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(Duenio), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<Duenio>> GetDuenio(int id)
    {
        var duenio = await _context.Duenios
            .AsNoTracking()
            .Include(d => d.Mascotas)
            .FirstOrDefaultAsync(d => d.DuenioId == id);

        if (duenio is null)
        {
            return NotFound(new { mensaje = $"No existe un dueño con id {id}." });
        }

        return Ok(duenio);
    }

    /// <summary>
    /// Ruta anidada: mascotas de un dueño, con filtro por especie y estado.
    /// </summary>
    /// <remarks>GET api/duenios/1/mascotas?especie=perro&amp;activa=true</remarks>
    [HttpGet("{id:int}/mascotas")]
    [ProducesResponseType(typeof(IEnumerable<Mascota>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<IEnumerable<Mascota>>> GetMascotasDeDuenio(
        int id,
        [FromQuery] string? especie,
        [FromQuery] bool? activa)
    {
        if (!await _context.Duenios.AnyAsync(d => d.DuenioId == id))
        {
            return NotFound(new { mensaje = $"No existe un dueño con id {id}." });
        }

        IQueryable<Mascota> query = _context.Mascotas
            .AsNoTracking()
            .Where(m => m.DuenioId == id);

        if (!string.IsNullOrWhiteSpace(especie))
        {
            var filtro = especie.Trim();
            query = query.Where(m => m.Especie.Contains(filtro));
        }

        if (activa.HasValue)
        {
            query = query.Where(m => m.Activa == activa.Value);
        }

        var mascotas = await query
            .OrderBy(m => m.Nombre)
            .ToListAsync();

        return Ok(mascotas);
    }

    /// <summary>
    /// Resumen calculado con LINQ: total de mascotas, activas y peso promedio.
    /// </summary>
    [HttpGet("{id:int}/resumen")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> GetResumen(int id)
    {
        var resumen = await _context.Duenios
            .AsNoTracking()
            .Where(d => d.DuenioId == id)
            .Select(d => new
            {
                d.DuenioId,
                NombreCompleto = d.Nombre + " " + d.Apellido,
                d.Email,
                d.Ciudad,
                d.Activo,
                TotalMascotas = d.Mascotas.Count(),
                MascotasActivas = d.Mascotas.Count(m => m.Activa),
                PesoPromedio = d.Mascotas.Any() ? d.Mascotas.Average(m => m.Peso) : 0m
            })
            .FirstOrDefaultAsync();

        if (resumen is null)
        {
            return NotFound(new { mensaje = $"No existe un dueño con id {id}." });
        }

        return Ok(resumen);
    }

    /// <summary>
    /// Registra un dueño. Regla de negocio: el correo no puede repetirse (409).
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(Duenio), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<Duenio>> PostDuenio([FromBody] Duenio duenio)
    {
        var email = duenio.Email.Trim().ToLowerInvariant();

        if (await _context.Duenios.AnyAsync(d => d.Email.ToLower() == email))
        {
            return Conflict(new { mensaje = $"Ya existe un dueño registrado con el correo {email}." });
        }

        duenio.DuenioId = 0;
        duenio.Nombre = duenio.Nombre.Trim();
        duenio.Apellido = duenio.Apellido.Trim();
        duenio.Email = email;
        duenio.Telefono = duenio.Telefono.Trim();
        duenio.Ciudad = duenio.Ciudad.Trim();
        duenio.FechaRegistro = DateTime.Now;
        duenio.Mascotas.Clear();

        _context.Duenios.Add(duenio);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetDuenio), new { id = duenio.DuenioId }, duenio);
    }

    /// <summary>
    /// Actualiza un dueño. El id de la ruta debe coincidir con el del cuerpo (400).
    /// </summary>
    [HttpPut("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> PutDuenio(int id, [FromBody] Duenio duenio)
    {
        if (id != duenio.DuenioId)
        {
            return BadRequest(new { mensaje = "El id de la ruta no coincide con el id enviado en el cuerpo." });
        }

        var existente = await _context.Duenios.FindAsync(id);

        if (existente is null)
        {
            return NotFound(new { mensaje = $"No existe un dueño con id {id}." });
        }

        var email = duenio.Email.Trim().ToLowerInvariant();

        if (await _context.Duenios.AnyAsync(d => d.DuenioId != id && d.Email.ToLower() == email))
        {
            return Conflict(new { mensaje = $"Otro dueño ya usa el correo {email}." });
        }

        existente.Nombre = duenio.Nombre.Trim();
        existente.Apellido = duenio.Apellido.Trim();
        existente.Email = email;
        existente.Telefono = duenio.Telefono.Trim();
        existente.Ciudad = duenio.Ciudad.Trim();
        existente.Activo = duenio.Activo;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!await _context.Duenios.AnyAsync(d => d.DuenioId == id))
            {
                return NotFound(new { mensaje = $"No existe un dueño con id {id}." });
            }

            throw;
        }

        return NoContent();
    }

    /// <summary>
    /// Elimina un dueño. Regla de negocio: no se puede si tiene mascotas (409).
    /// </summary>
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> DeleteDuenio(int id)
    {
        var duenio = await _context.Duenios.FindAsync(id);

        if (duenio is null)
        {
            return NotFound(new { mensaje = $"No existe un dueño con id {id}." });
        }

        if (await _context.Mascotas.AnyAsync(m => m.DuenioId == id))
        {
            return Conflict(new
            {
                mensaje = "No se puede eliminar al dueño porque tiene mascotas registradas. Elimine o reasigne sus mascotas primero."
            });
        }

        _context.Duenios.Remove(duenio);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
