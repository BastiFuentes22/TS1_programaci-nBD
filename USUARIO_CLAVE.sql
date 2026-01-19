/*
SUMATIVA BASES DE DATOS – ORACLE CLOUD
Alumno: Bastian Fuentes
Bloque: USUARIO_CLAVE
Descripción:
- Limpia tabla destino
- Genera usuario y clave por empleado
- Controla commit y rollback
*/


DEFINE FECHA_PROCESO = SYSDATE
SET SERVEROUTPUT ON;

DECLARE
  /* =============================
     PARAMETRO DE PROCESO (evita fechas fijas)
     ============================= */
  v_fecha_proceso   DATE := &FECHA_PROCESO;
  v_mmYYYY          VARCHAR2(6) := TO_CHAR(&FECHA_PROCESO,'MMYYYY');

  /* =============================
     Variables de control
     ============================= */
  v_total_empleados NUMBER := 0;
  v_insertados      NUMBER := 0;

  /* =============================
     %TYPE (cumple mínimo 3)
     ============================= */
  v_id_emp          EMPLEADO.ID_EMP%TYPE;
  v_numrun          EMPLEADO.NUMRUN_EMP%TYPE;
  v_dvrun           EMPLEADO.DVRUN_EMP%TYPE;
  v_appaterno       EMPLEADO.APPATERNO_EMP%TYPE;
  v_apmaterno       EMPLEADO.APMATERNO_EMP%TYPE;
  v_pnombre         EMPLEADO.PNOMBRE_EMP%TYPE;
  v_snombre         EMPLEADO.SNOMBRE_EMP%TYPE;
  v_sueldo          EMPLEADO.SUELDO_BASE%TYPE;
  v_fec_nac         EMPLEADO.FECHA_NAC%TYPE;
  v_fec_contrato    EMPLEADO.FECHA_CONTRATO%TYPE;
  v_id_ecivil       EMPLEADO.ID_ESTADO_CIVIL%TYPE;

  /* =============================
     Variables de cálculo (PL/SQL)
     ============================= */
  v_anios_trab      NUMBER;
  v_run_txt         VARCHAR2(20);
  v_tercer_dig_run  VARCHAR2(1);
  v_anio_nac_mas2   NUMBER;
  v_ult3_sueldo_m1  NUMBER;
  v_ult3_sueldo_txt VARCHAR2(3);

  v_estado_nombre   VARCHAR2(30);
  v_estado_letra    VARCHAR2(1);
  v_2letras_ap      VARCHAR2(2);

  v_nombre_empleado VARCHAR2(60);
  v_nombre_usuario  VARCHAR2(20);
  v_clave_usuario   VARCHAR2(20);

