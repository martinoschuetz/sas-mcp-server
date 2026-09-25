import os

in_path = r'C:\Users\germsz\OneDrive - SAS\Desktop\FQA_MCP\FQA_Users_Guide.md'
with open(in_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('G[Descriptive Analytics (Pareto, Trend, etc.)]', 'G["Descriptive Analytics (Pareto, Trend, etc.)"]')
content = content.replace('H[Predictive Analytics (Stat Driver, Trees)]', 'H["Predictive Analytics (Stat Driver, Trees)"]')
content = content.replace('F[Alerts / Emerging Issues Engine]', 'F["Alerts / Emerging Issues Engine"]')
content = content.replace('D[CAS Tables / In-Memory Data]', 'D["CAS Tables / In-Memory Data"]')
content = content.replace('J[FQA MCP Server / AI Agents]', 'J["FQA MCP Server / AI Agents"]')

# Let's also quote the other nodes just in case!
content = content.replace('E[Data Selection Engine]', 'E["Data Selection Engine"]')
content = content.replace('I[SAS Analytics for IoT UI]', 'I["SAS Analytics for IoT UI"]')
content = content.replace('A[(Warranty Claims)]', 'A[("Warranty Claims")]')
content = content.replace('B[(Product / Asset Data)]', 'B[("Product / Asset Data")]')
content = content.replace('C[(Labor / Parts Data)]', 'C[("Labor / Parts Data")]')

with open(in_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Nodes quoted successfully!")
