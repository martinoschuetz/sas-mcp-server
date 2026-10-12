import os
import zipfile
import xml.etree.ElementTree as ET

source_dir = r'C:\Users\germsz\OneDrive - SAS\Downloads\CAF\Priya'

def analyze_zip(filepath):
    print(f"--- Analyzing {os.path.basename(filepath)} ---")
    try:
        with zipfile.ZipFile(filepath, 'r') as z:
            input_xml = next((n for n in z.namelist() if n.endswith('input.xml')), None)
            if not input_xml:
                print("No input.xml found.")
                return
            
            content = z.read(input_xml)
            root = ET.fromstring(content)
            
            # Extract basic info
            reg = root.find('Registration')
            if reg is not None:
                print("Name:", reg.findtext('Name'))
                print("KeyGroup:", reg.findtext('KeyGroup'))
                
            # Extract parameters
            params = root.findall('.//Parameter')
            display_controls = set()
            data_types = set()
            for p in params:
                dc = p.get('displayControl')
                if dc: display_controls.add(dc)
                dt = p.get('dataType')
                if dt: data_types.add(dt)
                
            print("DisplayControls:", display_controls)
            print("DataTypes:", data_types)
            
            # Extract CTX methods from interactions
            interactions = root.findall('.//Interaction')
            ctx_methods = set()
            for i in interactions:
                cond = i.findtext('Condition', '')
                actions = i.findall('.//Action')
                for a in actions:
                    act_txt = a.text or ''
                    if '#ctx.' in act_txt:
                        import re
                        methods = re.findall(r'#ctx\.(\w+)', act_txt)
                        ctx_methods.update(methods)
                if '#ctx.' in cond:
                    import re
                    methods = re.findall(r'#ctx\.(\w+)', cond)
                    ctx_methods.update(methods)
                    
            print("CTX Methods:", ctx_methods)
            
    except Exception as e:
        print(f"Error: {e}")

for f in os.listdir(source_dir):
    if f.endswith('.zip'):
        analyze_zip(os.path.join(source_dir, f))
