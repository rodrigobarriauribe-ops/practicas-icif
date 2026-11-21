-- =====================================================================
-- Plataforma de Prácticas ICIF · instalación en Supabase
-- Ejecuta este archivo completo en Supabase → SQL Editor → New query → Run.
-- Se puede volver a ejecutar sin perder datos.
-- =====================================================================

-- ---------- Tablas ----------
create table if not exists public.personas (
  email     text primary key check (email = lower(email)),
  nombre    text not null default '',
  rol       text not null check (rol in ('direccion','docente','estudiante','supervisor')),
  rut       text not null default '',
  malla     text not null default '2024' check (malla in ('2019','2024')),
  nivel     int  not null default 0,
  telefono  text not null default '',
  creado    timestamptz not null default now()
);

create table if not exists public.practicas (
  id               uuid primary key default gen_random_uuid(),
  estudiante_email text not null references public.personas(email) on update cascade,
  tipo             text not null check (tipo in ('industrial','profesional')),
  periodo          text not null default '',
  nrc              text not null default '',
  docente_email    text references public.personas(email) on update cascade,
  empresa          jsonb not null default '{"razon":"","rut":"","direccion":"","rep":"","rutRep":"","area":""}',
  supervisor       jsonb not null default '{"nombre":"","cargo":"","correo":"","telefono":""}',
  inicio           date,
  termino          date,
  checklist        jsonb not null default '{"inscrita":false,"cupo":false,"requisitos":false,"noConsecutiva":false}',
  solicitud_fecha  date,
  activacion_fecha date,
  seguro           jsonb,
  obs_solicitud    jsonb,
  cierre           jsonb,
  creado           timestamptz not null default now()
);

create table if not exists public.cartas (
  id              uuid primary key default gen_random_uuid(),
  practica_id     uuid not null references public.practicas(id) on delete cascade,
  empresa         text not null default '',
  destinatario    text not null default '',
  cargo           text not null default '',
  estado          text not null default 'solicitada' check (estado in ('solicitada','emitida','rechazada')),
  fecha_solicitud date not null,
  fecha_emision   date,
  vence           date,
  folio           text unique,
  codigo          text,
  motivo          text,
  creado          timestamptz not null default now()
);

create table if not exists public.informes (
  id          uuid primary key default gen_random_uuid(),
  practica_id uuid not null references public.practicas(id) on delete cascade,
  version     int not null,
  nombre      text not null,
  size        bigint not null default 0,
  path        text not null,
  fecha       date not null,
  unique (practica_id, version)
);

create table if not exists public.devoluciones (
  id             uuid primary key default gen_random_uuid(),
  practica_id    uuid not null references public.practicas(id) on delete cascade,
  version        int not null,
  texto          text not null,
  por            text not null default '',
  fecha          date not null,
  resuelta       boolean not null default false,
  resuelta_fecha date,
  creado         timestamptz not null default now()
);

create table if not exists public.evaluaciones (
  id          uuid primary key default gen_random_uuid(),
  practica_id uuid not null references public.practicas(id) on delete cascade,
  rol         text not null check (rol in ('empresa','academico')),
  criterios   jsonb not null,
  niveles     jsonb not null,
  nota        numeric(2,1) not null,
  extras      jsonb not null default '{}',
  por         text not null default '',
  fecha       date not null,
  unique (practica_id, rol)
);

create table if not exists public.docs_empresa (
  id          uuid primary key default gen_random_uuid(),
  practica_id uuid not null references public.practicas(id) on delete cascade,
  nombre      text not null,
  size        bigint not null default 0,
  path        text not null,
  fecha       date not null,
  por         text not null default ''
);

create table if not exists public.historial (
  id          bigserial primary key,
  practica_id uuid not null references public.practicas(id) on delete cascade,
  fecha       date not null,
  actor       text not null,
  texto       text not null,
  creado      timestamptz not null default now()
);

create table if not exists public.config (
  id   int primary key default 1 check (id = 1),
  data jsonb not null
);

-- Nadie accede a las tablas directamente: todo pasa por las funciones de abajo,
-- que revisan quién es la persona y qué puede hacer.
alter table public.personas     enable row level security;
alter table public.practicas    enable row level security;
alter table public.cartas       enable row level security;
alter table public.informes     enable row level security;
alter table public.devoluciones enable row level security;
alter table public.evaluaciones enable row level security;
alter table public.docs_empresa enable row level security;
alter table public.historial    enable row level security;
alter table public.config       enable row level security;
revoke all on public.personas, public.practicas, public.cartas, public.informes, public.devoluciones,
  public.evaluaciones, public.docs_empresa, public.historial, public.config from anon, authenticated;

