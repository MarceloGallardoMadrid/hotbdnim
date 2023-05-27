import std/db_sqlite
import strutils
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
    var s ="archivo: data.sqlite" 
    s &= "\n"
    for t in c.tablas:
        s &= t.print()
        s &= "\n"
    s
proc existeFile(path:string):bool=
    fileExists(path)

proc show_help()=
    echo "Escribe help para este mensaje"
    echo "Comando tablas"
    echo "Los tipos son text,real,integer,blob"
    echo "new (nombre tabla) campo1 tipo1 campo2 tipo2"
    echo "Crear una nueva tabla"
    echo "del (nombre tabla)"
    echo "Eliminar la tabla"
    echo "edit (nombre tabla) add campo1 tipo1 campo2 tipo2 rem campo3"
    echo "Modoficar la tabla agregando campos y eliminadolos"
    echo "tabla (nombre tabla) add campo1 campo2 d valor1 valor2"
    echo "Insertar un valor en la tabla con esos campos y esos valores respecticos"
    echo "tabla (nombre tabla) rem (id)"
    echo "Eliminar la fila"
    echo "tabla (nombre tabla) edit campo1 campo2 d valor1 valor2 w (id)"
    echo "Editar la fila con ese id"
    echo "tabla (nombre tabla) getall"
    echo "Ver todas las filas"
    echo "tabla (nombre tabla) getone (id)"
    echo "Ver un row"
    echo "tabla (nombre tabla) fields"
    echo "Ver los campos de la tabla"

proc main()=
    var config = Config(tablas : @[])
    if not existeFile("data.sqlite"):
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
    else:
        let db = open("data.sqlite","","","")
        var config_str=db.getValue(sql"SELECT config FROM Config WHERE id = ?",1)
        echo config_str
        db.close()
        let jsonObject = parseJson(config_str)

        config = to(jsonObject, Config)
    echo print(config)
    var comando ="c"
    var comando_seq:seq[string] = @[]
    echo "Escribe un comando para manera la bd"
    echo "Escribe help para ver los comandos posibles"
    echo "Escribe exit para salir"
    while comando != "exit" :
        comando = readLine(stdin)
        comando = comando.toLower()
        if comando == "exit":
            echo "bye :)"
            break
        if comando == "help":
            show_help()
        comando_seq = comando.split(" ")
        echo comando_seq
        
        

main()

        

        


