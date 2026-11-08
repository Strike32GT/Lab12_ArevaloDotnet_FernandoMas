// Capturas visuales reales realizadas dentro de Swagger UI.
// Requiere PLAYWRIGHT_PATH apuntando al paquete temporal playwright.
const { chromium } = require(process.env.PLAYWRIGHT_PATH);
const path = require('path');
const fs = require('fs');

const baseUrl = 'http://vethuellitas-earevalo.runasp.net';
const output = path.resolve(__dirname, '../../docs/capturas/swagger');
fs.mkdirSync(output, { recursive: true });

const operations = {
  health: 'operations-Diagnóstico-get_health', duenios: 'operations-Duenios-get_api_Duenios',
  postDuenio: 'operations-Duenios-post_api_Duenios', duenio: 'operations-Duenios-get_api_Duenios__id_',
  putDuenio: 'operations-Duenios-put_api_Duenios__id_', delDuenio: 'operations-Duenios-delete_api_Duenios__id_',
  mascotasDuenio: 'operations-Duenios-get_api_Duenios__id__mascotas', resumen: 'operations-Duenios-get_api_Duenios__id__resumen',
  mascotas: 'operations-Mascotas-get_api_Mascotas', postMascota: 'operations-Mascotas-post_api_Mascotas',
  mascota: 'operations-Mascotas-get_api_Mascotas__id_', putMascota: 'operations-Mascotas-put_api_Mascotas__id_',
  delMascota: 'operations-Mascotas-delete_api_Mascotas__id_', estadisticas: 'operations-Mascotas-get_api_Mascotas_estadisticas'
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1300 } });
  const stamp = new Date().toISOString().slice(11,19).replaceAll(':','');
  let duenioId, mascotaId;

  async function run(n, name, op, expected, options = {}) {
    await page.goto(`${baseUrl}/swagger/index.html`, { waitUntil: 'networkidle' });
    const block = page.locator(`#${operations[op]}`);
    await block.locator('.opblock-summary').click();
    await block.getByText('Try it out', { exact: true }).click();
    if (options.id !== undefined) await block.locator('input').first().fill(String(options.id));
    if (options.body) await block.locator('textarea').fill(JSON.stringify(options.body, null, 2));
    await block.getByText('Execute', { exact: true }).click();
    await block.getByText('Server response', { exact: true }).waitFor({ timeout: 30000 });
    await page.waitForTimeout(500);
    const text = await block.innerText();
    const match = text.match(/Server response\s+Code\s+Details\s+(\d{3})/s);
    const actual = match ? Number(match[1]) : 0;
    if (actual !== expected) throw new Error(`${n}-${name}: esperado ${expected}, recibido ${actual}`);
    await block.screenshot({ path: path.join(output, `${String(n).padStart(2,'0')}-${name}-${actual}.png`) });
    console.log(`[${n}] ${name}: ${actual}`);
    return text;
  }

  await run(1,'health','health',200);
  await run(2,'get-duenios','duenios',200);
  await run(3,'get-duenio','duenio',200,{id:1});
  await run(4,'get-duenio-mascotas','mascotasDuenio',200,{id:1});
  await run(5,'get-resumen','resumen',200,{id:1});
  await run(6,'get-mascotas','mascotas',200);
  await run(7,'get-mascota','mascota',200,{id:1});
  await run(8,'estadisticas','estadisticas',200);

  const email = `swagger.${stamp}@correo.com`;
  let response = await run(9,'post-duenio','postDuenio',201,{body:{nombre:'Swagger',apellido:'Evidencia',email,telefono:'999888777',ciudad:'Lima',activo:true}});
  duenioId = Number((response.match(/"duenioId"\s*:\s*(\d+)/) || [])[1]);
  if (!duenioId) throw new Error('No se obtuvo duenioId de la respuesta Swagger.');
  await run(10,'post-duenio-invalido','postDuenio',400,{body:{nombre:'X',apellido:'Y',email:'invalido',telefono:'abc',ciudad:''}});
  await run(11,'post-duenio-duplicado','postDuenio',409,{body:{nombre:'Swagger',apellido:'Evidencia',email,telefono:'999888777',ciudad:'Lima',activo:true}});
  await run(12,'put-duenio-id-distinto','putDuenio',400,{id:duenioId,body:{duenioId:duenioId+1,nombre:'Swagger',apellido:'Evidencia',email,telefono:'999888777',ciudad:'Lima',activo:true}});
  await run(13,'put-duenio','putDuenio',204,{id:duenioId,body:{duenioId,nombre:'Swagger',apellido:'Actualizada',email,telefono:'999888777',ciudad:'Callao',activo:true}});

  response = await run(14,'post-mascota','postMascota',201,{body:{duenioId,nombre:'Kira',especie:'Perro',raza:'Mestiza',fechaNacimiento:'2023-04-15',peso:9.4,activa:true}});
  mascotaId = Number((response.match(/"mascotaId"\s*:\s*(\d+)/) || [])[1]);
  if (!mascotaId) throw new Error('No se obtuvo mascotaId de la respuesta Swagger.');
  await run(15,'post-mascota-fk-invalida','postMascota',400,{body:{duenioId:999999,nombre:'Fantasma',especie:'Perro',peso:5}});
  await run(16,'post-mascota-duplicada','postMascota',409,{body:{duenioId,nombre:'Kira',especie:'Gato',peso:4}});
  await run(17,'put-mascota-id-distinto','putMascota',400,{id:mascotaId,body:{mascotaId:mascotaId+1,duenioId,nombre:'Kira',especie:'Perro',peso:10.5}});
  await run(18,'put-mascota','putMascota',204,{id:mascotaId,body:{mascotaId,duenioId,nombre:'Kira',especie:'Perro',raza:'Mestiza',fechaNacimiento:'2023-04-15',peso:10.5,activa:true}});
  await run(19,'delete-duenio-con-mascotas','delDuenio',409,{id:duenioId});
  await run(20,'delete-mascota','delMascota',204,{id:mascotaId});
  await run(21,'delete-mascota-inexistente','delMascota',404,{id:mascotaId});
  await run(22,'delete-duenio','delDuenio',204,{id:duenioId});
  await run(23,'delete-duenio-inexistente','delDuenio',404,{id:duenioId});
  await run(24,'get-duenio-inexistente','duenio',404,{id:999999});
  await run(25,'get-mascota-inexistente','mascota',404,{id:999999});
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
