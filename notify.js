const https = require('https')

async function postData(url, data, headers = {}) {
    return new Promise((resolve, reject) => {
        const req = https.request(url, {
            method: 'POST',
            headers: { 'Content-Length': Buffer.byteLength(data), ...headers }
        }, (res) => {
            let responseData = ''
            res.on('data', (chunk) => { responseData += chunk })
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(responseData)
                } else {
                    reject(new Error(`Request failed with status code: ${res.statusCode} and message: ${responseData}`))
                }
            })
        })
        req.on('error', reject)
        req.write(data)
        req.end()
    })
}

const moduleId = process.argv[2]
const parserOutputRaw = (process.argv[3] || '').split('\n')
const ntfyConfigs = JSON.parse(process.argv[4])
const defaultPriority = process.argv[5] || ''
const defaultTags = process.argv[6] || ''
const parserOutput = {
    title: parserOutputRaw[0] || 'Logtfy Alert',
    priority: (parserOutputRaw[1] || '').length > 0 ? parserOutputRaw[1] : defaultPriority,
    tags: (parserOutputRaw[2] || '').length > 0 ? parserOutputRaw[2] : defaultTags,
    message: parserOutputRaw.slice(3).join('\n') || 'No message specified.'
}

const main = async () => {
    for (const config of ntfyConfigs) {
        try {
            const headers = { 'Content-Type': 'text/plain', 'Title': parserOutput.title }
            if (parserOutput.priority.length > 0) headers['Priority'] = parserOutput.priority
            if (parserOutput.tags.length > 0) headers['Tags'] = parserOutput.tags
            if (config.authHeader) headers['Authorization'] = config.authHeader
            const result = await postData(`${config.host}/${config.topic}`, parserOutput.message, headers)
            console.log(result)
            return
        } catch (e) {
            console.warn(`WARNING: Could not post notification for module '${moduleId}' with ntfy config ${config.id}!`)
            console.warn(e)
        }
    }
    throw new Error(`ERROR: Could not post notification for module '${moduleId}'!`)
}

main().catch(e => {
    console.error(e)
    process.exit(1)
})
