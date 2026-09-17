# On-device PPE model

The iOS app uses Apple Vision and Core ML for local PPE inference. This path requires neither a Roboflow account nor a cloud API key.

## Provenance

The source model is **SafetyVision YOLOv8s PPE v2**, published by Ayush Gupta at `ayushgupta7777/safetyvision-yolov8`. The original [model card](../tools/model_source/MODEL_CARD.md) is retained unchanged as third-party documentation. Its training and evaluation claims belong to the upstream project, not to SafetyLens field validation.

The model has 13 classes including Person, Hardhat, Safety Vest, Gloves, Goggles, Mask and corresponding missing-equipment classes. The app evaluates the configured PPE subset; it does not claim every upstream class is a validated product feature.

## Export

The bundled Core ML model uses a 640-pixel input, FP16 weights and non-maximum suppression. It is approximately 21 MB. Apple Vision provides an additional person-detection path when needed.

To reproduce the conversion, install `tools/model_source/export-requirements.txt` in a separate Python environment, obtain the upstream `v2/best.pt` weights as `tools/model_source/ppe-v2.pt`, then run:

```sh
python tools/export_coreml.py
```

The script exports a Core ML package, compiles it with Xcode tooling and copies it into `ios/Runner/SafetyPPE.mlmodelc`. Training checkpoints and intermediate exports are excluded from this repository; the compiled runtime model is included.

## Runtime

Raw camera frames pass through a 500 ms single-flight gate, then a Flutter platform channel to `CVPixelBuffer`, Vision and Core ML. Predictions return to Dart for PPE association, requirements, risk evaluation and event persistence. Continuous scanning does not save photographs or repeatedly compress JPEG.

## Limitations

Crowded scenes, small subjects, occlusion, glare and motion blur affect results. The upstream model card documents weak classes and training bias. No representative site evaluation has yet established accuracy for this iPhone application. Test fixtures demonstrate operation, not a field accuracy percentage.

## License

The upstream weights are identified as AGPL-3.0. Retain the [license](licenses/AGPL-3.0.txt) and model attribution when redistributing. Original application code has no separate license grant in this submission.
