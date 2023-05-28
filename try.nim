import std/db_sqlite
import strutils
import sequtils
import os
import json
import tables
import std/oids
#https://nim-lang.org/docs/oids.html

type TIPOSQLITE3 = enum
    INTEGER="INTEGER",REAL="REAL",TEXT="TEXT",BLOB="BLOB"
type COMANDOS = enum
    NEW="new",EDIT="edit",DEL="del",TABLACOM="tabla"
type COMANDOSTABLA = enum
    ADD="add",MOD="mod",REM="rem",ALL="getall",GETONE="getone",FIELDS="fields"
type Campo = object
    nombre : string
    tipo : TIPOSQLITE3
type Tabla = object
    nombre : string
    campos : seq[Campo] 
type Config = object
    tablas : seq[Tabla]
proc `==`(c1:Campo,c2:Campo):bool=
    return c1.nombre == c2.nombre
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
proc tipocampo(tc:string):TIPOSQLITE3=
    case tc:
        of "integer":
            return TIPOSQLITE3.INTEGER
        of "real":
            return TIPOSQLITE3.REAL
        of "text":
            return TIPOSQLITE3.TEXT
        else:
            return TIPOSQLITE3.BLOB
proc tipocampotabla(campo:string,tabla:Tabla):TIPOSQLITE3=
    
    let ix_c = tabla.campos.find(Campo(nombre:campo))
    return tabla.campos[ix_c].tipo
proc insert_tabla(commands:seq[string],config:Config):Config=
    let ix_add = commands.find("add")
    let ix_d = commands.find("d")
    let campos_len = ix_d - ix_add - 1
    for t in config.tablas:
        if t.nombre == commands[1]:
            var sqlcode = "INSERT INTO " & t.nombre & "( id,"
            
            for i in countup(1,campos_len):
                sqlcode &= commands[ix_add+i]
                if i != campos_len:
                    sqlcode &= ","
            sqlcode &= ") VALUES ('" & $genOid() & "',"
            for i in countup(1,campos_len):
                let tipo_campo=tipocampotabla(commands[ix_add+i],t)
                if tipo_campo == TIPOSQLITE3.TEXT:
                    sqlcode &= "'" & commands[ix_d+i] & "'"
                else:
                    sqlcode &= commands[ix_d+i]
                if i != campos_len:
                    sqlcode &= ","

            sqlcode &= ")"
            let db =open("data.sqlite","","","")
            echo sqlcode
            db.exec(sql sqlcode)
            db.close()
            return config
proc new_tabla(commands:seq[string],config:Config):Config=
    var sqlcode="CREATE TABLE " & commands[1] & "( id TEXT , "
    var campos_map = initTable[string, TIPOSQLITE3](commands.len-2)
    var par=true
    var nombre_campo =""
    var tipo_campo="integer"
    campos_map["id"]=TIPOSQLITE3.TEXT
    for i in countup(2,commands.len-1):
        if par:
            nombre_campo=commands[i]
            sqlcode &= nombre_campo & " "
        else:
            tipo_campo = commands[i]
            case tipo_campo:
                of "integer":
                    campos_map[nombre_campo] = TIPOSQLITE3.INTEGER
                    sqlcode &= $TIPOSQLITE3.INTEGER
                of "real":
                    campos_map[nombre_campo] = TIPOSQLITE3.REAL
                    sqlcode &= $TIPOSQLITE3.REAL
                of "text":
                    campos_map[nombre_campo] = TIPOSQLITE3.TEXT
                    sqlcode &= $TIPOSQLITE3.TEXT
                of "blob":
                    campos_map[nombre_campo] = TIPOSQLITE3.BLOB
                    sqlcode &= $TIPOSQLITE3.BLOB
                else:
                    echo "Para el campo: " & nombre_campo & " el tipo de datos no existe "
            if i != commands.len-1:
                sqlcode &= ","        
        par = not par
    
    let db = open("data.sqlite","","","")
    sqlcode &= ")"
    
    db.exeC(sql sqlcode)
    
    db.close()
    
    var campos:seq[Campo] = @[]

    for k in campos_map.keys:
        campos.add(Campo(nombre:k,tipo:campos_map[k]))
    let tabla=Tabla(nombre:commands[1],campos:campos)
    var new_config= config
    new_config.tablas.add(tabla)

    new_config
    
