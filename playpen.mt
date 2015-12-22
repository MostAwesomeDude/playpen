imports
exports (main)

def [=> tag :DeepFrozen] | _ := import("lib/http/tag")
def [=> makeDebugResource :DeepFrozen,
     => makeResource :DeepFrozen,
     => makeResourceApp :DeepFrozen,
     => smallBody :DeepFrozen] | _ := import("lib/http/resource")

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
            [for name => &&obj in (environment)
             tag.li(tag.em(name),
                    `: ${obj._getAllegedInterface().getDocstring()}`,
             )])

        def results := escape ej {
            def =="POST" exit ej := verb
            def [=> moduleSource] | _ exit ej := getForm(request, ej)
            # Forms usually use Windows lines, but we need UNIX lines.
            def massagedSource := moduleSource.replace("\r\n", "\n")
            def firstPart := try {
                def result := eval(massagedSource, environment)
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
            tag.div(
                firstPart,
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
            <textarea name="moduleSource"></textarea>
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
