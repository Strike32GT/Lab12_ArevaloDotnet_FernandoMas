using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using VetHuellitas.Models;

namespace VetHuellitas.Data;

public partial class VetHuellitasContext : DbContext
{
    public VetHuellitasContext(DbContextOptions<VetHuellitasContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Duenio> Duenios { get; set; }

    public virtual DbSet<Mascota> Mascotas { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Duenio>(entity =>
        {
            entity.Property(e => e.Activo).HasDefaultValue(true, "DF_Duenios_Activo");
            entity.Property(e => e.FechaRegistro).HasDefaultValueSql("(sysdatetime())", "DF_Duenios_FechaRegistro");
        });

        modelBuilder.Entity<Mascota>(entity =>
        {
            entity.Property(e => e.Activa).HasDefaultValue(true, "DF_Mascotas_Activa");

            // La FK es NO ACTION: no se puede borrar un dueño con mascotas.
            entity.HasOne(d => d.Duenio).WithMany(p => p.Mascotas)
                .OnDelete(DeleteBehavior.NoAction)
                .HasConstraintName("FK_Mascotas_Duenios");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