proc del_tabla(commands:seq[string],config:Config):Config=
    let db = open("data.sqlite","","","")
    let sqlcode = "DROP TABLE " & commands[1]
    echo sqlcode
    db.exeC(sql sqlcode)
    
    db.close()
    var new_config = config
    new_config.tablas = config.tablas.filter(proc(t:Tabla):bool = t.nombre != commands[1])
    return new_config
proc escomandotabla(ct:string):bool=
    case ct:
        of "add":
            return true
        of "rem":
            return true
        of "mod":
            return true
        of "getone":
            return true
        of "getall":
            return true
        of "fields":
            return true
        else:
            return false
proc comandotabla(ct:string):COMANDOSTABLA=
    case ct:
        of "add":
            return COMANDOSTABLA.ADD
        of "rem":
            return COMANDOSTABLA.REM
        of "mod":
            return COMANDOSTABLA.MOD
        of "getone":
            return COMANDOSTABLA.GETONE
        of "getall":
            return COMANDOSTABLA.ALL
        of "fields":
            return COMANDOSTABLA.FIELDS
        else:
            return COMANDOSTABLA.ADD


proc edit_tabla(commands:seq[string],config:Config):Config=
    var new_campos:seq[Campo] = @[]
    var ix_t=0
    var new_config=config
    for t in new_config.tablas:
        if t.nombre == commands[1]:
            # t es la tablas
            new_campos = t.campos
            let ix_add=commands.find("add")
            let ix_rem=commands.find("rem")
            if ix_add != -1:
                let last_campo= if ix_rem == -1: commands.len-1 else: ix_rem - 1
                let cols =commands[ix_add+1 .. last_campo]
                var init_sql= "ALTER TABLE " & t.nombre
                var sqlcode = ""
                var par=true
                
                var nombre_campo = ""
                var tipo_campo = TIPOSQLITE3.INTEGER
                for c in cols:
                    if par:
                        sqlcode &= init_sql & " ADD COLUMN " & c & " "
                        nombre_campo = c
                    else:
                        sqlcode &= c
                        tipo_campo = tipo_campo(c)
                        
                        sqlcode &= ";"
                        new_campos.add(Campo(nombre:nombre_campo,tipo:tipo_campo))
                        ## No lo veo como lo mas inteligente pero por ahora resuelve
                        let db=open("data.sqlite","","","")    
                        echo sqlcode
                        db.exec(sql sqlcode)
                        db.close()
                        sqlcode = ""

                    par = not par
                    
                    
                

            if ix_rem != -1:
                let cols =commands[ix_rem+1 .. commands.len-1]
                var init_sql="ALTER TABLE " & t.nombre
                var sqlcode =""
                
                for c in cols:
                    let col = c
                    sqlcode &= init_sql & " DROP COLUMN " & col & " "
                    new_campos=new_campos.filter(proc(camp:Campo):bool = camp.nombre != col)
                    sqlcode &= ";"
                    let db = open("data.sqlite","","","")
                    echo sqlcode
                    db.exec(sql sqlcode)
                    db.close()
                    sqlcode = ""
            
            let new_tabla=Tabla(nombre:t.nombre,campos:new_campos)
            new_config.tablas[ix_t]=new_tabla
            return new_config
        ix_t += 1
    return config
