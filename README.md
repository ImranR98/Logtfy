# Logtfy

Simple log monitoring service that uses [ntfy](https://ntfy.sh) for alerts.

## Details

- Logs from a specified source are continuously monitored, parsed, and used to trigger alerts that are posted to a ntfy topic.
- This is done through packages called modules - each module represents a specific source of logs.
  - For example, the `ssh_logins` module is used to monitor SSH logs and send an alert when someone logs in via SSH.
  - Modules are stored in the `modules` directory and each module must contain these 2 files:
    - `logger.sh`: Defines the log message source (continuously outputs log messages).
    - `parser.sh`: Parses an individual log and decides whether it should trigger a ntfy alert (if so, this script print a specifically formatted output containing the final alert data).
- Alerts can be sent to a user-defined ntfy server/topic, with the option to fallback to a second server/topic in case of failure.

# Usage

1. Create a copy of `config.default.json` and name it `config.json`.
2. Modify `config.json` to suit your needs.
   - This file defines your `ntfy.sh` servers (server URL, credentials, and an optional prefix to append to all topic names).
     - You can define as many servers as you want, but only 1 to 2 are used (the main server, with an optional fallback).
   - This file also defines changes to the default settings per module.
     - This includes specifying a different ntfy server (and fallback) to use, customizing the topic name, disabling modules, and adding additional data to use for log collection and parsing.
   - Other details not mentioned - most property names are self-explanatory.
3. Optionally, create a copy of `onExit.default.sh` named `onExit.sh` and customize it - this file runs when the monitoring script exits for any reason. By default, it will attempt to send a ntfy alert to your configured server.
4. If you've enabled a module that grabs logs from a Kubernetes service, you'll need to run `k8s/prep.sh`.
5. Launch the service with `run.sh`
   - Alternatively, you can use the `Dockerfile` to build and run a Docker image.
   - You can also set it up to run as a systemd service using the example service config file `logtfy.service.example`.