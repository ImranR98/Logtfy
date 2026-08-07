const fs = require('fs')

const action = process.argv[2]
const moduleId = process.argv[3]

let configPath = `${__dirname}/config.json`
if (!fs.existsSync(configPath)) {
    configPath = `${__dirname}/config.default.json`
}
const config = require(configPath)

const moduleCustomization = config.moduleCustomization.find(c => c.module === moduleId) ?? {}

const getNtfyConfigsForModule = () => {
    const moduleTopic = moduleCustomization.ntfyTopic || moduleId
    const mainConfigName = moduleCustomization.ntfyConfig || config.ntfyConfig.defaultConfig
    const fallbackConfigName = moduleCustomization.ntfyFallback || config.ntfyConfig.fallbackConfig
    const mainConfig = mainConfigName && config.ntfyConfig.configs.find(c => c.id === mainConfigName)
    const fallbackConfig = fallbackConfigName && mainConfigName !== fallbackConfigName && config.ntfyConfig.configs.find(c => c.id === fallbackConfigName)
    if (!mainConfig) {
        console.error(`Could not determine main ntfy config for module '${moduleId}'!`)
        process.exit(1)
    }
    const finalConfigs = [{ ...mainConfig, topic: `${mainConfig.topicPrefix || ''}${moduleTopic}` }]
    if (fallbackConfig) {
        finalConfigs.push({ ...fallbackConfig, topic: `${fallbackConfig.topicPrefix || ''}${moduleTopic}` })
    }
    return finalConfigs
}

const getModuleProp = (key) => {
    if (moduleCustomization[key]) {
        console.log(moduleCustomization[key])
    }
}

switch (action) {
    case 'isModuleEnabled':
        console.log(
            moduleCustomization.enabled === true ||
            (config.modulesEnabledByDefault === true && moduleCustomization.enabled !== false)
        )
        break;
    case 'getCrashNotificationInitialBackoffSeconds':
        console.log(config.crashNotificationInitialBackoffSeconds || 60)
        break;
    case 'getCrashNotificationMaxBackoffSeconds':
        console.log(config.crashNotificationMaxBackoffSeconds || 3600)
        break;
    case 'getLoggerArgForModule':
        getModuleProp('loggerArg')
        break;
    case 'getParserArgForModule':
        getModuleProp('parserArg')
        break;
    case 'getNtfyConfigsForModule':
        console.log(JSON.stringify(getNtfyConfigsForModule()))
        break;
    case 'getModuleSummaryString':
        const ntfyConfigs = process.argv[4] ? JSON.parse(process.argv[4]) : getNtfyConfigsForModule()
        console.log(`'${moduleId}' to ${ntfyConfigs.map(c => `'${c.host}/${c.topic}'`).join(' or ')}`)
        break;
    case 'getDefaultPriorityForModule':
        getModuleProp('defaultPriority')
        break;
    case 'getDefaultTagsForModule':
        getModuleProp('defaultTags')
        break;
    default:
        console.error(`Unknown action '${action}'!`)
        process.exit(1)
        break;
}
