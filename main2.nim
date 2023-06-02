# Aca iria lo del frontend
import json
import asyncdispatch, jester, strutils
import lib

router myrouter:
    # Testing
    get "/":
        resp "va"
    # Modificar una tabla
    patch "/tablas/@tablan/records/@id":
        let jsonObject = parseJson($request.body)
        resp print(editRow(@"tablan",@"id",jsonObject))
    # Tpdas las tablas
    get "/tablas":
        resp %*todastablas()
    # Ver un record de una tabla
    get "/tablas/@tablan/records/@id":
        
        resp %*getRow(@"tablan",@"id")
    # Ver los records de una tabla
    get "/tablas/@tablan/records":
        resp %*getRows(@"tablan")
    # Agregar una fila a la tabla
    post "/tablas/@tablan/records":
        let jsonObject = parseJson($request.body)

        resp print(addRow(@"tablan",jsonObject))
    # Agregar una tabla
    post "/newtabla/":
        let jsonObject = parseJson($request.body)
        var tabla = to(jsonObject, Tabla)
        resp newtabla(tabla)
    # Editar una tabla
    post "/edittabla/@tablan":
        let jsonObject = parseJson($request.body)
        
        resp edittabla(@"tablan",jsonObject)
    # Eliminar una tabla
    post "/deletetabla/@tablan":
        resp deletetabla(@"tablan")
    # Eliminar una fila de la tabla
    delete "/tablas/@tablan/records/@id":
        resp print(deleteRow(@"tablan",@"id"))
    else:
        resp "not found"


proc main()=
    
    let port = "22222".parseInt().Port
    let settings = newSettings(port)
    var jester = initJester(myrouter,settings=settings)
    initdatabase()
    jester.serve()

when isMainModule:
    main()