insert into public.config (id, data) values (1, $cfg${"exigencia":60,"ponderacion":{"industrial":{"empresa":40,"academico":60},"profesional":{"empresa":40,"academico":60}},"matrices":{"industrial":{"empresa":[{"id":"ie1","nombre":"Responsabilidad y puntualidad","desc":"Cumple horarios, avisa ausencias y responde por sus compromisos.","peso":15},{"id":"ie2","nombre":"Cumplimiento de tareas asignadas","desc":"Completa las tareas en plazo y con la calidad pedida.","peso":15},{"id":"ie3","nombre":"Aplicación de conocimientos técnicos","desc":"Usa lo aprendido en la carrera (programación, bases de datos, redes).","peso":15},{"id":"ie4","nombre":"Disposición a aprender y adaptarse","desc":"Incorpora herramientas y procesos nuevos de la organización.","peso":15},{"id":"ie5","nombre":"Trabajo en equipo","desc":"Colabora y mantiene buenas relaciones con el equipo.","peso":10},{"id":"ie6","nombre":"Comunicación oral y escrita","desc":"Informa avances y dudas con claridad.","peso":10},{"id":"ie7","nombre":"Iniciativa","desc":"Propone mejoras y busca soluciones antes de pedir ayuda.","peso":10},{"id":"ie8","nombre":"Normas, seguridad y confidencialidad","desc":"Respeta reglamentos internos y el manejo de la información.","peso":10}],"academico":[{"id":"ia1","nombre":"Estructura y formato","desc":"Sigue la pauta: portada, índice, secciones y anexos.","peso":15},{"id":"ia2","nombre":"Organización y área TI","desc":"Describe el rubro, la estructura y el rol del área donde trabajó.","peso":15},{"id":"ia3","nombre":"Actividades realizadas","desc":"Detalla tareas, herramientas y resultados, con evidencias.","peso":25},{"id":"ia4","nombre":"Relación con la formación","desc":"Vincula las actividades con asignaturas de la malla.","peso":20},{"id":"ia5","nombre":"Reflexión sobre aprendizajes","desc":"Identifica lo aprendido, dificultades y aspectos a mejorar.","peso":15},{"id":"ia6","nombre":"Redacción y ortografía","desc":"Escritura clara y técnica; cita sus fuentes.","peso":10}]},"profesional":{"empresa":[{"id":"pe1","nombre":"Calidad técnica de las soluciones","desc":"Analiza, diseña y desarrolla soluciones correctas y mantenibles.","peso":20},{"id":"pe2","nombre":"Autonomía y resolución de problemas","desc":"Enfrenta problemas nuevos con poca supervisión.","peso":15},{"id":"pe3","nombre":"Planificación y plazos","desc":"Organiza su trabajo y cumple lo comprometido.","peso":10},{"id":"pe4","nombre":"Metodologías y buenas prácticas","desc":"Control de versiones, pruebas, documentación, metodología de desarrollo.","peso":10},{"id":"pe5","nombre":"Comunicación técnica","desc":"Explica decisiones técnicas al equipo y a usuarios.","peso":10},{"id":"pe6","nombre":"Trabajo en equipo y liderazgo","desc":"Coordina tareas y apoya a otros integrantes.","peso":10},{"id":"pe7","nombre":"Responsabilidad y compromiso","desc":"Cumple horarios y se hace cargo de sus entregables.","peso":10},{"id":"pe8","nombre":"Ética y confidencialidad","desc":"Maneja con reserva la información y los accesos.","peso":5},{"id":"pe9","nombre":"Aporte a la organización","desc":"Su trabajo deja un resultado útil para la empresa.","peso":10}],"academico":[{"id":"pa1","nombre":"Contexto y problema abordado","desc":"Presenta la organización y define el problema con claridad.","peso":15},{"id":"pa2","nombre":"Solución técnica y fundamentación","desc":"Justifica el diseño y las decisiones técnicas.","peso":25},{"id":"pa3","nombre":"Metodología y herramientas","desc":"Explica cómo trabajó y con qué tecnologías.","peso":15},{"id":"pa4","nombre":"Resultados e impacto","desc":"Muestra resultados medibles y su efecto en la organización.","peso":15},{"id":"pa5","nombre":"Vínculo con el perfil de egreso","desc":"Relaciona su trabajo con las competencias de la carrera.","peso":10},{"id":"pa6","nombre":"Conclusiones y reflexión crítica","desc":"Evalúa su desempeño y propone mejoras.","peso":10},{"id":"pa7","nombre":"Redacción, formato y referencias","desc":"Escritura técnica correcta y fuentes citadas.","peso":10}]}},"carta":{"firmante":"","cargo":"Director/a de Carrera","unidad":"Ingeniería Civil Informática","sede":"Sede De la Patagonia","ciudad":"Puerto Montt","correo":"","telefono":"","vigencia":60,"auto":false,"legal":true,"seq":0}}$cfg$::jsonb)
on conflict (id) do nothing;

-- ---------- Funciones de apoyo ----------
create or replace function public._hoy() returns date
language sql stable as $$ select (now() at time zone 'America/Santiago')::date $$;

create or replace function public._email() returns text
language sql stable as $$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function public._yo() returns public.personas
language sql stable security definer set search_path = public as $$
  select * from public.personas where email = public._email()
$$;

create or replace function public._es_dir() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.personas where email = public._email() and rol = 'direccion')
$$;

create or replace function public._puede_ver(v public.practicas) returns boolean
language sql stable security definer set search_path = public as $$
  select public._es_dir()
      or v.estudiante_email = public._email()
      or (v.activacion_fecha is not null and v.docente_email = public._email())
      or (v.activacion_fecha is not null and lower(coalesce(v.supervisor ->> 'correo', '')) = public._email())
$$;

create or replace function public._practica(p_id uuid) returns public.practicas
language plpgsql stable security definer set search_path = public as $$
declare v public.practicas;
begin
  select * into v from public.practicas where id = p_id;
  if v.id is null or not public._puede_ver(v) then
    raise exception 'No encontramos esa práctica o no tienes acceso a ella.';
  end if;
  return v;
end $$;

