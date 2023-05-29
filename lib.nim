import os
import std/db_sqlite
import sequtils
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
    echo config_str
    db.close()
    let jsonObject = parseJson(config_str)
    return to(jsonObject, Config)
proc setconfig(config:Config)=
    let db = open("data.sqlite","","","")
    let consig_str:string = $(%*config)
    db.exec(sql "UPDATE Config SET config='" & consig_str & "' WHERE id=1" )
    db.close()

proc newtabla*(tabla:Tabla):Mensaje=
    var config = getconfig()
    for t in config.tablas:
        if t.nombre == tabla.nombre:
            var m = Mensaje( codigo : -1 , msg : "ya existe esa tabla")
            return m
    var campos_map=initTable[string,string]()
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

#"Se puede agregar columnas, quitarlas, cambiarle el nombre y cambiarle el tipo"
proc edittabla*(tabla:string,json:JsonNode):Mensaje=
    Mensaje()

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