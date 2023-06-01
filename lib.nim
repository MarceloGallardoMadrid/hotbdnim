import os
import options
import std/db_sqlite
import sequtils
import parseutils
import tables
import std/oids
import json
type TIPOSQLITE3 = enum
    INTEGER="INTEGER",REAL="REAL",TEXT="TEXT",BLOB="BLOB"
type COMANDOS = enum
    NEW="new",EDIT="edit",DEL="del",TABLACOM="tabla"
type COMANDOSTABLA = enum
    ADD="add",MOD="mod",REM="rem",ALL="getall",GETONE="getone",FIELDS="fields"
type Campo* = object
    nombre* : string
    tipo : string
type Tabla* = object
    nombre* : string
    campos* : seq[Campo] 
type Config = object
    tablas : seq[Tabla]
type Mensaje = object
    codigo : int
    msg : string
type EditTabla = object
    # No se puede cambiar el nombre de la tabla
    nombre : Option[string]
    nuevos : Option[seq[Campo]]
    eliminar : Option[seq[string]]
    cambiarnombre: Option[seq[seq[string]]]
    #Se borra la columna anterior y se crea una nueva con un nuevo tipo
    cambiartipo: Option[seq[Campo]]
type AgregarCampo = object
    nombre : string
    valor : string
type AgregarFila = object
    valores : seq[AgregarCampo]
type DBResponse[T] = object
    meta : string
    data : T
proc newDBResponse[T](meta:string, data: T):DBResponse[T]=
    DBResponse[T](meta:meta,data:data)
proc `==`(t1:Tabla,t2:Tabla):bool=
    return t1.nombre == t2.nombre
proc `==`(c1:Campo,c2:Campo):bool=
    return c1.nombre == c2.nombre
proc print(c:Campo):string=
    var s = "\t\tnombre: " & c.nombre
    s &= "\ttipo: " & $c.tipo
    s
proc print*(t:Tabla):string=
    var s = "\tnombre: " & t.nombre
    s &= "\n"
    for c in t.campos:
        s &= c.print()
    
        s &= "\n"
    s
proc print(c:Config):string=
    var s ="archivo: data.sqlite" 
    s &= "\n"
    for t in c.tablas:
        s &= t.print()
        s &= "\n"
    s
proc print*(m:Mensaje):string=
    " codigo: " & $m.codigo & " , msg: " & m.msg
# Primera solucion leer config y escribir config en cada entrada
proc getconfig():Config=
    let db = open("data.sqlite","","","")
    var config_str=db.getValue(sql"SELECT config FROM Config WHERE id = ?",1)
    #echo config_str
    db.close()
    let jsonObject = parseJson(config_str)
    #let x:string = 3
    return to(jsonObject, Config)
proc setconfig(config:Config)=
    let db = open("data.sqlite","","","")
    let consig_str:string = $(%*config)
    db.exec(sql "UPDATE Config SET config='" & consig_str & "' WHERE id=1" )
    db.close()
proc newMensaje(cod:int,msg:string):Mensaje=
    Mensaje(codigo:cod,msg:msg)
proc newtabla*(tabla:Tabla):Mensaje=
    var config = getconfig()
    for t in config.tablas:
        if t.nombre == tabla.nombre:
            var m = Mensaje( codigo : -1 , msg : "ya existe esa tabla")
            return m
    var campos_map=initTable[string,int]()
    var sqlcode = "CREATE TABLE " & tabla.nombre & "(id string,"
    var i=0
    for c in tabla.campos:
        if campos_map.hasKey(c.nombre):
            var m = Mensaje(codigo : -2 , msg : "Hay campos repetidos")
            return m
        let ix_t = @["text","real","integer","blob"].find(c.tipo)
        if ix_t == -1:
            var m = Mensaje(codigo : -3 , msg : "Hay un tipo de campo que no existe")

            return m
        sqlcode &= c.nombre & " " & c.tipo
        if i != tabla.campos.len-1:
            sqlcode &= " , "
        i += 1
        campos_map[c.nombre]=0
    sqlcode &= " )"
    var new_tabla=tabla
    new_tabla.campos.add(Campo(nombre:"id",tipo:"text"))
    config.tablas.add(new_tabla)
    setconfig(config)
    let db = open("data.sqlite","","","")
    #echo sqlcode
    db.exec(sql sqlcode )
    db.close()
    return Mensaje(codigo:1 , msg : "Se pudo guardar la tabla")

