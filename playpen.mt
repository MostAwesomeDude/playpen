imports
exports (main)

def [=> tag :DeepFrozen] | _ := import("lib/http/tag")
def [=> makeDebugResource :DeepFrozen,
     => makeResource :DeepFrozen,
     => makeResourceApp :DeepFrozen,
     => smallBody :DeepFrozen] | _ := import("lib/http/resource")

def main(=> currentRuntime, => makeTCP4ServerEndpoint, => unittest) as DeepFrozen:
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

    def formWorker(resource, request):
        def verb := request.getVerb()
        def headers := request.getHeaders()
        def body := request.getBody()
        def form := escape ej {getForm(request, ej)} catch _ {null}
        def report := tag.div(
            tag.h2("Resource"),
            tag.p(`$resource`),
            tag.h2("Verb"),
            tag.p(`$verb`),
            tag.h2("Headers"),
            tag.p(`$headers`),
            tag.h2("Body"),
            tag.p(`$body`),
            tag.h2("Body as Form"),
            tag.p(`$form`))
        return smallBody(`<!DOCTYPE html>
        <body>
        <form action="/" method="POST">
            <textarea name="moduleSource"></textarea>
            <input type="submit" value="Go!" />
        </form>
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
