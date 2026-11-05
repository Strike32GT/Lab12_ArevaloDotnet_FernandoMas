using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;

namespace VetHuellitas.Models;

[Index("DuenioId", Name = "IX_Mascotas_DuenioId")]
[Index("DuenioId", "Nombre", Name = "UQ_Mascotas_Duenio_Nombre", IsUnique = true)]
public partial class Mascota : IValidatableObject
{
    [Key]
    public int MascotaId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Debe indicar el dueño de la mascota.")]
    public int DuenioId { get; set; }

    [Required(ErrorMessage = "El nombre de la mascota es obligatorio.")]
    [StringLength(60, MinimumLength = 2, ErrorMessage = "El nombre debe tener entre 2 y 60 caracteres.")]
    public string Nombre { get; set; } = null!;

    [Required(ErrorMessage = "La especie es obligatoria.")]
    [StringLength(40, MinimumLength = 3, ErrorMessage = "La especie debe tener entre 3 y 40 caracteres.")]
    public string Especie { get; set; } = null!;

    [StringLength(60, ErrorMessage = "La raza no puede superar los 60 caracteres.")]
    public string? Raza { get; set; }

    public DateOnly? FechaNacimiento { get; set; }

    [Range(typeof(decimal), "0.01", "200.00", ErrorMessage = "El peso debe estar entre 0.01 y 200.00 kg.")]
    [Column(TypeName = "decimal(5, 2)")]
    public decimal Peso { get; set; }

    public bool Activa { get; set; }

    // Navegación opcional: el POST solo necesita enviar DuenioId.
    [ForeignKey("DuenioId")]
    [InverseProperty("Mascotas")]
    public virtual Duenio? Duenio { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (FechaNacimiento.HasValue && FechaNacimiento.Value > DateOnly.FromDateTime(DateTime.Today))
        {
            yield return new ValidationResult(
                "La fecha de nacimiento no puede ser futura.",
                new[] { nameof(FechaNacimiento) });
        }
    }
}