proc deletetabla*(tablan:string):Mensaje=
    var config = getconfig()
    let ix_t = config.tablas.find(Tabla(nombre:tablan))
    if ix_t == -1:
        return Mensaje(codigo: -4, msg:"No existe esa tabla")
    
    config.tablas = config.tablas.filter(proc(t:Tabla):bool = t.nombre != tablan)
    let db = open("data.sqlite","","","")
    db.exec(sql "DROP TABLE " & tablan )
    db.close()
    setconfig(config)
    return Mensaje(codigo:2 , msg :"Se Pudo eliminar la tabla")


proc validedittabla(tabla:Tabla,editt:EditTabla):Mensaje=
    var haycambio=false
    var campos_nuevos_map = initTable[string,int]()
    if editt.nuevos.isSome:
        haycambio=true
        let camposnuevos=editt.nuevos.get()
        for c in camposnuevos:
            let idx_c = tabla.campos.find(Campo(nombre:c.nombre))
            if idx_c != -1:
                return newMensaje(-1,"Ya existe el campo: " & c.nombre)
            if campos_nuevos_map.hasKey(c.nombre):
                return newMensaje(-2,"No se pueden repetir cambios campo: " & c.nombre)
            else:
                let idx_tipo = @["integer","text","real","blob"].find(c.tipo)
                if idx_tipo == -1:
                    return newMensaje(-3,"El tipo en el campo es incorrecto: " & c.nombre)
                
                campos_nuevos_map[c.nombre]=0
    if editt.eliminar.isSome:
        haycambio=true
        let eliminarlos = editt.eliminar.get()
        let deduplicados = deduplicate(eliminarlos)
        if deduplicados.len != eliminarlos.len:
            return newMensaje(-4,"No puede haber campos para eliminar repetidos")
        for e in eliminarlos:
            if e == "id":
                return newMensaje(-15,"No se  puede eliminar el campo id")
            let idx_c= tabla.campos.find(Campo(nombre:e))
            if idx_c == -1:
                return newMensaje(-5,"No existe el campo: " & e)
            if campos_nuevos_map.hasKey(e):
                return newMensaje(-6,"No se puede eliminar un campo que agregas: " & e)
            campos_nuevos_map[e]=0
    if editt.cambiarnombre.isSome:
        haycambio=true
        
        
        var cambiarnombre = editt.cambiarnombre.get()
        for i in countup(0,cambiarnombre.len-1):
            let fila = cambiarnombre[i]
            
            if fila.len != 2:
                return newMensaje(-7,"Tiene que estar primero el nombre del campo viejo y segundo el campo nuevo")
            if cambiarnombre[i][0] == "id":
                return newMensaje(-16,"No se puede modificar el campo id")
            if cambiarnombre[i][0] == cambiarnombre[i][1]:
                return newMensaje(-12,"No pueden ser iguales el campo nuevo y el viejo")
            let idx_campo_old = tabla.campos.find(Campo(nombre:cambiarnombre[i][0]))
            let idx_campo_new = tabla.campos.find(Campo(nombre:cambiarnombre[i][1]))
            if idx_campo_old == -1:
                return newMensaje(-8,"No existe el campo en los campos viejos: " & cambiarnombre[i][0])
            if idx_campo_new != -1:
                return newMensaje(-9,"Ya existe ese campo en los campos nuevos: " & cambiarnombre[i][1])
            if campos_nuevos_map.hasKey(cambiarnombre[i][0]):
                return newMensaje(-10,"No se puede editar un campo que se va a agregar o eliminar:" & cambiarnombre[i][0])
            if campos_nuevos_map.hasKey(cambiarnombre[i][1]):
                return newMensaje(-11,"No se puede tener como campo nuevo uno que se va a agregar o eliminar: " & cambiarnombre[i][1])
            
    if editt.cambiartipo.isSome:
        haycambio=true
        var cambiartipo =editt.cambiartipo.get()        
        for c in cambiartipo:
            let idx_campo = tabla.campos.find(Campo(nombre:c.nombre))
            if idx_campo == -1:
                return newMensaje(-13,"No existe el campo: " & c.nombre)
            if c.nombre == "id":
                return newMensaje(-17,"NO se puede cambiar el campo id")
            let idx_tipo= @["integer","real","text","blob"].find(c.tipo)
            if idx_tipo == -1:
                return newMensaje(-14,"No es un tipo valido en el campo: " & c.tipo)

    
            

    if editt.nombre.isSome:
        haycambio=true
    if not haycambio:
        return newMensaje(-10,"NO se hizo ningun cambio")
    newMensaje(0,"")


