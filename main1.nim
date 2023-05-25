import os
import json
import tiny_sqlite, std / options
type TIPOSQLITE3 = enum
    INTEGER="INTEGER",REAL="REAL",TEXT="TEXT",BLOB="BLOB"
type Campo = object
    nombre : string
    tipo : TIPOSQLITE3
type Tabla = object
    nombre : string
    campos : seq[Campo] 
type Config = object
    archivo : string
    tablas : seq[Tabla]
proc print(c:Campo):string=
    var s = "\t\tnombre: " & c.nombre
    s &= "\ttipo: " & $c.tipo
    s
proc print(t:Tabla):string=
    var s = "\tnombre: " & t.nombre
    s &= "\n"
    for c in t.campos:
        s &= c.print()
    
        s &= "\n"
    s
proc print(c:Config):string=
    var s ="archivo: " & c.archivo
    s &= "\n"
    for t in c.tablas:
        s &= t.print()
        s &= "\n"
    s
proc existeFile(path:string):bool=
    fileExists(path)
proc crear_tabla():Tabla=
    echo "Escriba el nombre de la tabla"
    var nombre = readLine(stdin)
    var campos:seq[Campo] = @[]
    var nombre_campo="c"
    while nombre_campo.len()!=0:
        echo "Ingrese el nombre del campo enter si no desea mas campos"
        nombre_campo = readLine(stdin)
        if nombre_campo.len==0:
            break
        echo "Ingrese el tipo 1 integer, 2 real, 3 text, 4 blob"
        var tipo_inp= readLine(stdin)
        var tipo_str=TIPOSQLITE3.INTEGER
        if tipo_inp=="2":
            tipo_str =  TIPOSQLITE3.REAL
        elif tipo_inp == "3":
            tipo_str = TIPOSQLITE3.TEXT
        elif tipo_inp == "4":
            tipo_str  = TIPOSQLITE3.BLOB
        else:
            tipo_str = TIPOSQLITE3.INTEGER
        let campo = Campo(nombre:nombre_campo,tipo:tipo_str)
        campos.add(campo)
    
    Tabla(nombre:nombre, campos:campos)
proc crearTablaDB(db:DbConn,tabla:Tabla)=
    var s = "CREATE TABLE " & tabla.nombre & " ("
    
    var i=0
    for c in tabla.campos:
        i += 1
        if i == tabla.campos.len:
            s &= "\t" & c.nombre & " " & $c.tipo
        else:
            s &= "\t"&c.nombre & " " & $c.tipo & "," 
    s &= ");"
    
    db.exec(s)


proc main()=
    let file="bd.json"

    if existeFile("bd.json"):
        let config_str=readFile("bd.json")
        let jsonObject = parseJson(config_str)

        let config = to(jsonObject, Config)
        echo print(config)
        let db = openDatabase(config.archivo)
        echo "Desea agregar una tabla? Si(s)- No(n)"
        var respuesta=readLine(stdin)
        if respuesta == "s":
            let tabla = crear_tabla()
            crearTablaDB(db,tabla)
        db.exec("SELECT name FROM sqlite_temp_master WHERE type='table';")
    else:
        echo "No existe el archivo asi que se va a crear uno de cero"
        echo " Escriba el nombre de la base de datos:(data.sqlite)"
        var nombre = readLine(stdin)
        if nombre.len() == 0:
            nombre ="data.sqlite"
        let config= Config(archivo:nombre,tablas : @[])
        let config_str =  $ %* config
        writeFile("bd.json",config_str)
        let db = openDatabase(nombre)
        
        echo "Desea agregar una tabla? Si(s)- No(n)"
        var respuesta=readLine(stdin)
        if respuesta == "s":
            let tabla = crear_tabla()
            crearTablaDB(db,tabla)
        





        
main()