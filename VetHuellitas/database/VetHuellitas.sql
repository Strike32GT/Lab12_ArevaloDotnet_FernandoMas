/* ============================================================
   VetHuellitas - Clinica Veterinaria
   Script de creacion de base de datos, tablas y datos de ejemplo
   Motor: SQL Server 2019 o superior (LocalDB / Express / Azure SQL)
   ============================================================ */

IF DB_ID('VetHuellitas') IS NULL
BEGIN
    CREATE DATABASE VetHuellitas;
END;
GO

USE VetHuellitas;
GO

/* Limpieza ordenada por la relacion 1:N */
IF OBJECT_ID('dbo.Mascotas', 'U') IS NOT NULL DROP TABLE dbo.Mascotas;
IF OBJECT_ID('dbo.Duenios', 'U') IS NOT NULL DROP TABLE dbo.Duenios;
GO

/* ------------------------- Duenios ------------------------- */
CREATE TABLE dbo.Duenios
(
    DuenioId      INT            IDENTITY(1,1) NOT NULL,
    Nombre        NVARCHAR(80)   NOT NULL,
    Apellido      NVARCHAR(80)   NOT NULL,
    Email         NVARCHAR(120)  NOT NULL,
    Telefono      NVARCHAR(20)   NOT NULL,
    Ciudad        NVARCHAR(60)   NOT NULL,
    FechaRegistro DATETIME2(0)   NOT NULL CONSTRAINT DF_Duenios_FechaRegistro DEFAULT (SYSDATETIME()),
    Activo        BIT            NOT NULL CONSTRAINT DF_Duenios_Activo DEFAULT (1),
    CONSTRAINT PK_Duenios PRIMARY KEY (DuenioId),
    CONSTRAINT UQ_Duenios_Email UNIQUE (Email)
);
GO

/* ------------------------- Mascotas ------------------------ */
CREATE TABLE dbo.Mascotas
(
    MascotaId       INT           IDENTITY(1,1) NOT NULL,
    DuenioId        INT           NOT NULL,
    Nombre          NVARCHAR(60)  NOT NULL,
    Especie         NVARCHAR(40)  NOT NULL,
    Raza            NVARCHAR(60)  NULL,
    FechaNacimiento DATE          NULL,
    Peso            DECIMAL(5,2)  NOT NULL,
    Activa          BIT           NOT NULL CONSTRAINT DF_Mascotas_Activa DEFAULT (1),
    CONSTRAINT PK_Mascotas PRIMARY KEY (MascotaId),
    CONSTRAINT FK_Mascotas_Duenios FOREIGN KEY (DuenioId)
        REFERENCES dbo.Duenios (DuenioId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_Mascotas_Duenio_Nombre UNIQUE (DuenioId, Nombre),
    CONSTRAINT CK_Mascotas_Peso CHECK (Peso > 0 AND Peso <= 200)
);
GO

CREATE INDEX IX_Mascotas_DuenioId ON dbo.Mascotas (DuenioId);
GO

/* --------------------- Datos de ejemplo -------------------- */
INSERT INTO dbo.Duenios (Nombre, Apellido, Email, Telefono, Ciudad, FechaRegistro, Activo)
VALUES
('Ana',      'Torres',   'ana.torres@correo.com',      '987654321', 'Lima',      '2026-01-12', 1),
('Luis',     'Ramirez',  'luis.ramirez@correo.com',    '912345678', 'Arequipa',  '2026-02-03', 1),
('Carla',    'Mendoza',  'carla.mendoza@correo.com',   '955112233', 'Trujillo',  '2026-02-21', 1),
('Jorge',    'Salazar',  'jorge.salazar@correo.com',   '944556677', 'Lima',      '2026-03-08', 0),
('Mariana',  'Vargas',   'mariana.vargas@correo.com',  '933221100', 'Cusco',     '2026-03-19', 1);
GO

INSERT INTO dbo.Mascotas (DuenioId, Nombre, Especie, Raza, FechaNacimiento, Peso, Activa)
VALUES
(1, 'Luna',    'Perro', 'Labrador',     '2022-05-10', 28.50, 1),
(1, 'Michi',   'Gato',  'Siames',       '2023-08-15',  4.20, 1),
(2, 'Rocky',   'Perro', 'Bulldog',      '2021-11-02', 22.30, 1),
(3, 'Nala',    'Gato',  'Persa',        '2020-03-27',  3.80, 1),
(3, 'Toby',    'Perro', 'Beagle',       '2024-01-09', 12.10, 1),
(3, 'Kiara',   'Ave',   'Periquito',    '2025-06-18',  0.09, 1),
(5, 'Firulais','Perro', 'Mestizo',      '2019-09-30', 18.75, 0);
GO

SELECT d.DuenioId, d.Nombre + ' ' + d.Apellido AS Duenio, COUNT(m.MascotaId) AS Mascotas
FROM dbo.Duenios d
LEFT JOIN dbo.Mascotas m ON m.DuenioId = d.DuenioId
GROUP BY d.DuenioId, d.Nombre, d.Apellido
ORDER BY d.DuenioId;
GO
