"""Run in a Python environment with export-requirements.txt installed.
Download provenance: tools/model_source/MODEL_CARD.md.
"""
from pathlib import Path
import subprocess
import shutil
from ultralytics import YOLO

root = Path(__file__).resolve().parents[1]
source = root / 'tools/model_source/ppe-v2.pt'
package = YOLO(str(source)).export(format='coreml', imgsz=640, nms=True, half=True)
out = root / 'build/coreml'
out.mkdir(parents=True, exist_ok=True)
subprocess.run(['xcrun', 'coremlcompiler', 'compile', str(package), str(out)], check=True)
shutil.copytree(out / 'ppe-v2.mlmodelc', root / 'ios/Runner/SafetyPPE.mlmodelc', dirs_exist_ok=True)
