# Conclusiones

Trabajar con Scaffold me dejó claro que la base de datos manda cuando se elige el enfoque
database first: el script define índices, restricciones y valores por defecto, y EF Core
solo traduce lo que ya existe. Por eso el índice único del correo y la restricción de peso
quedaron iguales en el modelo y en SQL, sin duplicar reglas a mano.

Las Data Annotations resolvieron la mitad del trabajo de validación sin escribir un solo
if, porque con `[ApiController]` el framework devuelve 400 y el detalle de los campos
inválidos antes de entrar a la acción. Lo que sí tuve que programar fue la lógica de
negocio: verificar el correo repetido, revisar que el dueño exista antes de guardar una
mascota y bloquear el borrado de dueños con dependientes. Ahí el 409 tiene sentido, porque
la petición está bien formada pero choca con una regla del negocio.

El uso de LINQ asíncrono se siente natural con `ToListAsync` y `AnyAsync`, y `AsNoTracking`
ayuda en los listados de solo lectura. La parte que más cuidé fue el JSON: dejar la
navegación del hijo como opcional permite que el POST solo envíe la clave foránea, y el
`[JsonIgnore]` en la colección del padre corta el ciclo sin necesidad de DTOs.

Sobre el despliegue, mantener SQL Server en la nube es la opción que menos código toca,
porque el script y el proveedor siguen iguales. Si se elige PostgreSQL o MySQL hay que
cambiar el paquete, usar `UseNpgsql` o `UseMySql` y adaptar los tipos del script; es un
cambio pequeño pero real, y conviene decidirlo antes de generar el modelo. También aprendí
que la cadena de conexión debe vivir fuera del repositorio, en user secrets en local y en
variables de entorno en la nube.
