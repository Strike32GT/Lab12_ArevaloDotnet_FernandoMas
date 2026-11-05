using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;

namespace VetHuellitas.Models;

[Index("Email", Name = "UQ_Duenios_Email", IsUnique = true)]
public partial class Duenio
{
    [Key]
    public int DuenioId { get; set; }

    [Required(ErrorMessage = "El nombre del dueño es obligatorio.")]
    [StringLength(80, MinimumLength = 2, ErrorMessage = "El nombre debe tener entre 2 y 80 caracteres.")]
    public string Nombre { get; set; } = null!;

    [Required(ErrorMessage = "El apellido del dueño es obligatorio.")]
    [StringLength(80, MinimumLength = 2, ErrorMessage = "El apellido debe tener entre 2 y 80 caracteres.")]
    public string Apellido { get; set; } = null!;

    [Required(ErrorMessage = "El correo es obligatorio.")]
    [EmailAddress(ErrorMessage = "El correo no tiene un formato válido.")]
    [StringLength(120, ErrorMessage = "El correo no puede superar los 120 caracteres.")]
    public string Email { get; set; } = null!;

    [Required(ErrorMessage = "El teléfono es obligatorio.")]
    [StringLength(20, MinimumLength = 6, ErrorMessage = "El teléfono debe tener entre 6 y 20 caracteres.")]
    [RegularExpression(@"^[0-9+\-\s()]+$", ErrorMessage = "El teléfono solo admite números y los signos + - ( ).")]
    public string Telefono { get; set; } = null!;

    [Required(ErrorMessage = "La ciudad es obligatoria.")]
    [StringLength(60, MinimumLength = 2, ErrorMessage = "La ciudad debe tener entre 2 y 60 caracteres.")]
    public string Ciudad { get; set; } = null!;

    [Precision(0)]
    public DateTime FechaRegistro { get; set; }

    public bool Activo { get; set; }

    // Se ignora en el JSON de salida para cortar el ciclo Duenio -> Mascotas -> Duenio.
    [JsonIgnore]
    [InverseProperty("Duenio")]
    public virtual ICollection<Mascota> Mascotas { get; set; } = new List<Mascota>();
}