#"Se puede agregar columnas, quitarlas, cambiarle el nombre y cambiarle el tipo"
proc edittabla*(tablan:string,jsono:JsonNode):Mensaje=
    var config = getconfig()
    
    let idx_t = config.tablas.find(Tabla(nombre:tablan))
    
    if idx_t == -1:
        return newMensaje(-5,"Esa tabla no existe")
    var t = config.tablas[idx_t]
    var editt=to(jsono,EditTabla)
    var valido=validedittabla(t,editt)
    if valido.codigo != 0:
        return valido
    if editt.nuevos.isSome:
        var db = open("data.sqlite","","","")
        db.exec(sql"BEGIN")
        for c in editt.nuevos.get():
            let sqlcode = "ALTER TABLE " & tablan & " ADD " & c.nombre & " " & c.tipo
            db.exec(sql sqlcode)
            t.campos.add(Campo(nombre:c.nombre,tipo:c.tipo))
        db.exec(sql"COMMIT")
        db.close()
    if editt.eliminar.isSome:
        var db = open("data.sqlite","","","")
        db.exec(sql"BEGIN")
        for le in editt.eliminar.get():
            var e = le
            let sqlcode = "ALTER TABLE " & tablan & " DROP COLUMN " & e
            db.exec(sql sqlcode)
            t.campos = t.campos.filter(proc(c:Campo):bool = c.nombre != e)
        db.exec(sql"COMMIT")
        
        db.close() 
    if editt.cambiarnombre.isSome:
        var db = open("data.sqlite","","","")
        db.exec(sql"BEGIN")
        for c in editt.cambiarnombre.get():
            let nombre_old = c[0]
            let nombre_new = c[1]
            let idx_c = t.campos.find(Campo(nombre:nombre_old))
            t.campos[idx_c].nombre = nombre_new
            let sqlcode = "ALTER TABLE " & tablan & " RENAME COLUMN " & nombre_old & " TO " & nombre_new
            db.exec(sql sqlcode)
        db.exec(sql"COMMIT")
        db.close()
    if editt.cambiartipo.isSome:
        var db = open("data.sqlite","","","")
        db.exec(sql"BEGIN")
        for c in editt.cambiartipo.get():
            var sqlcode = "ALTER TABLE " & tablan & " DROP COLUMN " & c.nombre  
            db.exec(sql sqlcode)
            sqlcode = "ALTER TABLE " & tablan & " ADD " & c.nombre  & " " & c.tipo
            db.exec(sql sqlcode)
            let idx_c = t.campos.find(Campo(nombre:c.nombre))
            t.campos[idx_c].tipo = c.tipo
        db.exec(sql"COMMIT")
        db.close()
    if editt.nombre.isSome:
        let nombre = editt.nombre.get()
        var db = open("data.sqlite","","","")
        db.exec(sql"BEGIN")
        
        let sqlcode = "ALTER TABLE " & tablan & " RENAME TO " & nombre
        echo sqlcode
        db.exec(sql sqlcode)
        db.exec(sql"COMMIT")
        db.close()
        t.nombre = nombre
    
    
    config.tablas[idx_t] = t
    setconfig(config)
    return valido
proc todastablas*():seq[Tabla]=
    getconfig().tablas

# Aca iria la libreria
proc initdatabase*()=
    if not fileExists("data.sqlite"):
        echo "No existe una base de datos se va a crear una"
        let db = open("data.sqlite","","","")
        db.exec(sql"""
            CREATE TABLE Config (
                id INTEGER,
                config TEXT
            )
        """)
        db.exec(sql"INSERT INTO Config (id, config) VALUES (1, ?)","""{"tablas":[]}""")
        db.close()
    let config = getconfig()
    echo config