proc show_help()=
    echo "Escribe help para este mensaje"
    echo "Todo se asume que es lowercase"
    echo "Comando tablas"
    echo "Los tipos son text,real,integer,blob"
    echo "new (nombre tabla) campo1 tipo1 campo2 tipo2"
    echo "  Crear una nueva tabla"
    echo "del (nombre tabla)"
    echo "  Eliminar la tabla"
    echo "edit (nombre tabla) add campo1 tipo1 campo2 tipo2 rem campo3"
    echo "  Modoficar la tabla agregando campos y eliminadolos"
    echo "tabla (nombre tabla) add campo1 campo2 d valor1 valor2"
    echo "  Insertar un valor en la tabla con esos campos y esos valores respecticos"
    echo "tabla (nombre tabla) rem (id)"
    echo "  Eliminar la fila"
    echo "tabla (nombre tabla) edit campo1 campo2 d valor1 valor2 w (id)"
    echo "  Editar la fila con ese id"
    echo "tabla (nombre tabla) getall"
    echo "  Ver todas las filas"
    echo "tabla (nombre tabla) getone (id)"
    echo "  Ver un row"
    echo "tabla (nombre tabla) fields"
    echo "  Ver los campos de la tabla"
proc valid_insert(commands:seq[string],conffig:Config,t:Tabla):bool=
    let ix_add = commands.find("add")
    let ix_d = commands.find("d")
    var campos_map = initTable[string,int]()
    if ix_add == -1:
        echo "tiene que estar comando add"
        return false
    if ix_d == -1:
        echo "tiene que estar comando d"
        return false
    if ix_add > ix_d:
        echo "El comando add debe estar antes que d"
        return false
    let campos_len=ix_d - ix_add - 1
    let valors_len=commands.len - ix_d - 1
    if campos_len != valors_len:
        echo "Tiene que haber tantos campos como valores"
        return false
    for i in countup(1,campos_len):
        let campo = commands[ix_add+i]
        if campos_map.hasKey(campo):
            echo "No se pueden repetir los campos: " & campo
            return false
        campos_map[campo] = 0
        let ix_c = t.campos.find(Campo(nombre:campo))
        if ix_c == -1 :
            echo "No existe ese campo: " & campo
            return false

    return true
proc valid_remove(commads:seq[string],conffig:Config):bool=
    true
proc valid_update(commads:seq[string],conffig:Config):bool=
    true
proc valid_getone(commads:seq[string],conffig:Config):bool=
    true

proc valid_new(commands:seq[string],config:Config):bool=
    var campos_map = initTable[string, string]()
    if commands.len-2==0:
        echo "No puede haber tablas sin columnas"
        return false
    if commands.len mod 2 != 0:
        echo "Debe haber tantas nombres de campos como sus tipos"
    for t in config.tablas:
        if commands[1] == t.nombre:
            echo "NO puede haber 2 tablas con nombres iguales"
            return false
    
    var par=true
    var nombre_campo =""
    var tipo_campo="integer"
    for i in countup(2,commands.len-1):
        if par:
            nombre_campo=commands[i]
            if campos_map.hasKey(nombre_campo):
                echo "No puede haber campos iguales"
                return false
            
        else:

            tipo_campo = commands[i]
            case tipo_campo:
                of "integer":
                    campos_map[nombre_campo] = $TIPOSQLITE3.INTEGER
                    
                of "real":
                    campos_map[nombre_campo] = $TIPOSQLITE3.REAL
                    
                of "text":
                    campos_map[nombre_campo] = $TIPOSQLITE3.TEXT
                    
                of "blob":
                    campos_map[nombre_campo] = $TIPOSQLITE3.BLOB
                    
                else:
                    echo "Para el campo: " & nombre_campo & " el tipo de datos no existe "
                    return false
        par = not par

    true
