# Observaciones

El Scaffold generó la navegación `Duenio` como no anulable y la colección con el nombre
`Mascota` en singular. Tuve que editar el modelo para dejar `Duenio?` y renombrar la
colección a `Mascotas`, además de ajustar la relación en el DbContext con
`DeleteBehavior.NoAction`, que es lo que realmente hace la base.

La validación del correo repetido se hace con una consulta antes de insertar, pero eso no
elimina la carrera entre dos peticiones simultáneas. El índice único de SQL Server es el
que realmente garantiza la regla; si dos request llegan a la vez, uno termina con error de
base de datos. Para la escala del laboratorio la comprobación previa alcanza y da un 409
claro, pero en producción convendría capturar esa excepción y responder igual con 409.

El script de creación y el de la nube son casi iguales a propósito. La diferencia es que el
primero crea la base y hace `USE`, mientras que el segundo asume que la base ya existe,
porque en Azure SQL y en varios paneles gratuitos la base se crea desde el portal.

En los planes gratuitos la aplicación se suspende por inactividad, así que la primera
petición puede demorar bastante y hasta devolver un error de pasarela. No es un fallo de la
API: conviene calentar `/health` antes de tomar las capturas. Por eso el script de pruebas
usa un tiempo de espera de noventa segundos.

La redirección a HTTPS quedó activa solo en desarrollo. Detrás de un proxy que ya termina
TLS, redirigir otra vez puede provocar bucles y romper Swagger en la nube. El proveedor se
encarga del certificado y la API escucha en el puerto que la plataforma le asigna.

El paquete Swashbuckle.AspNetCore.SwaggerUI solo aporta la pantalla; el documento OpenAPI
lo genera `Microsoft.AspNetCore.OpenApi` con `MapOpenApi`. Esa combinación funciona bien en
.NET 10 y evita depender de una versión de Swashbuckle que todavía no soporte el framework.

Las pruebas se pueden repetir con el script incluido, pero los datos que crea llevan un
sufijo de hora para no chocar con el correo único. Aun así, si se ejecuta muchas veces
quedan huecos en los identificadores por los intentos fallidos, algo normal en una columna
identity.
