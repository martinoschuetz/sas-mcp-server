
with open('.agents/rules/esp.md', 'a', encoding='utf-8') as f:
    f.write('''
## Example Projects & Templates
The official **[ESP Studio Examples Repository](https://github.com/sassoftware/esp-studio-examples)** provides ready-to-use XML templates demonstrating practical real-time stream processing use cases:
- **Practical Use Cases:** ctivitytracker, geofence, sailing, 	rades.
- **Advanced Lua & Python Integration:** Extensive examples showing how to embed Lua and Python via lua_compute, lua_connector, python_compute, python_connector, and patterns.
- **Machine Learning & Computer Vision:** Includes templates for ONNX integration (onnx_object_detection, onnx_pose_estimation, onnx_voice_transcription).
- **Streaming Analytics:** Shows how to use the Calculate/Train/Score windows for real-time algorithms like *K-Means clustering*, *Subspace Tracking (SST)*, *Support Vector Machines*, *TFIDF text mining*, and *Linear Regression*.
- **Custom Windows:** Examples like lert_suppression and vent_sorter.
''')