## Logica de los datos
## Es cualquiera que devuelva un mensaje pero por ahora
proc getRow*(tablan:string,id:string):JsonNode=
    #echo "Get row baby"
    let config = getconfig()
    let idx_table = config.tablas.find(Tabla(nombre:tablan))
    if idx_table == -1:
        let mensaje = newMensaje(-1,"No existe esa tabla")
        let respuesta = newDBResponse("Error",mensaje)
        return %*respuesta
    
    var sqlcode ="SELECT "
    var arrfields:seq[string] = @[]
    var i = 0
    for c in config.tablas[idx_table].campos:
        #if c.nombre == "id":
        #    continue
        if i < config.tablas[idx_table].campos.len - 1:
            sqlcode &= " " & c.nombre & ", "
        else:
            sqlcode &= " " & c.nombre & "  "
        
        i += 1
    sqlcode &= " FROM ? WHERE id = ?"
    arrfields.add(tablan)
    arrfields.add(id)
    # No me gusta la idea de sqlcode
    #echo sqlcode
    let db = open("data.sqlite","","","")
    let row = db.getRow(sql sqlcode , arrfields)
    #let row3 = db.getAllRows(sql "select id,c1 from t1 where id = ?" , id)
    #let row2= db.getRow(sql """ SELECT * FROM ? WHERE id = ?""",tablan,id)
    db.close()
    #echo row3
    #echo row2
    #echo row
    if row[0] == "":
        let mensaje = newMensaje(-2,"NO existe ese records")
        return %* newDBResponse("Error",mensaje)
    var jsonstr ="""{"meta":"todo bien","data":{"id":""""
    jsonstr &= row[0]
    jsonstr &= """", """
    i = 0
    
    for c in config.tablas[idx_table].campos:
        #if c.nombre == "id":
        #    continue
        if c.tipo == "text":
            
            jsonstr &= """ """" 
            jsonstr &= c.nombre & """" : """"
            jsonstr &= row[i]
            jsonstr &= """" """
        else:
            jsonstr &= """ """" 
            jsonstr &= c.nombre & """" :  """
            jsonstr &= row[i]
        if i < config.tablas[idx_table].campos.len - 1:
            jsonstr &= ","

        i += 1
    jsonstr &= "}}"
    #echo jsonstr
    let jso = parseJson(jsonstr)
    return jso
    
proc getRows*(tablan:string):JsonNode=
    let config = getconfig()
    let idx_table = config.tablas.find(Tabla(nombre:tablan))
    if idx_table == -1:
        let mensaje = newMensaje(-1,"No existe esa tabla")
        return %* newDBResponse("Error",mensaje)
    
    var arrfields: seq[string ]= @[]
    var sqlcode = "SELECT   "
    var i = 0
    for c in config.tablas[idx_table].campos:
        if i < config.tablas[idx_table].campos.len - 1:
            sqlcode &= " " & c.nombre & ", "
        else:
            sqlcode &= " " & c.nombre & "  "
        
        i += 1
    
    sqlcode &= " FROM ?"
    echo sqlcode
    arrfields.add(tablan)
    var  jsostrall="""{"meta":"todo bien","data":["""
    let db = open("data.sqlite","","","")
    #let sqlcode ="SELECT * FROM " & tablan  
    #let rws = db.getAllRows(sql sqlcode)
    let rows = db.getAllRows(sql sqlcode,tablan)
    echo rows
    i = 0
    for row in rows:
        var jsonstr ="{"
        var j = 0
        for c in config.tablas[idx_table].campos:
            if c.tipo == "text":
                jsonstr &= """ """" 
                jsonstr &= c.nombre & """" : """"
                jsonstr &= row[j]
                jsonstr &= """" """
            else:
                jsonstr &= """ """" 
                jsonstr &= c.nombre & """" :  """
                jsonstr &= row[j]
            if j < config.tablas[idx_table].campos.len - 1:
                jsonstr &= ","

            
            j += 1
        jsonstr &= "}"
        jsostrall &= jsonstr
        if i < rows.len - 1:
            jsostrall &= " , "
        i += 1 
    db.close()
    jsostrall &= "]}"
    #echo rws
    echo jsostrall
    return parseJson(jsostrall)

