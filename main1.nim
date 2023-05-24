import os
import json
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

proc main()=
    let file="bd.json"

    if existeFile("bd.json"):
        let config_str=readFile("bd.json")
        let jsonObject = parseJson(config_str)

        let config = to(jsonObject, Config)
        echo print(config)
    else:
        echo "No existe el archivo asi que se va a crear uno de cero"
        echo " Escriba el nombre de la base de datos:(data.sqlite)"
        var nombre = readLine(stdin)
        if nombre.len() == 0:
            nombre ="data.sqlite"
        let config= Config(archivo:nombre,tablas : @[])
        let config_str =  $ %* config
        writeFile("bd.json",config_str)

        
main()