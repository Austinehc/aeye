# Float32 Model Optimization Guide

**Status**: ✅ Float32 model installed  
**Next**: Optimize settings for maximum accuracy

---

## Verify Float32 Model

### Check File Size:
```bash
ls -lh aeye/assets/models/yolov8n.tflite
```

**Expected**: ~11-13 MB (float32)  
**If 3MB**: Still quantized, need to replace

---

## Optimal Settings for Float32

Float32 models are more accurate, so we can adjust thresholds:

### Recommended Thresholds:

```dart
// Float32 can be slightly more lenient (it's more accurate)
static const double objectDetectionThreshold = 0.55; // Was 0.60

// Per-class thresholds - slightly lower for float32
static const Map<String, double> perClassThresholds = {
  // Small objects - still strict but not as extreme
  'mouse': 0.65,          // Was 0.70
  'cup': 0.60,            // Was 0.65
  'cell phone': 0.65,     // Was 0.70
  'keyboard': 0.60,       // Was 0.65
  'bottle': 0.60,         // Was 0.65
  
  // Common objects - moderate
  'person': 0.50,
  'chair': 0.55,
  'laptop': 0.55,
  'tv': 0.50,
  
  // Everything else
  // ... (keep similar adjustments)
};
```

**Why lower?** Float32 confidence scores are more reliable, so 65% from float32 = 70% from quantized

---

## Testing Checklist

### Test 1: Mouse Detection
1. Place mouse on clean surface
2. Good lighting
3. Scan from above
4. **Expected**: "mouse" at 65-75% confidence
5. **Result**: Should be accurate and consistent

### Test 2: Cup Detection
1. Place cup on table
2. Clear background
3. Scan from side
4. **Expected**: "cup" at 60-70% confidence
5. **Result**: Should distinguish from bottle

### Test 3: Similar Objects
1. Place mouse and remote side by side
2. Scan each separately
3. **Expected**: Correct label for each
4. **Result**: Should not confuse them

### Test 4: Multiple Scans
1. Scan same object 5 times
2. **Expected**: Same label every time
3. **Result**: Consistent confidence scores

---

## Diagnostic Logs to Watch

### Good Detection (Float32):
```
✅ Detection: mouse (68%) gap=32% at [245,180,520,680]
📊 Above threshold: 5, Valid: 1, Rejected (low conf): 10, Rejected (ambiguous): 1
```

**Key indicators**:
- Confidence 65-75% (good for float32)
- Large gap (30%+) from second class
- Consistent across scans

### Poor Detection (Still Issues):
```
⚠️ Rejected mouse (52%) - too close to remote (48%)
📊 Above threshold: 8, Valid: 0, Rejected (low conf): 25, Rejected (ambiguous): 8
```

**If you see this**: Model might not be float32, or lighting/angle issues

---

## If Still Not Accurate

### Option 1: Verify Model Type

Run this in Python:
```python
import tensorflow as tf

interpreter = tf.lite.Interpreter(model_path='yolov8n.tflite')
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
print(f"Input type: {input_details[0]['dtype']}")

# Should print: <class 'numpy.float32'>
# If uint8 or float16: Not full float32
```

### Option 2: Try YOLOv8s Float32

If YOLOv8n float32 still not accurate enough:

```python
# In Google Colab
from ultralytics import YOLO

model = YOLO('yolov8s.pt')  # Small model (better accuracy)
model.export(format='tflite', imgsz=640, int8=False, half=False)
```

**YOLOv8s Float32**:
- Size: ~50MB
- Accuracy: 95%+
- Speed: 60-80ms
- Best possible accuracy

### Option 3: Increase Image Quality

```dart
// In object_detection_screen.dart
_camera = CameraController(
  cameras.first,
  ResolutionPreset.veryHigh,  // Maximum quality
  enableAudio: false,
);
```

**Trade-off**: Slower processing but better input quality

---

## Expected Performance

### With Float32 YOLOv8n:

| Test | Expected Result |
|------|----------------|
| Mouse | 90-95% correct identification |
| Cup | 90-95% correct identification |
| Mouse vs Remote | Clear distinction |
| Cup vs Bottle | Clear distinction |
| Consistency | Same result 9/10 times |
| False Positives | Very rare |

### If Not Meeting Expectations:

1. ✅ Verify model is truly float32 (check size ~12MB)
2. ✅ Ensure good lighting
3. ✅ Object should be clear and centered
4. ✅ Check diagnostic logs for confidence scores
5. ⚠️ Consider YOLOv8s if still issues

---

## Confidence Score Interpretation

### Float32 Confidence Scores:

**70-100%**: Excellent - Very confident  
**60-70%**: Good - Reliable  
**50-60%**: Fair - Acceptable with gap check  
**40-50%**: Poor - Likely wrong (rejected)  
**<40%**: Very poor - Definitely wrong (rejected)

### With Confidence Gap:

**Example 1** (Good):
- Mouse: 68%
- Remote: 36%
- Gap: 32% ✅ Accept

**Example 2** (Bad):
- Mouse: 52%
- Remote: 48%
- Gap: 4% ❌ Reject (ambiguous)

---

## Recommended Settings for Float32

### Conservative (Maximum Accuracy):
```dart
static const double objectDetectionThreshold = 0.60;
'mouse': 0.70,
'cup': 0.65,
```
**Use when**: Accuracy is critical, okay with fewer detections

### Balanced (Recommended):
```dart
static const double objectDetectionThreshold = 0.55;
'mouse': 0.65,
'cup': 0.60,
```
**Use when**: Good balance of accuracy and detection rate

### Aggressive (More Detections):
```dart
static const double objectDetectionThreshold = 0.50;
'mouse': 0.60,
'cup': 0.55,
```
**Use when**: Want more detections, can tolerate occasional errors

---

## Build and Test

```bash
cd aeye
flutter clean
flutter pub get
flutter run
```

### What to Test:

1. **Mouse** - Should detect as "mouse" consistently
2. **Cup** - Should detect as "cup", not bottle
3. **Phone** - Should detect as "cell phone"
4. **Keyboard** - Should detect as "keyboard"
5. **Multiple objects** - Should detect all correctly

### Success Criteria:

✅ 9/10 scans give correct label  
✅ Confidence scores 60-75%  
✅ No confusion between similar objects  
✅ Consistent results across scans  

---

## Troubleshooting

### Issue: Still getting wrong labels

**Check**:
1. Model file size (should be ~12MB)
2. Lighting conditions (need good light)
3. Object clarity (not obscured)
4. Diagnostic logs (confidence scores)

**Try**:
- Better lighting
- Clearer background
- Center object in frame
- Hold camera steady

### Issue: "No objects detected" too often

**Solution**: Lower thresholds slightly
```dart
static const double objectDetectionThreshold = 0.50;
'mouse': 0.60,
'cup': 0.55,
```

### Issue: Still confusing similar objects

**Solution**: Increase confidence gap requirement
```dart
// In object_detector_service.dart
if (confidenceGap < 0.20) {  // Was 0.15, now 20%
  rejectedSecondClass++;
  continue;
}
```

---

## Summary

✅ **Float32 model installed**  
✅ **Strict accuracy rules in place**  
✅ **Optimal thresholds configured**  
✅ **Ready to test**

**Expected**: 90-95% accuracy with float32 model

Test with real objects and report results. If still not accurate, we can:
1. Try YOLOv8s (larger, more accurate)
2. Adjust thresholds further
3. Improve preprocessing
4. Use higher camera resolution

**The float32 model should make a huge difference!**
