imports
exports (main)

def [=> tag :DeepFrozen] | _ := import("lib/http/tag")
def [=> makeDebugResource :DeepFrozen,
     => makeResource :DeepFrozen,
     => makeResourceApp :DeepFrozen,
     => smallBody :DeepFrozen] | _ := import("lib/http/resource")

def formWorker(resource, request) as DeepFrozen:
    def verb := request.getVerb()
    def headers := request.getHeaders()
    def body := request.getBody()
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
    <body>
    <form action="/" method="POST">
        <textarea name="moduleSource"></textarea>
        <input type="submit" value="Go!" />
    </form>
    $report
    </body>
    `)

def main(=> currentRuntime, => makeTCP4ServerEndpoint, => unittest) as DeepFrozen:
    def [=> makeHTTPEndpoint] | _ := import("lib/http/server", [=> unittest])

    def debug := makeDebugResource(currentRuntime)
    def root := makeResource(formWorker, [=> debug])

    def port :Int := 8080
    def endpoint := makeHTTPEndpoint(makeTCP4ServerEndpoint(port))
    def app := makeResourceApp(root)
    endpoint.listen(app)

    return 0
