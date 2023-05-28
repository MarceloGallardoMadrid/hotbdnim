# Aca iria lo del frontend
import json
import asyncdispatch, jester, strutils
import lib

router myrouter:
    get "/":
        resp "va"
    post "/newtabla/":
        
        echo request.body
        let jsonObject = parseJson($request.body)

        var tabla = to(jsonObject, Tabla)
        
        resp print(newtabla(tabla))
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