# Aca iria lo del frontend
import json
import asyncdispatch, jester, strutils
import lib

router myrouter:
    get "/":
        resp "va"
    get "/tablas":
        resp %*todastablas()
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