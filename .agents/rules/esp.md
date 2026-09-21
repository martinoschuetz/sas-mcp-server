# SAS Event Stream Processing (ESP) Context Material

The following resources and documentation links represent the core context material provided for SAS Event Stream Processing (ESP). Use these resources to troubleshoot connectors, Kafka offsets, and general ESP project configurations.

## Official Latest Documentation Links (from PDFs)
The following are the permanent, latest-version links for the ESP manuals originally provided in docs/ESP:

- **espan:** [SAS Event Stream Processing: Using Streaming Analytics](https://go.documentation.sas.com/doc/en/espcdc/default/espan/titlepage.htm)
- **espca:** [SAS Event Stream Processing: Connectors and Adapters](https://go.documentation.sas.com/doc/en/espcdc/default/espca/titlepage.htm)
- **espcreatewindows:** [SAS Event Stream Processing: Using Source and Derived Windows](https://go.documentation.sas.com/doc/en/espcdc/default/espcreatewindows/titlepage.htm)
- **espex:** [SAS Event Stream Processing: Using SAS Event Stream Processing in a Kubernetes Environment](https://go.documentation.sas.com/doc/en/espcdc/default/espex/titlepage.htm)
- **espov:** [SAS Event Stream Processing: Overview](https://go.documentation.sas.com/doc/en/espcdc/default/espov/titlepage.htm)
- **esppsapi:** [SAS Event Stream Processing: Publish/Subscribe API Reference](https://go.documentation.sas.com/doc/en/espcdc/default/esppsapi/titlepage.htm)
- **espstudio:** [SAS Event Stream Processing: Using SAS Event Stream Processing Studio](https://go.documentation.sas.com/doc/en/espcdc/default/espstudio/titlepage.htm)
- **espts:** [SAS Event Stream Processing: Troubleshooting](https://go.documentation.sas.com/doc/en/espcdc/default/espts/titlepage.htm)
- **espxmllang:** [SAS Event Stream Processing: XML Language Reference for Event Stream Processing Models](https://go.documentation.sas.com/doc/en/espcdc/default/espxmllang/titlepage.htm)
- **espxmllayer:** [SAS Event Stream Processing: Using the ESP Server in an Edge Environment](https://go.documentation.sas.com/doc/en/espcdc/default/espxmllayer/titlepage.htm)

## Local Books & Reference Files
- **Kafka Consumer Script:** docs/ESP/sas-kafka-consumer.py
- **Kafka Offset Reset Script:** docs/ESP/sas-kafka-reset-offsets.py
- **ESP Full Documentation Archive:** C:\Users\germsz\OneDrive - SAS\Downloads\espdocumentation.zip

## Key Known Issues & Workarounds
- **Kafka Offset Reset Configurations:** In ESP Kafka Connectors, use smallest instead of arliest (which is used in Python kafka-python). If the consumer group (e.g. sas-consumer-germsz) already has committed offsets, uto.offset.reset=earliest will not load from the beginning. You must reset offsets via a Kafka script or use a new consumer group ID.
- **Specific Kafka Connector Document (v0.75):** [Configuring smallest vs earliest](https://go.documentation.sas.com/doc/en/espcdc/v_075/espca/p0sbfix2ql9xpln1l1x4t9017aql.htm)

## Example Projects & Templates
The official **[ESP Studio Examples Repository](https://github.com/sassoftware/esp-studio-examples)** provides ready-to-use XML templates demonstrating practical real-time stream processing use cases:
- **Practical Use Cases:** ctivitytracker, geofence, sailing, 	rades.
- **Advanced Lua & Python Integration:** Extensive examples showing how to embed Lua and Python via lua_compute, lua_connector, python_compute, python_connector, and patterns.
- **Machine Learning & Computer Vision:** Includes templates for ONNX integration (onnx_object_detection, onnx_pose_estimation, onnx_voice_transcription).
- **Streaming Analytics:** Shows how to use the Calculate/Train/Score windows for real-time algorithms like *K-Means clustering*, *Subspace Tracking (SST)*, *Support Vector Machines*, *TFIDF text mining*, and *Linear Regression*.
- **Custom Windows:** Examples like lert_suppression and vent_sorter.
