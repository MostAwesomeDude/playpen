imports
exports (main)

def [=> tag :DeepFrozen] | _ := import("lib/http/tag")
def [=> makeDebugResource :DeepFrozen,
     => makeResource :DeepFrozen,
     => makeResourceApp :DeepFrozen,
     => smallBody :DeepFrozen] | _ := import("lib/http/resource")

def tagExpr(expr, _, args, _) as DeepFrozen:
    "Create some pretty HTML for a Monte expression."

    return switch (expr.getNodeName()):
        match =="DefExpr":
            def start := if (expr.getPattern().getNodeName() == "VarPattern") {
                ""
            } else {
                "def "
            }
            def exit_ := if (expr.getExit() == null) {
                ""
            } else {
                `exit ${args[1]}`
            }
            tag.span(start, args[0], exit_, " := ", args[2])
        match =="EscapeExpr":
            tag.span("escape ", args[0], "{\n", args[1], "} catch ", args[2],
                     " {", args[3], "}\n")
        match =="LiteralExpr":
            tag.span(M.toQuote(expr.getValue()))
        match =="MethodCallExpr":
            def posArgs := [", "].join(args[2])
            tag.span(args[0], ".", args[1], "(", posArgs, args[3], ")")
        match =="NounExpr":
            def name :Str := expr.getName()
            tag.a(name, "href" => `#$name`)
        match =="SeqExpr":
            tag.span(["\n"].join(args[0]))
        match =="FinalPattern":
            def name :Str := expr.getNoun().getName()
            var rv := tag.span(name, "id" => name)
            if (expr.getGuard() != null):
                rv := tag.span(rv, " :", args[1])
            rv
        match =="ListPattern":
            # XXX tail
            tag.span("[", [", "].join(args[0]), "]")
        match =="VarPattern":
            def name :Str := expr.getNoun().getName()
            var rv := tag.span(`var $name`, "id" => name)
            if (expr.getGuard() != null):
                rv := tag.span(rv, " :", args[1])
            rv
        match =="ViaPattern":
            tag.span("via (", args[0], ") ", args[1])
        match ex:
            tag.span(`Do $ex next!`)

def makeLogger() as DeepFrozen:
    def lines := [].diverge()

    return object logger:
        to log(line :Str):
            lines.push(line)

        to getLines() :List[Str]:
            return lines.snapshot()

        to makeTrace():
            return object traceln:
                "Write a line to the trace log."
                match [=="run", items, _]:
                    def rv := [].diverge()
                    for item in items:
                        if (item =~ s :Str):
                            rv.push(s)
                        else:
                            rv.push(M.toString(item))
                    lines.push("".join(rv))

def main(=> currentRuntime, => makeTCP4ServerEndpoint, => unsealException,
         => unittest) as DeepFrozen:
    def [=> makeHTTPEndpoint] | _ := import("lib/http/server", [=> unittest])
    def [=> PercentEncoding] | _ := import("lib/codec/percent", [=> unittest])
    def [=> UTF8] | _ := import.script("lib/codec/utf8")
    def [=> composeCodec] | _ := import("lib/codec")

    def UTF8Percent := composeCodec(PercentEncoding, UTF8)

    def getForm(request, ej):
        "Get the body from a request and interpret it as a form."
        def contentType := request.getHeaders().getContentType()
        if (contentType != ["application", "x-www-form-urlencoded"]):
            throw.eject(ej, `Content-Type $contentType isn't a form`)
        def pairs := request.getBody().split(b`&`)
        def m := [].asMap().diverge()
        for pair in pairs:
            def [k, v] exit ej := pair.split(b`=`)
            def f(x) {return UTF8Percent.decode(x.replace(b`+`, b` `), ej)}
            m[f(k)] := f(v)
        return m.snapshot()

    var environment := [for `&&@k` => v in (safeScope) k => v]

    def formWorker(resource, request):
        def verb := request.getVerb()
        def headers := request.getHeaders()
        def body := request.getBody()

        def logger := makeLogger()

        # Patch traceln().
        environment with= ("traceln", {def t := logger.makeTrace(); &&t})
        def envHelp := tag.ul(
            [for name => &&obj in (environment.sortKeys())
             tag.li(tag.em(name, "id" => name),
                    `: ${obj._getAllegedInterface().getDocstring()}`,
             )])

        def results := escape ej {
            def =="POST" exit ej := verb
            def [=> moduleSource] | _ exit ej := getForm(request, ej)
            # Forms usually use Windows lines, but we need UNIX lines.
            def massagedSource := moduleSource.replace("\r\n", "\n")
            def secondPart := try {
                def expr := m__quasiParser.fromStr(massagedSource)
                def firstPart := try {
                    def result := eval(expr, environment)
                    [
                        tag.h2("Evaluated result"),
                        tag.p(`$result`),
                    ]
                } catch via (unsealException) [problem, backtrace] {
                    [
                        tag.h2("Error during evaluation"),
                        tag.p(`$problem`),
                        tag.h3("Backtrace"),
                        tag.ul([for frame in (backtrace) tag.li(`$frame`)]),
                    ]
                }
                firstPart + [
                    tag.h2("Kernel Source"),
                    tag.pre(expr.transform(tagExpr)),
                ]
            } catch via (unsealException) [problem, backtrace] {
                [tag.h2("Parse Error"), tag.pre(`$problem`)]
            }
            tag.div(
                tag.h2("Source"),
                tag.pre(massagedSource),
                secondPart,
                tag.h2("Trace log"),
                tag.ul([for line in (logger.getLines()) tag.li(`$line`)]),
                tag.h2("Available objects"),
                envHelp,
            )
        } catch _ {tag.div(tag.h2("Nothing posted"))}
        def report := tag.div(
            tag.h2("Resource"),
            tag.p(`$resource`),
            tag.h2("Verb"),
            tag.p(`$verb`),
            tag.h2("Headers"),
            tag.p(`$headers`),
            tag.h2("Body"),
            tag.p(`$body`))
        return smallBody(`<!DOCTYPE html>
        <meta charset="utf-8" />
        <body>
        <form action="/" method="POST">
            <textarea name="moduleSource" cols="80" rows="30"></textarea>
            <input type="submit" value="Go!" />
        </form>
        $results
        $report
        </body>
        `)

    def debug := makeDebugResource(currentRuntime)
    def root := makeResource(formWorker, [=> debug])

    def port :Int := 8080
    def endpoint := makeHTTPEndpoint(makeTCP4ServerEndpoint(port))
    def app := makeResourceApp(root)
    endpoint.listen(app)

    return 0
