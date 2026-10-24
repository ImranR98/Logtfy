// Minimal HTTPS ntfy stand-in for tests. Records each request as JSON and
// always replies 200. Never reachable outside localhost.
const https = require('https')
const fs = require('fs')

const server = https.createServer(
    {
        key: fs.readFileSync(process.env.TLS_KEY),
        cert: fs.readFileSync(process.env.TLS_CERT)
    },
    (req, res) => {
        let body = ''
        req.on('data', (chunk) => {
            body += chunk
        })
        req.on('end', () => {
            fs.appendFileSync(
                process.env.REQUEST_LOG,
                JSON.stringify({
                    method: req.method,
                    url: req.url,
                    headers: req.headers,
                    body
                }) + '\n'
            )
            res.writeHead(200, { 'Content-Type': 'text/plain' })
            res.end('ok')
        })
    }
)

server.listen(0, '127.0.0.1', () => {
    fs.writeFileSync(process.env.PORT_FILE, String(server.address().port))
})