create or replace function public._hist(p_id uuid, p_texto text) returns void
language plpgsql security definer set search_path = public as $$
declare r text;
begin
  select rol into r from public.personas where email = public._email();
  insert into public.historial (practica_id, fecha, actor, texto)
  values (p_id, public._hoy(),
    case r when 'direccion' then 'Dirección de Carrera' when 'docente' then 'Académico/a'
           when 'estudiante' then 'Estudiante' when 'supervisor' then 'Supervisor/a de empresa' else 'Sistema' end,
    p_texto);
end $$;

-- Nota en escala 1,0 a 7,0 con exigencia configurable (60 % = 4,0)
create or replace function public.calc_nota(p_criterios jsonb, p_niveles jsonb, p_exig numeric) returns numeric
language plpgsql immutable as $$
declare c jsonb; n int; tot numeric := 0; got numeric := 0; p numeric; e numeric := p_exig / 100; nota numeric;
begin
  for c in select * from jsonb_array_elements(p_criterios) loop
    n := (p_niveles ->> (c ->> 'id'))::int;
    if n is null or n < 1 or n > 4 then raise exception 'Falta evaluar el criterio «%».', c ->> 'nombre'; end if;
    tot := tot + coalesce((c ->> 'peso')::numeric, 0);
    got := got + coalesce((c ->> 'peso')::numeric, 0) * n / 4;
  end loop;
  if tot = 0 then raise exception 'La matriz no tiene pesos.'; end if;
  p := got / tot;
  nota := case when p < e then 1 + 3 * p / e else 4 + 3 * (p - e) / (1 - e) end;
  return round(least(7, greatest(1, nota)), 1);
end $$;

create or replace function public._eval_json(p_id uuid, p_rol text, p_viewer text, p_cerrada boolean) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare ev public.evaluaciones;
begin
  select * into ev from public.evaluaciones where practica_id = p_id and rol = p_rol;
  if ev.id is null then return null; end if;
  if p_viewer = 'estudiante' and not p_cerrada then
    if p_rol = 'empresa' then return jsonb_build_object('fecha', ev.fecha::text); end if;
    return jsonb_build_object('fecha', ev.fecha::text, 'por', ev.por, 'comentario', ev.extras ->> 'comentario');
  end if;
  if p_viewer = 'supervisor' and p_rol = 'academico' then
    return jsonb_build_object('fecha', ev.fecha::text);
  end if;
  return jsonb_build_object('criterios', ev.criterios, 'niveles', ev.niveles, 'nota', ev.nota,
    'fecha', ev.fecha::text, 'por', ev.por) || ev.extras;
end $$;

create or replace function public._practica_json(v public.practicas, p_viewer text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', v.id, 'estudianteId', v.estudiante_email, 'tipo', v.tipo, 'periodo', v.periodo, 'nrc', v.nrc,
    'academicoId', coalesce(v.docente_email, ''), 'empresa', v.empresa, 'supervisor', v.supervisor,
    'inicio', coalesce(v.inicio::text, ''), 'termino', coalesce(v.termino::text, ''), 'checklist', v.checklist,
    'solicitud', case when v.solicitud_fecha is null then null else jsonb_build_object('fecha', v.solicitud_fecha::text) end,
    'activacion', case when v.activacion_fecha is null then null else jsonb_build_object('fecha', v.activacion_fecha::text) end,
    'seguro', v.seguro, 'obsSolicitud', v.obs_solicitud,
    'cierre', case when v.cierre is null then null when p_viewer = 'supervisor' then jsonb_build_object('fecha', v.cierre ->> 'fecha') else v.cierre end,
    'informes', coalesce((select jsonb_agg(jsonb_build_object('version', i.version, 'nombre', i.nombre, 'size', i.size, 'fecha', i.fecha::text, 'path', i.path) order by i.version)
                          from public.informes i where i.practica_id = v.id), '[]'::jsonb),
    'devoluciones', coalesce((select jsonb_agg(jsonb_build_object('fecha', d.fecha::text, 'version', d.version, 'por', d.por, 'texto', d.texto, 'resuelta', d.resuelta) order by d.creado)
                          from public.devoluciones d where d.practica_id = v.id), '[]'::jsonb),
    'evalEmpresa', public._eval_json(v.id, 'empresa', p_viewer, v.cierre is not null),
    'evalAcademico', public._eval_json(v.id, 'academico', p_viewer, v.cierre is not null),
    'docsEmpresa', coalesce((select jsonb_agg(jsonb_build_object('nombre', x.nombre, 'size', x.size, 'fecha', x.fecha::text, 'path', x.path, 'por', x.por) order by x.fecha)
                          from public.docs_empresa x where x.practica_id = v.id), '[]'::jsonb),
    'historial', case when p_viewer = 'supervisor' then '[]'::jsonb else
                 coalesce((select jsonb_agg(jsonb_build_object('fecha', h.fecha::text, 'actor', h.actor, 'texto', h.texto) order by h.id)
                          from public.historial h where h.practica_id = v.id), '[]'::jsonb) end,
    'cartas', case when p_viewer = 'supervisor' then '[]'::jsonb else
              coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'empresa', c.empresa, 'destinatario', c.destinatario, 'cargo', c.cargo, 'estado', c.estado,
                          'fechaSolicitud', c.fecha_solicitud::text, 'fechaEmision', c.fecha_emision::text, 'vence', c.vence::text, 'folio', c.folio, 'codigo', c.codigo, 'motivo', c.motivo) order by c.creado)
                          from public.cartas c where c.practica_id = v.id), '[]'::jsonb) end
  )
$$;

