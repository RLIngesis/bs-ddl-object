create or replace FUNCTION          "SF_PROCESO" 
  ( as_tabla IN varchar2,
     as_tipo IN varchar2,
     as_parametros IN varchar2,
     as_usuario IN varchar2)
 RETURN  numeric IS

al_siguiente_proceso numeric(10);
ls_usuario varchar2(80);
BEGIN 

    SELECT SQ_IDEPROC.NEXTVAL
 INTO al_siguiente_proceso
 FROM SYS.DUAL;

    LS_USUARIO := as_usuario;

  INSERT INTO PROCESO  
         ( IDEPROC,   
           TABLA,   
           TIPOPROC,   
           USUARIO,   
           FECSTS,   
           PARAMETROS )  
  VALUES ( al_siguiente_proceso,   
           as_tabla,   
           as_tipo,   
           ls_usuario,   
           sysdate,   
           as_parametros )  ;

    RETURN al_siguiente_proceso;
END; -- Function SF_PROCESO