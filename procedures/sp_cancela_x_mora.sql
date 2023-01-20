create or replace PROCEDURE          "SP_CANCELA_MOROSOS" (as_poliza IN varchar2, as_fecha IN varchar2, as_usuario IN varchar2)
   IS

   cursor q_cancela_certificados is
   select cer.producto, mov.poliza, mov.serie, mov.certificado, pro.periodogracia, pro.maxdiamora, min(fecha_inicio_vigencia)
      
    from producto pro, poliza pol, certificado cer, movimiento mov
    where pol.producto = cer.producto
      and pol.poliza = cer.poliza
      and pro.producto = pol.producto
      and cer.poliza = mov.poliza
      and cer.serie = mov.serie
      and cer.certificado = mov.certificado
      and mov.stsmov = 'PEN'
      and cer.stsCer = 'ACT'    
      and cer.poliza = as_poliza
            
    group by cer.producto, mov.poliza, mov.serie, mov.certificado, pro.periodogracia, pro.maxdiamora
    having trunc((to_date(as_fecha,'DD-MM-YYYY') - min(fecha_inicio_vigencia)),0) > pro.maxdiamora;

    ll_ideproc numeric(8);
    ls_descriPoliza varchar2(200);

BEGIN
    ls_descriPoliza := '';

    select pol.descripcion
      into ls_descriPoliza
      from POLIZA pol
     where pol.poliza = as_poliza;

    ll_ideproc := sf_proceso('Certificado','CM','poliza:'||as_poliza||'-'||ls_descriPoliza||',al: '||as_fecha, as_usuario);

    for loop_certificados in q_cancela_certificados loop
       pq_archivo_traslado.p_eliminarRecibosBolson(loop_certificados.poliza,loop_certificados.serie,loop_certificados.certificado, null);
       PQ_CERTIFICADO.anularCertificadoPorEstado(loop_certificados.poliza,loop_certificados.serie,loop_certificados.certificado,'9',null,to_date(as_fecha,'DD-MM-YYYY'),as_usuario);      
    end loop;
END;