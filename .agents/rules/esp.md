
# SAS Event Stream Processing (ESP) Context Material

The following resources and documentation links represent the core context material provided for SAS Event Stream Processing (ESP). Use these resources to troubleshoot connectors, Kafka offsets, and general ESP project configurations.

## Official Documentation Links
- **Kafka Connector Documentation (v0.75):** 
  [https://go.documentation.sas.com/doc/en/espcdc/v_075/espca/p0sbfix2ql9xpln1l1x4t9017aql.htm](https://go.documentation.sas.com/doc/en/espcdc/v_075/espca/p0sbfix2ql9xpln1l1x4t9017aql.htm)
  *(Focus: Configuring smallest vs arliest offsets, partitioning, and consumer groups for Kafka pub/sub connectors).*

## Local Books & Reference Files
- **ESP Connector Guide PDF:** 
  C:\Users\germsz\OneDrive - SAS\Downloads\espca_2026.08.pdf
  *(Focus: Resolving the smallest/earliest issue with Kafka connectors and loading full topic data).*
- **ESP Full Documentation Archive:** 
  C:\Users\germsz\OneDrive - SAS\Downloads\espdocumentation.zip
  *(Focus: General comprehensive ESP coding guidelines, window types, schemas, and performance tuning).*

## Key Known Issues & Workarounds
- **Kafka Offset Reset Configurations:** In ESP Kafka Connectors, use smallest instead of arliest (which is used in Python kafka-python). If the consumer group (e.g. sas-consumer-germsz) already has committed offsets, uto.offset.reset=earliest will not load from the beginning. You must reset offsets via a Kafka script or use a new consumer group ID.

