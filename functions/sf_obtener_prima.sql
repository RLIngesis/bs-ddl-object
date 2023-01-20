create or replace FUNCTION          "SF_OBTENER_PRIMA" (as_poliza        IN VARCHAR2,
                                                                                     as_serie         IN VARCHAR2,
                                                                                     as_certificado   IN VARCHAR2,
                                                                                     an_mesesCalculaEdad  IN NUMBER)
  RETURN NUMBER
IS                 
  ll_plan                     NUMBER;
  ll_plan_pago                NUMBER;
  ls_producto                 VARCHAR2 (50);
  ld_valor_asegurado          NUMBER;
  ln_actualizaTarifaPorEdad   NUMBER (2);
  ld_fecha_emision            DATE;
  ld_fecha_nacimiento         DATE;
  ld_fechaInicioVigCert       DATE;
  ld_prima                    NUMBER (14, 2) := 0;
  ld_prima_tmp                NUMBER (14, 2) := 0;
  ld_tasa_tmp                 NUMBER (14, 8) := 0;
  ln_meses                    NUMBER (10);
  ls_indGeneraRecAnual        VARCHAR2 (3);
  ls_lov_datos_particulares   VARCHAR2 (50);
  ls_indica_prestatario       PRODUCTO.IND_PRESTATARIO%TYPE;
  cur_coberturaRamo           SYS_REFCURSOR;
  recordCoberturaRamo         cobertura_x_ramo%ROWTYPE;
  /******************************************************************************
     NAME:       SF_OBTENER_PRIMA
     PURPOSE:    obtencion de prima para asegurado para productos prestatarios y no prestatarios

     REVISIONS:
     Ver        Date        Author           Description
     ---------  ----------  ---------------  ------------------------------------
     1.0        1/12/2015   LuisMiguel       1. Created this function.

     NOTES:

     Automatically available Auto Replace Keywords:
        Object Name:     SF_OBTENER_PRIMA
        Sysdate:         1/12/2015
        Date and Time:   1/12/2015, 10:47:54 a. m., and 1/12/2015 10:47:54 a. m.
        Username:        LuisMiguel (set in TOAD Options, Procedure Editor)
        Table Name:       (set in the New PL/SQL Object dialog)

        CODIGOS RESPUESTAS
        -1000 No se encontro informacion del certificado
        -2000 No se encontro informacion en tarifa
        -3000 No se pudo calcular tarifa para prestatario

  ******************************************************************************/
  BEGIN
    BEGIN
      SELECT 
        certificado.prima_certificado,
        certificado.producto,
        certificado.plan,
        NVL (certificado.valor_asegurado, 0) AS valor_asegurado,
        certificado.plan_pago,
        TRUNC(certificado.fechaemision),
        TRUNC(entidad.fechanacimiento),
        nvl(producto.actualiza_tarfifa_x_edad,0),
        NVL (ind_prestatario, 'N'),
        plan_pago.meses,
        NVL(producto.ind_genera_rec_anual,'N'),
        TRUNC(certificado.fechaInicioVigencia),
        tipo_producto.lov_datos_particulares

      INTO 
        ld_prima,
        ls_producto,
        ll_plan,
        ld_valor_asegurado,
        ll_plan_pago,
        ld_fecha_emision,
        ld_fecha_nacimiento,
        ln_actualizaTarifaPorEdad,
        ls_indica_prestatario,
        ln_meses,
        ls_indGeneraRecAnual,
        ld_fechaInicioVigCert,
        ls_lov_datos_particulares
      FROM certificado, plan_pago, entidad,producto, tipo_producto
      WHERE     (certificado.certificado = as_certificado)
                AND (certificado.serie = as_serie)
                AND (certificado.poliza = as_poliza)
                AND (plan_pago.plan_pago = certificado.plan_pago)
                AND (entidad.entidad = certificado.entidad)
                and (certificado.producto=producto.producto)
                AND (producto.tipo_producto=tipo_producto.tipo_producto);


      EXCEPTION
      WHEN NO_DATA_FOUND THEN
      LD_PRIMA:=-1000;
      --raise_application_error (-20100,'No se encontro informacion del certificado '|| as_serie|| '-'|| as_certificado|| ' poliza '|| as_poliza);
    END;


    IF (ls_indica_prestatario = 'N')
    THEN
      BEGIN
        SELECT VERSION.PRIMA
        INTO LD_PRIMA
        FROM VERSION
        WHERE     (VERSION.PLAN = LL_PLAN)
                  AND (VERSION.PLAN_PAGO = LL_PLAN_PAGO)
                  AND (VERSION.PRODUCTO = LS_PRODUCTO)
                  AND (VERSION.POLIZA = AS_POLIZA)
                  AND (VERSION.SUMA_ASEGURADA_MINIMA <= LD_VALOR_ASEGURADO)
                  AND (VERSION.SUMA_ASEGURADA_MAXIMA >= LD_VALOR_ASEGURADO)
                  --AND (VERSION.EDAD_MINIMA <=TRUNC (MONTHS_BETWEEN (DECODE (ls_actualizaTarifaPorEdad,1, SYSDATE,ld_fecha_emision),ld_fecha_nacimiento)/ 12))
                  AND (VERSION.EDAD_MINIMA <= PQ_TRASLADARCERT_SALV.edadActuarial(ld_fecha_nacimiento,DECODE(ln_actualizaTarifaPorEdad,1,SYSDATE,DECODE(nvl(ls_indGeneraRecAnual,'N'),'S',ld_fechaInicioVigCert,ld_fecha_emision)),an_mesesCalculaEdad))
                  AND (VERSION.EDAD_MAXIMA >= PQ_TRASLADARCERT_SALV.edadActuarial(ld_fecha_nacimiento,DECODE(ln_actualizaTarifaPorEdad,1,SYSDATE,DECODE(nvl(ls_indGeneraRecAnual,'N'),'S',ld_fechaInicioVigCert,ld_fecha_emision)),an_mesesCalculaEdad))
                  --AND (VERSION.EDAD_MAXIMA >=TRUNC (MONTHS_BETWEEN (DECODE (ln_actualizaTarifaPorEdad,1, SYSDATE,ld_fecha_emision),ld_fecha_nacimiento) / 12))
                  AND (VERSION.ESTADO = '1');
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
        --raise_application_error (-20100,'No se encontro informacion en tarifa para Plan: '|| LL_PLAN|| ' PlanP:'|| ll_plan_pago);
        LD_PRIMA:=-2000;
      END;
    ELSIF (ls_lov_datos_particulares = 'dtSaldoDeudor')THEN
        RETURN ld_prima;
    ELSE
      --PRESTATARIO
      BEGIN
        OPEN cur_coberturaRamo FOR
        --SELECT cr.prima
        SELECT cr.*
        FROM cobertura_x_ramo cr
        WHERE cr.producto = LS_PRODUCTO AND cr.plan = LL_PLAN;

        LOOP
          FETCH cur_coberturaRamo INTO recordCoberturaRamo;

          EXIT WHEN cur_coberturaRamo%NOTFOUND;

          ld_prima_tmp := 0;
          ld_tasa_tmp := 0;

          IF (recordCoberturaRamo.tasa IS NOT NULL AND recordCoberturaRamo.tasa > 0) THEN
            IF (recordCoberturaRamo.IND_PORC_TARIFICA = 'C') THEN
              ld_tasa_tmp := recordCoberturaRamo.tasa / 100;

            ELSIF (recordCoberturaRamo.IND_PORC_TARIFICA = 'M')THEN
              ld_tasa_tmp := recordCoberturaRamo.tasa / 1000;
            END IF;

            ld_prima_tmp := (ld_valor_asegurado * ld_tasa_tmp)/ll_plan_pago;
          ELSE
            --se tomara como default prima
            IF (recordCoberturaRamo.prima IS NOT NULL) THEN
              ld_prima_tmp := ld_prima_tmp + (recordCoberturaRamo.prima * ln_meses);
            END IF;
          END IF;

          ld_prima := ld_prima + ld_prima_tmp;
        END LOOP;

        CLOSE cur_coberturaRamo;
        EXCEPTION
        WHEN OTHERS THEN
        --raise_application_error (-20100,'No se pudo calcular tarifa para prestatario, para Producto: '|| LS_PRODUCTO|| ' Plan:'|| LL_PLAN);
        LD_PRIMA:=-3000;
      END;
    END IF;

    RETURN ld_prima;
    EXCEPTION
    WHEN OTHERS THEN
    --RAISE_APPLICATION_ERROR (-20100,'Error al Obtener la Prima: ' || SQLERRM);
    RETURN ld_prima;

  END SF_OBTENER_PRIMA;