# Agregar y quitar columnas, total no es la version final
proc valid_edit(commands:seq[string],config:Config):bool=
    for t in config.tablas:
        if t.nombre == commands[1]:
            let ix_add=commands.find("add")
            let ix_rem=commands.find("rem")
            if ix_add == -1 and ix_rem == -1:
                echo "Debe estar la palabra add o rem"
                return false
            if ix_add != -1 and ix_rem != -1 and ix_add > ix_rem:
                echo "Dbe estar la palabra add adelante de rem"
            if ix_add != -1:
                if ix_add != 2:
                    echo "No puede haver ninguna palabra antes de add"
                    return false
                var campo_map=newTable[string,int]()
                let campo_tipo = ix_rem - ix_add - 1
                if campo_tipo mod 2 != 0:
                    echo "Debe haber la misma cantidad de tipos como de campo"
                    return false
                let last_campo= if ix_rem == -1: commands.len-1 else: ix_rem - 1
                let cols =commands[ix_add+1 .. last_campo]
                var par=true
                for tc in t.campos:
                    campo_map[tc.nombre] = 1
                for c in cols:
                    
                    if par:
                        if campo_map.hasKey(c):
                            echo "No puede haber 2 columnas iguales, error en " & c
                            return false
                        else:
                            campo_map[c]=1
                    else:
                        let ix_com = @["integer","real","text","blob"].find(c)
                        if ix_com == -1:
                            echo "No existe el tipo: " & c
                    par = not par
            
            if ix_rem != -1:
                let cols=commands[ix_rem+1 .. commands.len-1]
                var todo_bien=false
                for c in cols:
                    todo_bien = false
                    for tc in t.campos:
                        if tc.nombre == c:
                            todo_bien =true
                    if not todo_bien:
                        echo "No existe la columna: " & c
                        return false

            return true
    
    echo "No hay ninguna tabla con ese nombre"
    return false
proc valid_del(commands:seq[string],config:Config):bool=
    for t in config.tablas:
        if t.nombre == commands[1]:
            echo "Seguro que desea eliminar la tabla: '" & t.nombre & "' Si(s), lo demas n "

            let verificar = readLine(stdin)
            if verificar == "s":
                return true
            else:
                return false
    echo "No hay ninguna tabla con ese nombre"

    return false
proc valid_tabla(commands:seq[string],config: Config):bool=
    if not escomandotabla(commands[2]):
        echo "No existe ese comando: " & commands[2]

        return false
    var comtabla=comandotabla(commands[2])
    for t in config.tablas:
        if commands[1] == t.nombre:
            case comtabla:
                of ADD:
                    return valid_insert(commands,config,t)
                of ALL:
                    return true
                    
                of FIELDS:
                    return true
                    
                of GETONE:
                    return valid_getone(commands,config)
                of MOD:
                    return valid_update(commands,config)
                else:
                    #rem
                    return valid_remove(commands,config)
            return true
    echo "NO se encontro la tabla"
    return false
proc valid_command(commands:seq[string],config:Config):bool=
    var valido=false
    var comando=COMANDOS.NEW
    if commands.len==0:
        echo "No puede ser vacio el comando"
        return false
    for com in @["new","del","edit","tabla"]:
        if commands[0]==com:
            if com=="new":
                comando=COMANDOS.NEW
            elif com=="del":
                comando=COMANDOS.DEL
            elif com=="edit":
                comando=COMANDOS.EDIT
            else:
                comando=COMANDOS.TABLACOM
            valido = true
            break
    if not valido:
        echo "Ningun primer comando es valido"
        return false
    case comando:
        of NEW:
            return valid_new(commands,config)
        of DEL:
            return valid_del(commands,config)
        of EDIT:
            return valid_edit(commands,config)
        else:
            return valid_tabla(commands,config)

    

proc proccess_comand(commands:seq[string],config:Config):Config=
    case commands[0]:
        of "new":
            return new_tabla(commands,config)
        of "del":
            return del_tabla(commands,config)
        of "edit":
            return edit_tabla(commands,config)
        else:
            let com_tabla=comandotabla(commands[2])
            case com_tabla:
                of ADD:
                    return insert_tabla(commands,config)
                of REM:
                    return config
                of ALL:
                    return config
                of FIELDS:
                    return config
                of GETONE:
                    return config
                else:
                    return config
            

            
        
            

proc main*()=
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
        if valid_command(comando_seq,config):
            config = proccess_comand(comando_seq,config)
            let db = open("data.sqlite","","","")
            let consig_str:string = $(%*config)
            db.exec(sql "UPDATE Config SET config='" & consig_str & "' WHERE id=1" )
            db.close()
        echo comando_seq
    
main()
        



        

        


