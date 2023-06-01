# Aca iria lo del frontend
import json
import asyncdispatch, jester, strutils
import lib

router myrouter:
    get "/":
        resp "va"
    patch "/tablas/@tablan/records/@id":
        let jsonObject = parseJson($request.body)
        resp print(editRow(@"tablan",@"id",jsonObject))
    # Debe devolver un json
    get "/tablas":
        resp %*todastablas()
    # Debe devolver un json
    get "/tablas/@tablan/records/@id":
        
        resp %*getRow(@"tablan",@"id")
    # Debe devolver un json
    get "/tablas/@tablan/records":
        resp print(getRows(@"tablan"))
    # Debe devolver un json
    post "/tablas/@tablan/records":
        let jsonObject = parseJson($request.body)

        resp print(addRow(@"tablan",jsonObject))
    # Debe devolver un json
    post "/newtabla/":
        let jsonObject = parseJson($request.body)
        var tabla = to(jsonObject, Tabla)
        resp print(newtabla(tabla))
    # Debe devolver un json
    post "/edittabla/@tablan":
        let jsonObject = parseJson($request.body)
        echo jsonObject
        resp print(edittabla(@"tablan",jsonObject))
    # Debe devolver un json
    post "/deletetabla/@tablan":
        resp print(deletetabla(@"tablan"))
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