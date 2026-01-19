/*
SUMATIVA BASES DE DATOS – ORACLE CLOUD
Alumno: Bastian Fuentes
Bloque: PROY_MOVILIZACION
Descripción:
- Calcula movilización por año de proceso
- Usa tramos de antigüedad
- Inserta resultados finales
- Controla errores y transacciones
*/

SET SERVEROUTPUT ON;

DECLARE
  v_fecha_proceso     DATE := SYSDATE;

  v_total_empleados   NUMBER := 0;
  v_insertados        NUMBER := 0;

  v_anno_proceso      NUMBER(4);
  v_anios_trab        NUMBER(4);
  v_porc_movil_normal NUMBER(6);
  v_val_movil_normal  NUMBER(12);
  v_val_movil_extra   NUMBER(12);
  v_val_total_movil   NUMBER(12);

  v_nombre_empleado   VARCHAR2(60);
  v_nombre_comuna     VARCHAR2(60);

BEGIN
  DBMS_OUTPUT.PUT_LINE('==========================');
  DBMS_OUTPUT.PUT_LINE('INICIO PROY_MOVILIZACION');
  DBMS_OUTPUT.PUT_LINE('Fecha proceso (LOCAL): '||TO_CHAR(v_fecha_proceso,'DD-MM-YYYY HH24:MI:SS'));
  DBMS_OUTPUT.PUT_LINE('==========================');

  -- Limpieza para poder ejecutar varias veces sin mezclar resultados
  EXECUTE IMMEDIATE 'TRUNCATE TABLE PROY_MOVILIZACION';

  v_anno_proceso := EXTRACT(YEAR FROM v_fecha_proceso);

  SELECT COUNT(*) INTO v_total_empleados
  FROM empleado;

  DBMS_OUTPUT.PUT_LINE('Año proceso: '||v_anno_proceso);
  DBMS_OUTPUT.PUT_LINE('Total empleados: '||v_total_empleados);

  FOR r IN (
    SELECT e.id_emp, e.numrun_emp, e.dvrun_emp,
           e.pnombre_emp, e.snombre_emp,
           e.appaterno_emp, e.apmaterno_emp,
           e.sueldo_base, e.fecha_contrato, e.id_comuna
      FROM empleado e
     ORDER BY e.id_emp
  ) LOOP

    -- Nombre empleado
    v_nombre_empleado :=
      TRIM(r.pnombre_emp || ' ' || NVL(r.snombre_emp,'') || ' ' ||
           r.appaterno_emp || ' ' || r.apmaterno_emp);

    -- Nombre comuna
    SELECT c.nombre_comuna
      INTO v_nombre_comuna
      FROM comuna c
     WHERE c.id_comuna = r.id_comuna;

    -- Años trabajados (entero)
    v_anios_trab := FLOOR(MONTHS_BETWEEN(v_fecha_proceso, r.fecha_contrato)/12);

    -- Porcentaje según tramo
    BEGIN
      SELECT t.porcentaje
        INTO v_porc_movil_normal
        FROM tramo_antiguedad t
       WHERE t.anno_vig = v_anno_proceso
         AND v_anios_trab BETWEEN t.tramo_inf AND t.tramo_sup;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_porc_movil_normal := 0;
    END;

    -- Cálculos (evita error de conversión)
    v_val_movil_normal := ROUND( NVL(r.sueldo_base,0) * (NVL(v_porc_movil_normal,0)/100), 0 );
    v_val_movil_extra  := 0;
    v_val_total_movil  := v_val_movil_normal + v_val_movil_extra;

    INSERT INTO proy_movilizacion
      (anno_proceso, id_emp, numrun_emp, dvrun_emp,
       nombre_empleado, nombre_comuna, sueldo_base,
       porc_movil_normal, valor_movil_normal,
       valor_movil_extra, valor_total_movil)
    VALUES
      (v_anno_proceso, r.id_emp, r.numrun_emp, r.dvrun_emp,
       v_nombre_empleado, v_nombre_comuna, r.sueldo_base,
       v_porc_movil_normal, v_val_movil_normal,
       v_val_movil_extra, v_val_total_movil);

    v_insertados := v_insertados + 1;
  END LOOP;

  IF v_insertados = v_total_empleados THEN
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('? OK: Insertados '||v_insertados||' de '||v_total_empleados||'. COMMIT realizado.');
  ELSE
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('? ERROR: Insertados '||v_insertados||' de '||v_total_empleados||'. ROLLBACK aplicado.');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('? EXCEPTION: '||SQLERRM);
    DBMS_OUTPUT.PUT_LINE('Se aplicó ROLLBACK por seguridad.');
END;
/

SELECT COUNT(*) AS empleados FROM empleado;
SELECT COUNT(*) AS filas_proy FROM proy_movilizacion;

SELECT anno_proceso, id_emp, nombre_empleado, nombre_comuna,
       sueldo_base, porc_movil_normal, valor_total_movil
FROM proy_movilizacion
ORDER BY id_emp;