-- ---------- Lectura: todo lo que la persona puede ver ----------
create or replace function public.estado() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare me public.personas; r jsonb;
begin
  select * into me from public.personas where email = public._email();
  if me.email is null then return jsonb_build_object('yo', null, 'email', public._email()); end if;
  with vis as (select p.* from public.practicas p where public._puede_ver(p))
  select jsonb_build_object(
    'yo', jsonb_build_object('email', me.email, 'nombre', me.nombre, 'rol', me.rol),
    'config', (select data from public.config where id = 1),
    'practicas', coalesce((select jsonb_agg(public._practica_json(v, me.rol) order by v.creado) from vis v), '[]'::jsonb),
    'estudiantes', coalesce((select jsonb_agg(jsonb_build_object('id', e.email, 'nombre', e.nombre,
          'rut', case when me.rol = 'supervisor' then '' else e.rut end, 'malla', e.malla, 'nivel', e.nivel, 'correo', e.email,
          'telefono', case when me.rol = 'supervisor' then '' else e.telefono end) order by e.nombre)
        from public.personas e where e.rol = 'estudiante' and (me.rol = 'direccion' or exists (select 1 from vis v where v.estudiante_email = e.email))), '[]'::jsonb),
    'academicos', coalesce((select jsonb_agg(jsonb_build_object('id', d.email, 'nombre', d.nombre, 'correo', d.email) order by d.nombre)
        from public.personas d where d.rol = 'docente'), '[]'::jsonb),
    'equipo', case when me.rol = 'direccion' then coalesce((select jsonb_agg(jsonb_build_object('email', x.email, 'nombre', x.nombre, 'rol', x.rol) order by x.rol, x.nombre)
        from public.personas x where x.rol in ('direccion', 'docente')), '[]'::jsonb) else '[]'::jsonb end
  ) into r;
  return r;
end $$;

