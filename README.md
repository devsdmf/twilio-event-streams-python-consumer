# Twilio EventStreams Python Consumer

This is a sample implementation of a Python-based consumer for Twilio's EventStreams. It contains two integration types that can be used, a webhook-based implementation that is a simple HTTP server that receives events through a WebHook sink, and an AWS Kinesis consumer that uses the Amazon KCL library to read streaming data from a Kinesis DataStream.

The idea behind this project is to act as a quickstart to start consuming those Events without need to setup a new project from scratch as the project already provides the necessarily boilerplate.

## Architecture

In order to consume a Kinesis Stream using Python, Amazon developed a wrapper application called KCL that serves as a runtime environment that stablishes the communication between your app and the DataStream. This process isn't very well documented and has some specific thins that needs to be configured both on the KCL side and also on the consumer script, so the idea of this project is to serve as a quickstart that you can just clone (or fork) and implement your own processing logic.

### KCL (MultiLangDaemon)

The KCL (Kinesis Client Library), also known as MultiLangDaemon, is a wrapper application, developed by Amazon using their SDK for Java language, that creates a runtime environment, to run a script that is aiming to connect and consume Kinesis Streams. This script can be developed in any programming language, and communicate to the wrapper using standard file descriptors (STDIN, STDOUT, STDERR), allowing the communication with the Kinesis Stream.

## Requirements

- Python 3.9+
- JRE 1.8+
- Twilio CLI 3.3+
- AWS CLI 2.2+

## Installation

### Clone the repository

The first thing you need to do, is clone the repository:

```
$ git clone git@github.com:devsdmf/twilio-event-streams-python-consumer.git
```

### Setting up a VirtualEnv

In order to isolate dependencies, we use VirtualEnv(Venv) to create a local environment to install dependencies and run the code:

```
$ cd /path/to/the/project
$ python3 -m venv .venv
$ source .venv/bin/activate
```

You can make sure that the virtual environment is activated by a `(.venv)` right before your terminal username.

### Installing Dependencies

Now you need to install the dependencies necessary to run both scripts:

```
$ cd /path/to/the/project
$ pip install -r requirements.txt
```

## Setting up Twilio EventStreams

### WebHook Sink

The first thing we need to do is to configure a sink and we need to use the Twilio CLI, so if you haven't installed or configured the CLI, please refer to [this documentation](https://www.twilio.com/docs/twilio-cli/quickstart).

With the CLI configured, you need to run the following command:

```
twilio api:events:v1:sinks:create \
--description="Webhook Sink" \
--sink-configuration='{"destination": "{URL}", "method": "POST", "batch_events": false}' \
--sink-type=webhook
```

Make sure to replace the `{URL}` content for the your application URL. If you are running it locally, with the command below, it will be `http://127.0.0.1:3000`.

After setting up the sink, you will receive as the output of the command above, a SID for the newly created sink, save it in a safe place.

The next step is to subscribe to the desired [events](https://www.twilio.com/docs/events/event-types). In order to do that, a new command must be ran on the terminal:

```
twilio api:events:v1:subscriptions:create --description "TaskRouter Events" \
--sink-sid={SINK_SID} \
--types='{"type":"com.twilio.taskrouter.reservation.created", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.reservation.accepted", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.reservation.rejected", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.reservation.timeout", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.reservation.canceled", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.reservation.wrapup", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.reservation.completed", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.reservation.failed", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.task.created", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.task.canceled", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.task.updated", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.task.deleted", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.task.completed", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.task.wrapup", "schema_version": 1}' \
--types='{"type":"com.twilio.taskrouter.worker.activity.update", "schema_version": 1}'
```

In the example above, we are subscribe to some TaskRouter events, remember to replace the `{SINK_SID}` by the value that you've got from the first command that we executed.

With that configured, we are ready to receive events over HTTP.

### Kinesis Sink

In order to configure a Kinesis Stream and subscribe to events on your Twilio account, refer to this [documentation](https://www.twilio.com/docs/events/eventstreams-quickstart). The scripts mentioned in this guide are already available on the `kinesis-consumer` folder, so all you need is to follow the guide with the available resources.

#### Setting up AWS Credentials

Before running the application, you need to setup the AWS security, which will be used by the KCL Daemon to interact with the Kinesis stream and DynamoDB(more details [here](https://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.htm://docs.aws.amazon.com/general/latest/gr/aws-security-credentials.html)). By default, the KCL uses the [DefaultAWSCredentialsProviderChain](https://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html), so make your credentials available to one of the credential providers in that provider chain. The easiest way to do this is through the following CLI command:

```
$ aws configure
```

More information about the configuration process can be found [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).

## Running the application

### WebHook Consumer

The webhook consumer is a simple HTTP server that was developed using Flask framework, in order to run it, just use the following commands:

```
$ cd /path/to/web-consumer
$ gunicorn -w 4 -b 0.0.0.0:3000 consumer:app
```

This will start the HTTP server with 4 workers that is enough for local development/testing. Any event received by the consumer will be printed in the logs.

In order to process the events, just head to the `consumer.py` script on the `web-consumer` folder and implement your own processing logic in the commented section.

### Kinesis Consumer

The Kinesis consumer is a bit more complex but not so difficult to run. The `sample.properties` file contains some configurations that can be changed on the KCL side, like the number of records to fetch on every batch, some timings and also the number of threads to process the records, feel free to tune it according to your needs.

After configuring the properties file, you can use the following command to start the KCL daemon and start to listen to the events:

```
$ cd /path/to/kinesis-consumer
$ `python bootstrap.py --print_command --java $(which java) --properties sample.properties`
```

Any events received on the DataStream will be printed in the logs. In order to process the events, just head to the `consumer.py` script on the `kinesis-consumer` folder and implement your own processing logic in the `process_record` function.

## More Resources

- [Twilio EventStreams Quickstart](https://www.twilio.com/docs/events/eventstreams-quickstart)
- [Twilio CLI Quickstart](https://www.twilio.com/docs/twilio-cli/quickstart)
- [Kinesis Data Streams](https://docs.aws.amazon.com/streams/latest/dev/introduction.html)
- [Developing a Kinesis Client Library Consumer in NodeJS](https://docs.aws.amazon.com/streams/latest/dev/kinesis-record-processor-implementation-app-nodejs.html)
- [Amazon Kinesis Client Library for Java](https://github.com/awslabs/amazon-kinesis-client)
- [Amazon Kinesis Client Library for NodeJS](https://github.com/awslabs/amazon-kinesis-client-nodejs)
- [Amazon AWS Command Line Interface CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html)

## Disclaimer

This software is to be considered "sample code", a Type B Deliverable, and is delivered "as-is" to the user. Twilio bears no responsibility to support the use or implementation of this software.

## License

This project is licensed under the [MIT license](LICENSE), that means that it is free to use, copy and modified for your own intents.

