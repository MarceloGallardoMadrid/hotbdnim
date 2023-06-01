import tiny_sqlite, std / options
import parseutils
import sequtils
# Primero voy a usar un archivo json que diga la estructura de las tablas
# Si no existe te pide crear uno
# si existe una base de datos .sqlite te pregunta si queres usarla como referencia
# El json seria 
# Por ahora son enteros, reales, text y blob
#[
    json->{
        nombre:nombre de la bd,
        tablas[
            { 
                "nombre":"t1",
                "campos":[
                    {nombre:atributo,tipo:tipo},
                    {nombre:atributo,tipo:tipo}
                ]
            },
            {
                "nombre":"t2",
                "campos":[
                    {nombre:atributo,tipo:tipo},
                    {nombre:atributo,tipo:tipo}
                ]
            }
        ]
            
        
    }


]#
# Practicando
## Aprendiendo lo de las ramasgit
## 
## 
## 
## Como funciona?
let db = openDatabase(":memory:")
db.execScript("""
CREATE TABLE Person(
    name TEXT,
    age INTEGER
);

INSERT INTO
    Person(name, age)
VALUES
    ("John Doe", 47);
""")

db.exec("INSERT INTO Person VALUES(?, ?)", "Jane Doe", nil)

for row in db.iterate("SELECT name, age FROM Person"):
    let (name, age) = row.unpack((string, Option[int]))
    echo name, " ", age

# Output:
# John Doe Some(47)
# Jane Doe None[int]
var arr1 = @["1","2"]
var arr2 = @["3","4"]

proc printThings(things: varargs[string]) =
  for thing in things:
    echo thing
printThings(arr1.concat(arr2))