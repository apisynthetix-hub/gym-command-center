# SYNTHETIX GYM OS PRO V1

Base profesional de gimnasio offline-first, sin paquetes externos.

## Incluye
- Dashboard / Command Center
- Clientes y alta rápida
- Membresías y estados dentro del CRM
- Check-in / acceso
- Finanzas y pagos
- Entrenadores
- Rutinas / entrenamiento
- Analytics
- Configuración
- Navbar inferior con FAB central en móvil
- Sidebar profesional en pantallas grandes
- Tema oscuro rojo/cian conservando el concepto del prototipo original

## Arquitectura
`main.dart` es mínimo. La aplicación está separada en `core`, `data` y `features`.

> V1 usa datos locales en memoria para que la interfaz sea ejecutable sin dependencias. El siguiente paso puede conectar persistencia local real sin rehacer la UI.
