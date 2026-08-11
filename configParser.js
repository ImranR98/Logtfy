const fs = require('fs')

const action = process.argv[2]
const moduleId = process.argv[3]
const instanceName = process.argv[4] || ''

let configPath = `${__dirname}/config.json`
if (!fs.existsSync(configPath)) {
    configPath = `${__dirname}/config.default.json`
}
const config = require(configPath)

const moduleCustomization = config.moduleCustomization.find(c => c.module === moduleId) ?? {}
const moduleInstances = moduleCustomization.moduleInstances || []
const isInstance = moduleInstances.length > 0 && instanceName.length > 0
const moduleInstance = isInstance ? moduleInstances.find(i => i.name === instanceName) ?? {} : {}

const effectiveCustomization = isInstance ? moduleInstance : moduleCustomization

const getProp = (key) => {
    const value = effectiveCustomization[key] ?? (isInstance ? moduleCustomization[key] : undefined)
    if (value !== undefined && value !== null) {
        console.log(value)
    }
}

const getNtfyConfigsForModule = () => {
    const moduleTopic = effectiveCustomization.ntfyTopic || moduleCustomization.ntfyTopic || (isInstance ? `${moduleId}_${instanceName}` : moduleId)
    const mainConfigName = effectiveCustomization.ntfyConfig || moduleCustomization.ntfyConfig || config.ntfyConfig.defaultConfig
    const fallbackConfigName = effectiveCustomization.ntfyFallback || moduleCustomization.ntfyFallback || config.ntfyConfig.fallbackConfig
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

switch (action) {
    case 'isModuleEnabled':
        console.log(
            moduleCustomization.enabled === true ||
            (config.modulesEnabledByDefault === true && moduleCustomization.enabled !== false)
        )
        break;
    case 'isModuleInstanceEnabled':
        const moduleEnabled =
            moduleCustomization.enabled === true ||
            (config.modulesEnabledByDefault === true && moduleCustomization.enabled !== false)
        console.log(moduleInstance.enabled === true || (moduleEnabled && moduleInstance.enabled !== false))
        break;
    case 'listModuleInstances':
        for (const instance of moduleInstances) {
            if (instance.name) {
                console.log(instance.name)
            }
        }
        break;
    case 'getCrashNotificationInitialBackoffSeconds':
        console.log(config.crashNotificationInitialBackoffSeconds || 60)
        break;
    case 'getCrashNotificationMaxBackoffSeconds':
        console.log(config.crashNotificationMaxBackoffSeconds || 3600)
        break;
    case 'getLoggerArgForModule':
        getProp('loggerArg')
        break;
    case 'getParserArgForModule':
        getProp('parserArg')
        break;
    case 'getNtfyConfigsForModule':
        console.log(JSON.stringify(getNtfyConfigsForModule()))
        break;
    case 'getModuleSummaryString':
        const ntfyConfigs = process.argv[5] ? JSON.parse(process.argv[5]) : getNtfyConfigsForModule()
        const displayName = isInstance ? `${moduleId}/${instanceName}` : moduleId
        console.log(`'${displayName}' to ${ntfyConfigs.map(c => `'${c.host}/${c.topic}'`).join(' or ')}`)
        break;
    case 'getDefaultPriorityForModule':
        getProp('defaultPriority')
        break;
    case 'getDefaultTagsForModule':
        getProp('defaultTags')
        break;
    default:
        console.error(`Unknown action '${action}'!`)
        process.exit(1)
        break;
}
