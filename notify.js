const https = require('https')

async function postData(url, data, headers = {}) {
    return new Promise((resolve, reject) => {
        const urlObject = new URL(url)
        const options = {
            hostname: urlObject.hostname,
            port: urlObject.port || 443,
            path: urlObject.pathname + urlObject.search,
            method: 'POST',
            headers: {
                'Content-Length': Buffer.byteLength(data),
                ...headers
            }
        }
        const req = https.request(options, (res) => {
            let responseData = ''
            res.on('data', (chunk) => {
                responseData += chunk
            })
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(responseData)
                } else {
                    reject(new Error(`Request failed with status code: ${res.statusCode} and message: ${responseData}`))
                }
            })
        })
        req.on('error', (e) => {
            reject(e)
        })
        req.write(data)
        req.end()
    })
}


const moduleId = process.argv[2]
const parserOutputRaw = process.argv[3].split('\n')
const parserOutput = {
    title: parserOutputRaw[0] || 'Logtfy Alert',
    priority: parserOutputRaw[1] || '',
    tags: parserOutputRaw[2] || '',
    message: parserOutputRaw.slice(3).join('\n')
}
if (parserOutput.message.length == 0) {
    parserOutput.message = 'No message specified.'
}
const ntfyConfigs = JSON.parse(process.argv[4])


const main = async () => {
    let didPost = false
    for (let i = 0; i < ntfyConfigs.length && !didPost; i++) {
        try {
            const headers = {
                'Content-Type': 'text/plain',
                'Title': parserOutput.title,
            }
            if (parserOutput.priority.length > 0) {
                headers['Priority'] = parserOutput.priority.toString()
            }
            if (parserOutput.tags.length > 0) {
                headers['Tags'] = parserOutput.tags.toString()
            }
            if (ntfyConfigs[i].authHeader) {
                headers['Authorization'] = ntfyConfigs[i].authHeader
            }
            const result = await postData(
                `${ntfyConfigs[i].host}/${ntfyConfigs[i].topic}`,
                parserOutput.message,
                headers
            )
            console.log(result)
            didPost = true
        } catch (e) {
            console.warn(`WARNING: Could not post notification for module '${moduleId}' with ntfy config ${ntfyConfigs[i].id}!`)
            console.warn(e)
        }
    }
    if (!didPost) {
        throw new Error(`ERROR: Could not post notification for module '${moduleId}'! Parsed log: ${JSON.stringify(parserOutput)}`)
    }
}

main().catch(e => {
    console.error(e)
    process.exit(1)
})