BEGIN
  /* =============================
     SQL DOCUMENTADA #1 (Dynamic SQL)
     Truncar tabla destino para permitir re-ejecución
     ============================= */
  EXECUTE IMMEDIATE 'TRUNCATE TABLE USUARIO_CLAVE';

  /* =============================
     SQL DOCUMENTADA #2
     Contar empleados a procesar (validación para COMMIT)
     ============================= */
  SELECT COUNT(*) INTO v_total_empleados
  FROM EMPLEADO;

  DBMS_OUTPUT.PUT_LINE('Fecha proceso: ' || TO_CHAR(v_fecha_proceso,'DD-MM-YYYY HH24:MI:SS'));
  DBMS_OUTPUT.PUT_LINE('MMYYYY clave: ' || v_mmYYYY);
  DBMS_OUTPUT.PUT_LINE('Total empleados: ' || v_total_empleados);

  /* =============================
     Iteración: procesar TODOS los empleados
     (orden ascendente por ID_EMP)
     ============================= */
  FOR r IN (
    SELECT
      id_emp, numrun_emp, dvrun_emp, appaterno_emp, apmaterno_emp,
      pnombre_emp, snombre_emp, sueldo_base, fecha_nac, fecha_contrato, id_estado_civil
    FROM empleado
    ORDER BY id_emp
  ) LOOP

    /* PL/SQL DOCUMENTADA #1:
       Copio a variables %TYPE para trabajar ordenado */
    v_id_emp       := r.id_emp;
    v_numrun       := r.numrun_emp;
    v_dvrun        := r.dvrun_emp;
    v_appaterno    := r.appaterno_emp;
    v_apmaterno    := r.apmaterno_emp;
    v_pnombre      := r.pnombre_emp;
    v_snombre      := r.snombre_emp;
    v_sueldo       := r.sueldo_base;
    v_fec_nac      := r.fecha_nac;
    v_fec_contrato := r.fecha_contrato;
    v_id_ecivil    := r.id_estado_civil;

    /* =============================
       SQL DOCUMENTADA #3
       Traer nombre estado civil (solo lookup)
       ============================= */
    SELECT nombre_estado_civil
      INTO v_estado_nombre
      FROM estado_civil
     WHERE id_estado_civil = v_id_ecivil;

    /* =============================
       Cálculos PL/SQL (no en SQL)
       ============================= */

    -- Nombre completo (formato ApPaterno ApMaterno, PNombre SNombre)
    v_nombre_empleado :=
      TRIM(
        v_appaterno || ' ' || v_apmaterno || ', ' || v_pnombre ||
        CASE WHEN v_snombre IS NOT NULL THEN ' '|| v_snombre ELSE '' END
      );

    -- Años trabajando (redondeado a entero hacia abajo)
    v_anios_trab := TRUNC(MONTHS_BETWEEN(v_fecha_proceso, v_fec_contrato)/12);

    -- RUN a texto (NUMRUN ya es número)
    v_run_txt := TO_CHAR(v_numrun);

    -- Tercer dígito del RUN
    v_tercer_dig_run := SUBSTR(v_run_txt, 3, 1);

    -- Año nacimiento + 2
    v_anio_nac_mas2 := TO_NUMBER(TO_CHAR(v_fec_nac,'YYYY')) + 2;

    -- Últimos 3 dígitos sueldo - 1 (con ceros a la izquierda)
    v_ult3_sueldo_m1  := MOD(TRUNC(v_sueldo), 1000) - 1;
    v_ult3_sueldo_txt := LPAD(TO_CHAR(v_ult3_sueldo_m1), 3, '0');

    /* =============================
       Estado civil: letra + regla de apellido (minúscula)
       ============================= */
    v_estado_letra := LOWER(SUBSTR(TRIM(v_estado_nombre),1,1));

    IF UPPER(v_estado_nombre) LIKE '%CASAD%' OR UPPER(v_estado_nombre) LIKE '%UNION%' THEN
      -- Casado o Unión civil: 2 primeras letras
      v_2letras_ap := LOWER(SUBSTR(v_appaterno,1,2));

    ELSIF UPPER(v_estado_nombre) LIKE '%DIVOR%' OR UPPER(v_estado_nombre) LIKE '%SOLTER%' THEN
      -- Divorciado o Soltero: primera y última
      v_2letras_ap := LOWER(SUBSTR(v_appaterno,1,1) || SUBSTR(v_appaterno,-1,1));

    ELSIF UPPER(v_estado_nombre) LIKE '%VIUD%' THEN
      -- Viudo: antepenúltima y penúltima
      v_2letras_ap := LOWER(SUBSTR(v_appaterno,-3,1) || SUBSTR(v_appaterno,-2,1));

    ELSIF UPPER(v_estado_nombre) LIKE '%SEPAR%' THEN
      -- Separado: dos últimas
      v_2letras_ap := LOWER(SUBSTR(v_appaterno,-2,2));

    ELSE
      -- Respaldo por si viene un texto distinto
      v_2letras_ap := LOWER(SUBSTR(v_appaterno,1,2));
    END IF;

    /* =============================
       NOMBRE_USUARIO (según pauta)
       ============================= */
    v_nombre_usuario :=
        v_estado_letra
      || LOWER(SUBSTR(v_pnombre,1,3))
      || LENGTH(v_pnombre)
      || '*'
      || SUBSTR(TO_CHAR(TRUNC(v_sueldo)),-1,1)
      || v_dvrun
      || v_anios_trab
      || CASE WHEN v_anios_trab < 10 THEN 'X' ELSE '' END;

    /* =============================
       CLAVE_USUARIO (según pauta)
       ============================= */
    v_clave_usuario :=
        v_tercer_dig_run
      || TO_CHAR(v_anio_nac_mas2)
      || v_ult3_sueldo_txt
      || v_2letras_ap
      || TO_CHAR(v_id_emp)
      || v_mmYYYY;

    /* =============================
       SQL DOCUMENTADA #4
       Insert en USUARIO_CLAVE
       ============================= */
    INSERT INTO usuario_clave
      (id_emp, numrun_emp, dvrun_emp, nombre_empleado, nombre_usuario, clave_usuario)
    VALUES
      (v_id_emp, v_numrun, v_dvrun, v_nombre_empleado, v_nombre_usuario, v_clave_usuario);

    v_insertados := v_insertados + 1;

  END LOOP;

  /* =============================
     Confirmación final: COMMIT solo si procesó todo
     ============================= */
  IF v_insertados = v_total_empleados THEN
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('OK: Insertados '||v_insertados||' de '||v_total_empleados||'. COMMIT realizado.');
  ELSE
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR: Insertados '||v_insertados||' de '||v_total_empleados||'. ROLLBACK aplicado.');
  END IF;

END;
/

SELECT COUNT(*) AS empleados FROM EMPLEADO;
SELECT COUNT(*) AS generados FROM USUARIO_CLAVE;

SELECT id_emp, nombre_usuario, clave_usuario
FROM usuario_clave
ORDER BY id_emp;
