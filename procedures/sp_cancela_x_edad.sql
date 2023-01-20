create or replace PROCEDURE          "SP_CANCELA_X_EDAD" (as_poliza varchar2, as_fecha varchar2, as_usuario varchar2)
IS

  cursor q_cancela_certificados is
   SELECT cert.certificado,
          cert.serie,
          cert.producto,
          cert.fechaInicioCobro,
          cert.poliza,
          prod.edad_vencimiento,
          enti.fechaNacimiento,
          pol.descripcion

     FROM CERTIFICADO cert, PRODUCTO prod, POLIZA pol, ENTIDAD enti

  WHERE pol.producto = cert.producto
     AND pol.poliza = cert.poliza
     AND prod.producto =  pol.producto
     AND enti.entidad = cert.entidad
     AND cert.stsCer = 'ACT'
     AND cert.poliza = as_poliza
     AND pq_trasladarcert_salv.edadActuarial(enti.fechaNacimiento, to_date(as_fecha,'dd/mm/yyyy'), 0) >= prod.edad_vencimiento

  ORDER BY cert.fechaInicioCobro, cert.serie, cert.certificado, cert.poliza;

    ll_mora numeric(3);
    ld_fecha_nacimiento date;
    ld_hoy date;
    ll_edad numeric(3);
    ll_ideproc numeric(14);
    ls_descriPoliza varchar2(200);
BEGIN
    ls_descriPoliza := '';

    SELECT pol.descripcion
      INTO ls_descriPoliza
      FROM POLIZA pol
     WHERE pol.poliza = as_poliza;

    ll_ideproc := sf_proceso('Certificado','CE','poliza:'||as_poliza||'-'||ls_descriPoliza||',Al: '||as_fecha,as_usuario);

    for loop_certificados in q_cancela_certificados loop
        pq_archivo_traslado.p_eliminarRecibosBolson(loop_certificados.poliza,loop_certificados.serie,loop_certificados.certificado, null);
        PQ_CERTIFICADO.anularCertificadoPorEstado(loop_certificados.poliza,loop_certificados.serie,loop_certificados.certificado,'6',null,to_date(as_fecha,'dd/mm/yyyy'),as_usuario);
    end loop;
exception when others then
    raise_application_error(-20100,'CancelaXEdad: '||sqlerrm);
END;