-- ---------- Acciones del estudiante ----------
create or replace function public.guardar_borrador(p_id uuid, p_datos jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare v public.practicas; me public.personas; d text; est jsonb;
begin
  v := public._practica(p_id); me := public._yo();
  if not (me.rol = 'direccion' or (me.rol = 'estudiante' and v.estudiante_email = me.email and v.solicitud_fecha is null)) then
    raise exception 'Esta práctica ya no se puede modificar desde el formulario.';
  end if;
  if p_datos ? 'academicoId' then
    d := nullif(lower(p_datos ->> 'academicoId'), '');
    if d is not null and not exists (select 1 from public.personas where email = d and rol = 'docente') then
      raise exception 'El docente elegido no está registrado.';
    end if;
  end if;
  update public.practicas set
    tipo      = coalesce(p_datos ->> 'tipo', tipo),
    nrc       = coalesce(p_datos ->> 'nrc', nrc),
    docente_email = case when p_datos ? 'academicoId' then d else docente_email end,
    empresa   = case when p_datos ? 'empresa' then empresa || (p_datos -> 'empresa') else empresa end,
    supervisor = case when p_datos ? 'supervisor'
                 then supervisor || (p_datos -> 'supervisor') || jsonb_build_object('correo', lower(trim(coalesce(p_datos -> 'supervisor' ->> 'correo', supervisor ->> 'correo', ''))))
                 else supervisor end,
    inicio    = case when p_datos ? 'inicio' then nullif(p_datos ->> 'inicio', '')::date else inicio end,
    termino   = case when p_datos ? 'termino' then nullif(p_datos ->> 'termino', '')::date else termino end,
    checklist = case when p_datos ? 'checklist' then checklist || (p_datos -> 'checklist') else checklist end
  where id = p_id;
  est := p_datos -> 'estudiante';
  if est is not null then
    update public.personas set
      rut      = coalesce(est ->> 'rut', rut),
      telefono = coalesce(est ->> 'telefono', telefono),
      malla    = coalesce(est ->> 'malla', malla),
      nivel    = coalesce((est ->> 'nivel')::int, nivel)
    where email = v.estudiante_email;
  end if;
end $$;

create or replace function public.enviar_solicitud(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v public.practicas; me public.personas; k text;
begin
  v := public._practica(p_id); me := public._yo();
  if me.rol <> 'estudiante' or v.estudiante_email <> me.email then raise exception 'Solo el estudiante puede enviar su solicitud.'; end if;
  if v.solicitud_fecha is not null then raise exception 'La solicitud ya fue enviada.'; end if;
  if v.nrc = '' then raise exception 'Falta el NRC de la sección.'; end if;
  if v.docente_email is null then raise exception 'Falta elegir al docente corrector/a.'; end if;
  foreach k in array array['razon','rut','direccion','rep','rutRep'] loop
    if coalesce(v.empresa ->> k, '') = '' then raise exception 'Faltan datos de la empresa.'; end if;
  end loop;
  foreach k in array array['nombre','cargo','correo','telefono'] loop
    if coalesce(v.supervisor ->> k, '') = '' then raise exception 'Faltan datos del supervisor/a.'; end if;
  end loop;
  if v.inicio is null or v.termino is null or v.inicio <= public._hoy() or v.termino <= v.inicio then
    raise exception 'Revisa las fechas: el inicio debe ser posterior a hoy y el término posterior al inicio.';
  end if;
  foreach k in array array['inscrita','cupo','requisitos','noConsecutiva'] loop
    if coalesce((v.checklist ->> k)::boolean, false) = false then raise exception 'Faltan confirmaciones en el formulario.'; end if;
  end loop;
  update public.practicas set solicitud_fecha = public._hoy(), obs_solicitud = null where id = p_id;
  perform public._hist(p_id, 'Envió la solicitud de activación a la Dirección de Carrera.');
end $$;

create or replace function public._emitir(p_carta uuid) returns void
language plpgsql security definer set search_path = public as $$
declare c public.cartas; n int; vig int; alfabeto text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; cod text := ''; i int;
begin
  select * into c from public.cartas where id = p_carta for update;
  if c.estado <> 'solicitada' then raise exception 'La carta ya fue procesada.'; end if;
  update public.config set data = jsonb_set(data, '{carta,seq}', to_jsonb(coalesce((data #>> '{carta,seq}')::int, 0) + 1))
    where id = 1 returning (data #>> '{carta,seq}')::int, coalesce((data #>> '{carta,vigencia}')::int, 60) into n, vig;
  for i in 1..8 loop
    cod := cod || substr(alfabeto, 1 + floor(random() * length(alfabeto))::int, 1);
    if i = 4 then cod := cod || '-'; end if;
  end loop;
  update public.cartas set estado = 'emitida', fecha_emision = public._hoy(), vence = public._hoy() + vig,
    folio = 'ICIF-PAP-' || extract(year from public._hoy())::int || '-' || lpad(n::text, 3, '0'), codigo = cod
  where id = p_carta;
  select * into c from public.cartas where id = p_carta;
  perform public._hist(c.practica_id, format('Emitió la carta de presentación N° %s para %s.', c.folio, coalesce(nullif(c.empresa, ''), 'uso general')));
end $$;

create or replace function public.pedir_carta(p_id uuid, p_empresa text, p_destinatario text, p_cargo text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v public.practicas; me public.personas; cid uuid; c public.cartas;
begin
  v := public._practica(p_id); me := public._yo();
  if me.rol <> 'estudiante' or v.estudiante_email <> me.email then raise exception 'Solo el estudiante puede pedir su carta.'; end if;
  if v.activacion_fecha is not null then raise exception 'Tu práctica ya está activada.'; end if;
  insert into public.cartas (practica_id, empresa, destinatario, cargo, fecha_solicitud)
  values (p_id, trim(coalesce(p_empresa, '')), trim(coalesce(p_destinatario, '')), trim(coalesce(p_cargo, '')), public._hoy())
  returning id into cid;
  perform public._hist(p_id, format('Pidió una carta de presentación para %s.', coalesce(nullif(trim(p_empresa), ''), 'uso general')));
  if coalesce((select (data #>> '{carta,auto}')::boolean from public.config where id = 1), false) then
    perform public._emitir(cid);
  end if;
  select * into c from public.cartas where id = cid;
  return jsonb_build_object('estado', c.estado, 'folio', c.folio);
end $$;

create or replace function public.registrar_informe(p_id uuid, p_nombre text, p_size bigint, p_path text) returns int
language plpgsql security definer set search_path = public as $$
declare v public.practicas; me public.personas; ver int;
begin
  v := public._practica(p_id); me := public._yo();
  if me.rol <> 'estudiante' or v.estudiante_email <> me.email then raise exception 'Solo el estudiante puede subir su informe.'; end if;
  if v.seguro is null or v.cierre is not null or exists (select 1 from public.evaluaciones where practica_id = p_id and rol = 'academico') then
    raise exception 'En esta etapa no se puede subir el informe.';
  end if;
  if p_path not like p_id::text || '/%' then raise exception 'Ruta de archivo no válida.'; end if;
  select coalesce(max(version), 0) + 1 into ver from public.informes where practica_id = p_id;
  insert into public.informes (practica_id, version, nombre, size, path, fecha) values (p_id, ver, p_nombre, p_size, p_path, public._hoy());
  update public.devoluciones set resuelta = true, resuelta_fecha = public._hoy() where practica_id = p_id and not resuelta;
  perform public._hist(p_id, format('Subió el informe (versión %s).', ver));
  return ver;
end $$;

-- ---------- Acciones del supervisor/a ----------
create or replace function public.evaluar_empresa(p_id uuid, p_niveles jsonb, p_extras jsonb) returns numeric
language plpgsql security definer set search_path = public as $$
declare v public.practicas; me public.personas; cfg jsonb; crit jsonb; nota numeric;
begin
  v := public._practica(p_id); me := public._yo();
  if me.rol <> 'supervisor' or lower(v.supervisor ->> 'correo') <> me.email then raise exception 'Solo el supervisor/a de esta práctica puede evaluarla.'; end if;
  if v.seguro is null then raise exception 'La práctica aún no tiene seguro emitido.'; end if;
  if exists (select 1 from public.evaluaciones where practica_id = p_id and rol = 'empresa') then raise exception 'La evaluación ya fue enviada.'; end if;
  if coalesce(trim(p_extras ->> 'fortalezas'), '') = '' then raise exception 'Escribe al menos las fortalezas observadas.'; end if;
  select data into cfg from public.config where id = 1;
  crit := cfg -> 'matrices' -> v.tipo -> 'empresa';
  nota := public.calc_nota(crit, p_niveles, (cfg ->> 'exigencia')::numeric);
  insert into public.evaluaciones (practica_id, rol, criterios, niveles, nota, extras, por, fecha)
  values (p_id, 'empresa', crit, p_niveles, nota,
    jsonb_build_object('fortalezas', trim(p_extras ->> 'fortalezas'), 'mejoras', trim(coalesce(p_extras ->> 'mejoras', '')), 'recibiria', coalesce(p_extras ->> 'recibiria', '')),
    coalesce(nullif(v.supervisor ->> 'nombre', ''), me.nombre), public._hoy());
  perform public._hist(p_id, format('Registró la evaluación de desempeño (nota %s).', replace(nota::text, '.', ',')));
  return nota;
end $$;

create or replace function public.registrar_doc_empresa(p_id uuid, p_nombre text, p_size bigint, p_path text) returns void
language plpgsql security definer set search_path = public as $$
declare v public.practicas; me public.personas;
begin
  v := public._practica(p_id); me := public._yo();
  if not (me.rol = 'direccion' or (me.rol = 'supervisor' and lower(v.supervisor ->> 'correo') = me.email)) then raise exception 'No puedes subir documentos a esta práctica.'; end if;
  if p_path not like p_id::text || '/%' then raise exception 'Ruta de archivo no válida.'; end if;
  insert into public.docs_empresa (practica_id, nombre, size, path, fecha, por) values (p_id, p_nombre, p_size, p_path, public._hoy(), me.nombre);
  perform public._hist(p_id, format('Subió el documento «%s».', p_nombre));
end $$;

-- ---------- Acciones del docente corrector/a ----------
create or replace function public.evaluar_academico(p_id uuid, p_niveles jsonb, p_comentario text) returns numeric
language plpgsql security definer set search_path = public as $$
declare v public.practicas; me public.personas; cfg jsonb; crit jsonb; nota numeric;
begin
  v := public._practica(p_id); me := public._yo();
  if me.rol <> 'docente' or v.docente_email <> me.email then raise exception 'Solo el docente corrector/a asignado puede evaluar este informe.'; end if;
  if not exists (select 1 from public.informes where practica_id = p_id) then raise exception 'El estudiante aún no sube su informe.'; end if;
  if exists (select 1 from public.devoluciones where practica_id = p_id and not resuelta) then raise exception 'Hay observaciones pendientes: espera la nueva versión.'; end if;
  if exists (select 1 from public.evaluaciones where practica_id = p_id and rol = 'academico') then raise exception 'El informe ya fue evaluado.'; end if;
  if coalesce(trim(p_comentario), '') = '' then raise exception 'Escribe una retroalimentación para el estudiante.'; end if;
  select data into cfg from public.config where id = 1;
  crit := cfg -> 'matrices' -> v.tipo -> 'academico';
  nota := public.calc_nota(crit, p_niveles, (cfg ->> 'exigencia')::numeric);
  insert into public.evaluaciones (practica_id, rol, criterios, niveles, nota, extras, por, fecha)
  values (p_id, 'academico', crit, p_niveles, nota, jsonb_build_object('comentario', trim(p_comentario)), me.nombre, public._hoy());
  perform public._hist(p_id, format('Evaluó el informe (nota %s).', replace(nota::text, '.', ',')));
  return nota;
end $$;

create or replace function public.devolver_informe(p_id uuid, p_texto text) returns void
language plpgsql security definer set search_path = public as $$
declare v public.practicas; me public.personas; ver int;
begin
  v := public._practica(p_id); me := public._yo();
  if me.rol <> 'docente' or v.docente_email <> me.email then raise exception 'Solo el docente corrector/a asignado puede devolver este informe.'; end if;
  select max(version) into ver from public.informes where practica_id = p_id;
  if ver is null then raise exception 'No hay informe que devolver.'; end if;
  if exists (select 1 from public.evaluaciones where practica_id = p_id and rol = 'academico') then raise exception 'El informe ya fue evaluado.'; end if;
  if exists (select 1 from public.devoluciones where practica_id = p_id and not resuelta) then raise exception 'Ya hay observaciones pendientes.'; end if;
  if coalesce(trim(p_texto), '') = '' then raise exception 'Escribe las observaciones.'; end if;
  insert into public.devoluciones (practica_id, version, texto, por, fecha) values (p_id, ver, trim(p_texto), me.nombre, public._hoy());
  perform public._hist(p_id, 'Devolvió el informe con observaciones.');
end $$;

-- ---------- Acciones de la Dirección de Carrera ----------
create or replace function public._solo_dir() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public._es_dir() then raise exception 'Esta acción es solo para la Dirección de Carrera.'; end if;
end $$;

create or replace function public.aprobar_activacion(p_id uuid, p_nrc text, p_docente text) returns text
language plpgsql security definer set search_path = public as $$
declare v public.practicas; sup text; existente text; dn text;
begin
  perform public._solo_dir(); v := public._practica(p_id);
  if v.solicitud_fecha is null or v.activacion_fecha is not null then raise exception 'Esta práctica no está esperando activación.'; end if;
  if coalesce(trim(p_nrc), '') = '' then raise exception 'Ingresa el NRC.'; end if;
  select nombre into dn from public.personas where email = lower(p_docente) and rol = 'docente';
  if dn is null then raise exception 'El docente elegido no está registrado.'; end if;
  sup := lower(v.supervisor ->> 'correo');
  select rol into existente from public.personas where email = sup;
  if existente is not null and existente <> 'supervisor' then
    raise exception 'El correo del supervisor/a ya está registrado en la plataforma con otro perfil (%).', existente;
  end if;
  insert into public.personas (email, nombre, rol) values (sup, coalesce(v.supervisor ->> 'nombre', ''), 'supervisor')
  on conflict (email) do update set nombre = excluded.nombre;
  update public.practicas set nrc = trim(p_nrc), docente_email = lower(p_docente), activacion_fecha = public._hoy() where id = p_id;
  perform public._hist(p_id, format('Activó la práctica (NRC %s) con %s como docente corrector/a. Se envió acceso a %s.', trim(p_nrc), dn, v.supervisor ->> 'nombre'));
  return sup;
end $$;

create or replace function public.devolver_solicitud(p_id uuid, p_motivo text) returns void
language plpgsql security definer set search_path = public as $$
declare v public.practicas;
begin
  perform public._solo_dir(); v := public._practica(p_id);
  if v.solicitud_fecha is null or v.activacion_fecha is not null then raise exception 'Esta solicitud no se puede devolver.'; end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Escribe el motivo.'; end if;
  update public.practicas set solicitud_fecha = null, obs_solicitud = jsonb_build_object('fecha', public._hoy()::text, 'texto', trim(p_motivo)) where id = p_id;
  perform public._hist(p_id, 'Devolvió la solicitud: ' || trim(p_motivo));
end $$;

create or replace function public.registrar_seguro(p_id uuid, p_fecha date, p_folio text) returns void
language plpgsql security definer set search_path = public as $$
declare v public.practicas;
begin
  perform public._solo_dir(); v := public._practica(p_id);
  if v.activacion_fecha is null or v.seguro is not null then raise exception 'Esta práctica no está esperando seguro.'; end if;
  update public.practicas set seguro = jsonb_build_object('fecha', coalesce(p_fecha, public._hoy())::text, 'folio', trim(coalesce(p_folio, ''))) where id = p_id;
  perform public._hist(p_id, 'Registró el seguro de práctica' || case when coalesce(trim(p_folio), '') <> '' then ' (folio ' || trim(p_folio) || ')' else '' end || '.');
end $$;

create or replace function public.cambiar_docente(p_id uuid, p_docente text) returns void
language plpgsql security definer set search_path = public as $$
declare v public.practicas; dn text;
begin
  perform public._solo_dir(); v := public._practica(p_id);
  select nombre into dn from public.personas where email = lower(p_docente) and rol = 'docente';
  if dn is null then raise exception 'El docente elegido no está registrado.'; end if;
  update public.practicas set docente_email = lower(p_docente) where id = p_id;
  perform public._hist(p_id, format('Asignó a %s como docente corrector/a.', dn));
end $$;

create or replace function public.cerrar_practica(p_id uuid) returns numeric
language plpgsql security definer set search_path = public as $$
declare v public.practicas; ne numeric; na numeric; w jsonb; nf numeric;
begin
  perform public._solo_dir(); v := public._practica(p_id);
  if v.cierre is not null then raise exception 'La práctica ya está cerrada.'; end if;
  select nota into ne from public.evaluaciones where practica_id = p_id and rol = 'empresa';
  select nota into na from public.evaluaciones where practica_id = p_id and rol = 'academico';
  if ne is null or na is null then raise exception 'Faltan evaluaciones para cerrar.'; end if;
  select data -> 'ponderacion' -> v.tipo into w from public.config where id = 1;
  nf := round(ne * (w ->> 'empresa')::numeric / 100 + na * (w ->> 'academico')::numeric / 100, 1);
  update public.practicas set cierre = jsonb_build_object('fecha', public._hoy()::text, 'nota', nf) where id = p_id;
  perform public._hist(p_id, format('Cerró la práctica con nota final %s.', replace(nf::text, '.', ',')));
  return nf;
end $$;

create or replace function public.emitir_carta(p_carta uuid) returns void
language plpgsql security definer set search_path = public as $$
begin perform public._solo_dir(); perform public._emitir(p_carta); end $$;

create or replace function public.rechazar_carta(p_carta uuid, p_motivo text) returns void
language plpgsql security definer set search_path = public as $$
declare c public.cartas;
begin
  perform public._solo_dir();
  select * into c from public.cartas where id = p_carta;
  if c.id is null or c.estado <> 'solicitada' then raise exception 'La carta ya fue procesada.'; end if;
  if coalesce(trim(p_motivo), '') = '' then raise exception 'Escribe el motivo.'; end if;
  update public.cartas set estado = 'rechazada', motivo = trim(p_motivo) where id = p_carta;
  perform public._hist(c.practica_id, format('Rechazó la carta de presentación para %s: %s', coalesce(nullif(c.empresa, ''), 'uso general'), trim(p_motivo)));
end $$;

create or replace function public.nueva_carta(p_id uuid, p_empresa text, p_destinatario text, p_cargo text) returns void
language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  perform public._solo_dir(); perform public._practica(p_id);
  insert into public.cartas (practica_id, empresa, destinatario, cargo, fecha_solicitud)
  values (p_id, trim(coalesce(p_empresa, '')), trim(coalesce(p_destinatario, '')), trim(coalesce(p_cargo, '')), public._hoy())
  returning id into cid;
  perform public._emitir(cid);
end $$;

create or replace function public.reenviar_acceso(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v public.practicas;
begin
  perform public._solo_dir(); v := public._practica(p_id);
  if v.activacion_fecha is null then raise exception 'La práctica aún no está activada.'; end if;
  perform public._hist(p_id, format('Reenvió el acceso a la plataforma a %s.', v.supervisor ->> 'correo'));
  return lower(v.supervisor ->> 'correo');
end $$;

create or replace function public.guardar_config(p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare seq jsonb;
begin
  perform public._solo_dir();
  select data #> '{carta,seq}' into seq from public.config where id = 1;
  update public.config set data = jsonb_set(p_data, '{carta,seq}', coalesce(seq, '0'::jsonb)) where id = 1;
end $$;

-- Carga de personas: [{email, nombre, rol, rut, malla, nivel, telefono, tipo, periodo}]
create or replace function public.agregar_personas(p_lista jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare x jsonb; em text; r text; np int := 0; npr int := 0;
begin
  perform public._solo_dir();
  for x in select * from jsonb_array_elements(p_lista) loop
    em := lower(trim(x ->> 'email')); r := x ->> 'rol';
    if em is null or em !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Correo no válido: %', coalesce(x ->> 'email', '(vacío)'); end if;
    if r not in ('direccion', 'docente', 'estudiante') then raise exception 'Perfil no válido para %', em; end if;
    insert into public.personas (email, nombre, rol, rut, malla, nivel, telefono)
    values (em, trim(coalesce(x ->> 'nombre', '')), r, trim(coalesce(x ->> 'rut', '')), coalesce(nullif(x ->> 'malla', ''), '2024'),
            coalesce(nullif(x ->> 'nivel', '')::int, 0), trim(coalesce(x ->> 'telefono', '')))
    on conflict (email) do update set
      nombre = coalesce(nullif(excluded.nombre, ''), personas.nombre), rol = excluded.rol,
      rut = coalesce(nullif(excluded.rut, ''), personas.rut), malla = excluded.malla,
      nivel = case when excluded.nivel > 0 then excluded.nivel else personas.nivel end,
      telefono = coalesce(nullif(excluded.telefono, ''), personas.telefono);
    np := np + 1;
    if r = 'estudiante' and coalesce(x ->> 'tipo', '') in ('industrial', 'profesional')
       and not exists (select 1 from public.practicas p where p.estudiante_email = em and p.tipo = x ->> 'tipo' and p.cierre is null) then
      insert into public.practicas (estudiante_email, tipo, periodo) values (em, x ->> 'tipo', trim(coalesce(x ->> 'periodo', '')));
      npr := npr + 1;
    end if;
  end loop;
  return jsonb_build_object('personas', np, 'practicas', npr);
end $$;

create or replace function public.eliminar_practica(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v public.practicas;
begin
  perform public._solo_dir(); v := public._practica(p_id);
  if v.activacion_fecha is not null then raise exception 'Solo se pueden eliminar prácticas que aún no están activadas.'; end if;
  delete from public.practicas where id = p_id;
end $$;

-- ---------- Permisos de ejecución ----------
revoke execute on all functions in schema public from public, anon;
revoke execute on function public._yo(), public._practica(uuid), public._hist(uuid, text), public._eval_json(uuid, text, text, boolean),
  public._practica_json(public.practicas, text), public._emitir(uuid), public._solo_dir() from authenticated;
grant execute on function public.estado(), public.guardar_borrador(uuid, jsonb), public.enviar_solicitud(uuid),
  public.pedir_carta(uuid, text, text, text), public.registrar_informe(uuid, text, bigint, text),
  public.evaluar_empresa(uuid, jsonb, jsonb), public.registrar_doc_empresa(uuid, text, bigint, text),
  public.evaluar_academico(uuid, jsonb, text), public.devolver_informe(uuid, text),
  public.aprobar_activacion(uuid, text, text), public.devolver_solicitud(uuid, text), public.registrar_seguro(uuid, date, text),
  public.cambiar_docente(uuid, text), public.cerrar_practica(uuid), public.emitir_carta(uuid), public.rechazar_carta(uuid, text),
  public.nueva_carta(uuid, text, text, text), public.reenviar_acceso(uuid), public.guardar_config(jsonb),
  public.agregar_personas(jsonb), public.eliminar_practica(uuid), public.calc_nota(jsonb, jsonb, numeric),
  public._hoy(), public._email(), public._es_dir(), public._puede_ver(public.practicas) to authenticated;

-- ---------- Archivos (informes y documentos de empresa) ----------
create or replace function public._puede_ver_carpeta(f text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.practicas p where p.id::text = f and public._puede_ver(p))
$$;
create or replace function public._puede_subir_carpeta(f text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.practicas p where p.id::text = f and (
    public._es_dir()
    or (p.estudiante_email = public._email() and p.seguro is not null and p.cierre is null)
    or (p.activacion_fecha is not null and lower(p.supervisor ->> 'correo') = public._email())))
$$;
grant execute on function public._puede_ver_carpeta(text), public._puede_subir_carpeta(text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('archivos', 'archivos', false, 20971520,
        array['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do nothing;

drop policy if exists "practicas_leer_archivos" on storage.objects;
create policy "practicas_leer_archivos" on storage.objects for select to authenticated
  using (bucket_id = 'archivos' and public._puede_ver_carpeta((storage.foldername(name))[1]));
drop policy if exists "practicas_subir_archivos" on storage.objects;
create policy "practicas_subir_archivos" on storage.objects for insert to authenticated
  with check (bucket_id = 'archivos' and public._puede_subir_carpeta((storage.foldername(name))[1]));

-- ---------- Primera persona de la Dirección de Carrera ----------
-- Reemplaza el correo y el nombre antes de ejecutar. Con ese correo entrarás a la plataforma.
insert into public.personas (email, nombre, rol)
values (lower('__DIRECTOR_EMAIL__'), '__DIRECTOR_NOMBRE__', 'direccion')
on conflict (email) do update set rol = 'direccion', nombre = excluded.nombre;
