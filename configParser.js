// 3 args: config filename, desired action (validate or getProp), prop to get

const fs = require('fs')

const action = process.argv[2]
const moduleId = process.argv[3]

let configPath = `${__dirname}/config.json`

if (!fs.existsSync(configPath)) {
    configPath = `${__dirname}/config.default.json`
}

const config = require(configPath)

const moduleCustomization = config.moduleCustomization.filter(c => c.module === moduleId)[0] ?? {}

const getNtfyConfigsForModule = () => {
    const moduleTopic = (moduleCustomization && moduleCustomization.ntfyTopic) || moduleId
    const mainConfigName = (moduleCustomization && moduleCustomization.ntfyConfig) || config.ntfyConfig.defaultConfig
    const fallBackConfigName = (moduleCustomization && moduleCustomization.ntfyFallback) || config.ntfyConfig.fallbackConfig
    const mainConfig = mainConfigName && config.ntfyConfig.configs.filter(c => c.id === mainConfigName)[0]
    const fallbackConfig = fallBackConfigName && mainConfigName != fallBackConfigName && config.ntfyConfig.configs.filter(c => c.id === fallBackConfigName)[0]
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
            (config.ntfyConfig.modulesEnabledByDefault === true && moduleCustomization.enabled !== false)
        )
        break;
    case 'shouldCatchModuleCrashes':
        console.log(config.ntfyConfig.catchModuleCrashes === true)
        break;
    case 'getLoggerArgForModule':
        if (moduleCustomization && moduleCustomization.loggerArg) {
            console.log(moduleCustomization.loggerArg)
        }
        break;
    case 'getParserArgForModule':
        if (moduleCustomization && moduleCustomization.parserArg) {
            console.log(moduleCustomization.parserArg)
        }
        break;
    case 'getNtfyConfigsForModule':
        console.log(JSON.stringify(getNtfyConfigsForModule()))
        break;
    case 'getModuleSummaryString':
        const ntfyConfigs = process.argv[4] ? JSON.parse(process.argv[4]) : getNtfyConfigsForModule()
        console.log(`'${moduleId}' to ${ntfyConfigs.map(c => `'${c.host}/${c.topic}'`).join(' or ')}`)
        break;
    default:
        console.error(`Unknown action '${action}'!`)
        process.exit(1)
        break;
}