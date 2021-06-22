package tasks

import (
	"github.com/input-output-hk/mantis-ops/pkg/schemas/nomad:types"
	"list"
	"strings"
)

#Mantis: types.#stanza.task & {
	#namespace:           string
	#role:                "passive" | "miner" | "backup"
	#logLevel:            "TRACE" | "DEBUG" | "INFO" | "WARN" | "ERROR" | "OFF"
	#mantisRev:           string
	#network:             string
	#networkConfig:       string
	#amountOfMorphoNodes: 5
	#loggers: {}
	#fastSync: true | *false
	#flake:    *"github:input-output-hk/mantis?rev=\(#mantisRev)#mantis" | string

	if #network == "etc" {
		#flake: "github:input-output-hk/mantis/develop#mantis"
	}

	driver: "exec"

	if #role == "miner" {
		resources: {
			cpu:    7500
			memory: 6 * 1024
		}
	}

	if #role == "passive" || #role == "backup" {
		resources: {
			cpu:    5000
			memory: 3 * 1024
		}
	}

	vault: {
		policies: ["nomad-cluster"]
		change_mode: "noop"
	}

	config: {
		flake:   #flake
		command: "/bin/mantis"
		args: ["-Dconfig.file=/local/mantis.conf", "-XX:ActiveProcessorCount=2", "-Dlogback.configurationFile=/local/logback.xml"]
	}

	if #network != "etc" {
		restart: {
			interval: "30m"
			attempts: 10
			delay:    "1m"
			mode:     "fail"
		}
	}

	env: {
		REQUIRED_PEER_COUNT: "${NOMAD_ALLOC_INDEX}"
		STORAGE_DIR:         "/local/mantis"
		NAMESPACE:           #namespace
		DAG_NAME:            "full-R23-0000000000000000"
		DAG_BUCKET:          "mantis-dag"
		MONITORING_ADDR:     "http://172.16.0.20:9000"
		AWS_DEFAULT_REGION:  "us-east-1"
	}

	#vaultPrefix: 'kv/data/nomad-cluster/\(#namespace)/mantis-%s'

	if #role == "miner" {
		template: "secrets/secret-key": {
			#prefix:     'kv/data/nomad-cluster/\(#namespace)/mantis-%s'
			change_mode: "noop"
			splay:       "15m"
			data:        """
			{{ with secret (printf "\(#vaultPrefix)/secret-key" (env "NOMAD_ALLOC_INDEX")) }}{{.Data.data.value}}{{end}}
			{{ with secret (printf "\(#vaultPrefix)/enode-hash" (env "NOMAD_ALLOC_INDEX")) }}{{.Data.data.value}}{{end}}
			"""
		}
	}

	template: "secrets/env.txt": {
		data: """
			AWS_ACCESS_KEY_ID="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_access_key_id}}{{end}}"
			AWS_SECRET_ACCESS_KEY="{{with secret "kv/data/nomad-cluster/restic"}}{{.Data.data.aws_secret_access_key}}{{end}}"
			"""
		env:         true
		change_mode: "noop"
	}

	template: "local/logback.xml": {
		data: """
		<configuration>
		
		    <property name="stdoutEncoderPattern" value="%d %-5level [%logger{36}] - %msg%n" />
		    <property name="fileEncoderPattern" value="%d [%thread] %-5level %logger{36} %X{akkaSource} - %msg%n" />
		
		    <!--read properties from application.conf-->
		    <newRule pattern="*/load" actionClass="io.iohk.ethereum.utils.LoadFromApplicationConfiguration"/>
		    <load key="logging.json-output" as="ASJSON"/>
		    <load key="logging.logs-dir" as="LOGSDIR"/>
		    <load key="logging.logs-file" as="LOGSFILENAME"/>
		    <load key="logging.logs-level" as="LOGSLEVEL"/>
		
		    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
		        <encoder>
		            <pattern>${stdoutEncoderPattern}</pattern>
		        </encoder>
		    </appender>
		
		    <appender name="STASH" class="ch.qos.logback.core.ConsoleAppender">
		        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
		            <customFields>{"hostname":"${HOSTNAME}"}</customFields>
		            <fieldNames>
		                <timestamp>timestamp</timestamp>
		                <version>[ignore]</version>
		            </fieldNames>
		        </encoder>
		    </appender>
		
		    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
		        <file>${LOGSDIR}/${LOGSFILENAME}.log</file>
		        <append>true</append>
		        <rollingPolicy class="ch.qos.logback.core.rolling.FixedWindowRollingPolicy">
		            <fileNamePattern>${LOGSDIR}/${LOGSFILENAME}.%i.log.zip</fileNamePattern>
		            <minIndex>1</minIndex>
		            <maxIndex>10</maxIndex>
		        </rollingPolicy>
		        <triggeringPolicy class="ch.qos.logback.core.rolling.SizeBasedTriggeringPolicy">
		            <maxFileSize>10MB</maxFileSize>
		        </triggeringPolicy>
		        <encoder>
		            <pattern>${fileEncoderPattern}</pattern>
		        </encoder>
		    </appender>
		
		    <appender name="METRICS" class="io.prometheus.client.logback.InstrumentedAppender" />
		
		    <root level="${LOGSLEVEL}">
		        <if condition='p("ASJSON").contains("true")'>
		            <then>
		                <appender-ref ref="STASH" />
		            </then>
		            <else>
		                <appender-ref ref="STDOUT" />
		            </else>
		        </if>
		        <appender-ref ref="FILE" />
		        <appender-ref ref="METRICS" />
		    </root>
		
		\(strings.Join(#loggerTags, "\n"))
		</configuration>
		"""

		#loggerTags: [ for class, level in #loggers {
			"    <logger name=\"\(class)\" level=\"\(level)\"/>"
		}]

		change_mode: "noop"
	}

	template: "local/mantis.conf": {
		#checkpointRange: list.Range(0, #amountOfMorphoNodes, 1)
		if #network == "testnet-internal-nomad" {
			#checkpointKeys: [ for n in #checkpointRange {
				"""
			{{- with secret "kv/data/nomad-cluster/\(#namespace)/obft-node-\(n)/obft-public-key" -}}
			"{{- .Data.data.value -}}"
			{{ end -}}
			"""
			}]
			#checkPointKeysString: strings.Join(#checkpointKeys, ",")
		}

		#extraConfig:          string | *"""
			mantis.consensus.mining-enabled = false
			"""
		#checkPointKeysString: string | *""

		if #role == "miner" {
			#extraConfig: """
			mantis = {
				node-key-file = "/secrets/secret-key"
				consensus = {
					mining-enabled = true
					coinbase = "{{ with secret (printf "\(#vaultPrefix)/coinbase" (env "NOMAD_ALLOC_INDEX")) }}{{.Data.data.value}}{{end}}"
				}
			}
			"""
		}
		if #role == "passive" {
			if #network == "etc" {
				#extraConfig: """
					mantis.consensus.mining-enabled = false
					mantis.sync.min-peers-to-choose-pivot-block = 1
					"""
			}
		}

		change_mode: "noop"
		splay:       "1h"
		data:        """
		logging.json-output = false
		logging.logs-file = "logs"
		logging.logs-level = "\(#logLevel)"

		include "/conf/base.conf"
		include "/conf/\(#network).conf"

		mantis = {
			blockchains.testnet-internal-nomad = {
			  custom-genesis-file = "/local/genesis.json"
			  allowed-miners = []
			  checkpoint-public-keys = [
			    \(#checkPointKeysString)
			  ]
			}

			client-id = "mantis-\(#role)-{{env "NOMAD_ALLOC_INDEX"}}"
			datadir = "/local/mantis"
			ethash.ethash-dir = "/local/ethash"

			sync.do-fast-sync = \(#fastSync)

			metrics.enabled = true
			metrics.port = {{ env "NOMAD_PORT_metrics" }}

			network.rpc.http.interface = "0.0.0.0"
			network.rpc.http.port = {{ env "NOMAD_PORT_rpc" }}

			network.server-address.port = {{ env "NOMAD_PORT_server" }}
			network.server-address.interface = "0.0.0.0"

			network.discovery.discovery-enabled = true
			network.discovery.host = "172.16.0.20"
			network.discovery.port = {{ env "NOMAD_PORT_discovery" }}
		}

		akka.loglevel = "DEBUG"

		\(#extraConfig)
		\(#networkConfig)
		"""
	}

	if #network != "etc" {
		template: "local/genesis.json": {
			change_mode: "noop"
			data:        """
		{{- with secret "kv/nomad-cluster/\(#namespace)/genesis" -}}
		{{.Data.data | toJSON }}
		{{- end -}}
		"""
		}
	}
}
