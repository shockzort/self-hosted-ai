SHELL := /usr/bin/env bash

.PHONY: init preflight start start-cpu stop logs smoke pull-llm workflows custom-nodes models model-files dashboards bootstrap open-webui-signup update config

init:
	./scripts/init.sh

preflight:
	./scripts/preflight.sh

start:
	./scripts/start.sh

start-cpu:
	./scripts/start-cpu.sh

stop:
	./scripts/stop.sh

logs:
	./scripts/logs.sh

smoke:
	./scripts/smoke-test.sh

pull-llm:
	./scripts/pull-ollama-models.sh

workflows:
	./scripts/install-comfy-workflows.sh starter

custom-nodes:
	./scripts/install-comfy-custom-nodes.sh list

models:
	./scripts/download-comfy-models.sh list

model-files:
	./scripts/download-comfy-workflow-models.sh starter

dashboards:
	./scripts/generate-grafana-dashboards.py

bootstrap:
	./scripts/bootstrap-inference.sh starter

open-webui-signup:
	./scripts/open-webui-enable-signup.sh

update:
	./scripts/update-images.sh

config:
	./scripts/compose.sh config
