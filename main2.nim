# Aca iria lo del frontend
import json
import asyncdispatch, jester, strutils
import lib

router myrouter:
    get "/":
        resp "va"
    patch "/":
        resp "Funciona patch"
    get "/tablas":
        resp %*todastablas()
    get "/tablas/@tablan/@id":
        echo "por aca"
        resp print(getRow(@"tablan",@"id"))
    get "/tablas/@tablan":
        resp print(getRows(@"tablan"))
    
    post "/tablas/@tablan":
        let jsonObject = parseJson($request.body)

        resp print(addRow(@"tablan",jsonObject))
    post "/newtabla/":
        let jsonObject = parseJson($request.body)
        var tabla = to(jsonObject, Tabla)
        resp print(newtabla(tabla))
    post "/edittabla/@tablan":
        let jsonObject = parseJson($request.body)
        echo jsonObject
        resp print(edittabla(@"tablan",jsonObject))
    post "/deletetabla/@tablan":
        resp print(deletetabla(@"tablan"))
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