proc validateaddRow(tablan:string,ar:AgregarFila):Mensaje=
    let config = getconfig()
    let idx_table = config.tablas.find(Tabla(nombre:tablan))
    if idx_table == -1:
        return newMensaje(-1,"No existe esa tabla")
    let tabla = config.tablas[idx_table]
    for c in ar.valores:
        let idx_c = tabla.campos.find(Campo(nombre:c.nombre))
        let campo=tabla.campos[idx_c]
        if idx_c == -1:
            return newMensaje(-2,"No existe ese campo: " & c.nombre)

        if campo.tipo == "real":
            var valor:float
            let res = parseFloat(c.valor,valor,0)
            if res == 0:
                return newMensaje(-3,"El campo tiene un valor invalido: " & c.nombre)
        if campo.tipo == "integer":
            var valor:int
            let res = parseInt(c.valor,valor,0)
            if res == 0:
                return newMensaje(-3,"El campo tiene un valor invalido: " & c.nombre)
    return newMensaje(0,"")
proc addRow*(tablan:string,jso:JsonNode):Mensaje=
    var newrow = to(jso,AgregarFila)
    let valido = validateaddRow(tablan,newrow)
    if valido.codigo < 0:
        return valido
    var sqlcode = "INSERT INTO ? "
    var sqlcodefields = "( ? ,"
    var sqlcodevalues = "( ? ,"
    var arrfields:seq[string] = @[tablan,"id"]
    var arrvalues:seq[string] = @[$genOid()]
    let vlen = newrow.valores.len
    var i = 0
    for valor in newrow.valores:
        if i < vlen-1:
            sqlcodefields &= " ?, "
            sqlcodevalues &= " ?, "
        else:
            sqlcodefields &= " ? "
            sqlcodevalues &= " ? "
        arrfields.add(valor.nombre)
        arrvalues.add(valor.valor)
        i += 1
    sqlcodefields &= " ) VALUES "
    sqlcodevalues &= " )"
    sqlcode &= sqlcodefields & sqlcodevalues
    let db=open("data.sqlite","","","")
    db.exec(sql sqlcode,arrfields.concat(arrvalues))
    db.close()
    return newMensaje(0,"Se guardo joya")
proc editRow*(tablan:string,id:string,jso:JsonNode):Mensaje=
    var newrow = to(jso,AgregarFila)
    let valido = validateaddRow(tablan,newrow)
    if valido.codigo < 0:
        return valido
    var db = open("data.sqlite","","","")
    var sqlcode ="SELECT * FROM " & tablan & " WHERE id = ?"
    let rw = db.getRow(sql sqlcode , id)
    db.close()
    if rw.len == 0:
        return newMensaje(-2,"{'data':'No existe ese record'}")
    sqlcode = "UPDATE ? SET "
    var arrfields:seq[string] = @[tablan]
    var sqlcodefields = ""
    var i = 0
    for c in newrow.valores:
        if i < newrow.valores.len - 1:
            sqlcodefields &= " ? = ? ,"
            
        else:
            sqlcodefields &= " ? = ?"
        arrfields.add(c.nombre)
        arrfields.add(c.valor)
        i += 1
    
    sqlcodefields &= " WHERE id = ?"
    arrfields.add(id)
    sqlcode &= sqlcodefields
    db = open("data.sqlite","","","")
    
    db.exec(sql sqlcode,arrfields)
    db.close()
    newMensaje(0,"Se edito joya")
proc deleteRow*(tablan:string,id:string):Mensaje=
    let config = getconfig()
    let idx_table = config.tablas.find(Tabla(nombre:tablan))
    if idx_table == -1:
        return newMensaje(-1,"{'data':'No existe esa tabla'}")
    var db = open("data.sqlite","","","")
    let sqlcode ="SELECT * FROM " & tablan & " WHERE id = ?"
    let rw = db.getRow(sql sqlcode , id)
    db.close()
    if rw.len == 0:
        return newMensaje(-2,"{'data':'No existe ese record'}")
    db = open("data.sqlite","","","")
    let sqlcodedel ="DELETE FROM ? WHERE id = ? "
    echo sqlcodedel
    echo tablan
    echo id
    db.exec(sql sqlcodedel ,tablan, id)
    db.close()    
    return newMensaje(0,"Se guardo mortal")
    
