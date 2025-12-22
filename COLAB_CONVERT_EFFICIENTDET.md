# Convert EfficientDet-Lite2 .pb to .tflite using Google Colab

**Step-by-Step Guide for Complete Beginners**

---

## Step 1: Open Google Colab

1. Go to: https://colab.research.google.com/
2. Click **"New Notebook"** or **"File" → "New Notebook"**
3. You'll see a blank notebook with code cells

---

## Step 2: Prepare Your .pb File

Your EfficientDet-Lite2 should be in a folder structure like:

```
efficientdet-lite2/
├── saved_model.pb
└── variables/
    ├── variables.data-00000-of-00001
    └── variables.index
```

**If you only have `saved_model.pb`:**
- That's okay, we'll try to convert it
- But ideally you need the full folder with variables

**Zip your folder:**
```bash
# On your computer, zip the entire folder
zip -r efficientdet-lite2.zip efficientdet-lite2/
```

---

## Step 3: Upload to Colab

### Cell 1: Upload the zip file

```python
# Upload your model zip file
from google.colab import files
print("📤 Click 'Choose Files' and select your efficientdet-lite2.zip")
uploaded = files.upload()
```

**What to do:**
1. Copy this code into the first cell
2. Click the **Play button** (▶️) on the left
3. A **"Choose Files"** button will appear
4. Click it and select your `efficientdet-lite2.zip`
5. Wait for upload to complete (you'll see progress bar)

---

## Step 4: Unzip the Model

### Cell 2: Extract the files

```python
# Unzip the model
import zipfile
import os

# Get the uploaded filename
zip_filename = list(uploaded.keys())[0]
print(f"📦 Extracting {zip_filename}...")

# Unzip
with zipfile.ZipFile(zip_filename, 'r') as zip_ref:
    zip_ref.extractall('.')

print("✅ Extraction complete!")

# List contents to verify
print("\n📁 Files extracted:")
!ls -la
```

**What to do:**
1. Copy this into the second cell
2. Click **Play** (▶️)
3. You should see your folder listed

---

## Step 5: Install TensorFlow (if needed)

### Cell 3: Check/Install TensorFlow

```python
# Check TensorFlow version
import tensorflow as tf
print(f"✅ TensorFlow version: {tf.__version__}")

# If version is too old, upgrade
# !pip install --upgrade tensorflow
```

**What to do:**
1. Copy and run this cell
2. Should show TensorFlow 2.x (usually pre-installed in Colab)
3. If version is < 2.0, uncomment the last line and run again

---

## Step 6: Find Your Model Directory

### Cell 4: Locate the saved_model.pb

```python
# Find the saved_model.pb file
import os

def find_saved_model(root_dir='.'):
    for dirpath, dirnames, filenames in os.walk(root_dir):
        if 'saved_model.pb' in filenames:
            return dirpath
    return None

model_dir = find_saved_model()

if model_dir:
    print(f"✅ Found model at: {model_dir}")
    print(f"\n📁 Contents:")
    !ls -la {model_dir}
else:
    print("❌ saved_model.pb not found!")
    print("Please check your zip file structure")
```

**What to do:**
1. Run this cell
2. It will find your `saved_model.pb` automatically
3. Note the path shown (e.g., `./efficientdet-lite2`)

---

## Step 7: Convert to TFLite (Basic)

### Cell 5: Basic conversion

```python
import tensorflow as tf

# Use the model directory found above
saved_model_dir = model_dir  # From previous cell
output_tflite = "efficientdet-lite2.tflite"

print(f"🔄 Converting {saved_model_dir} to TFLite...")

try:
    # Create converter
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
    
    # Basic optimization for mobile
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Allow TensorFlow ops if needed
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,  # TFLite ops
        tf.lite.OpsSet.SELECT_TF_OPS     # TensorFlow ops (fallback)
    ]
    
    # Convert
    tflite_model = converter.convert()
    
    # Save
    with open(output_tflite, 'wb') as f:
        f.write(tflite_model)
    
    # Check size
    size_mb = os.path.getsize(output_tflite) / (1024 * 1024)
    
    print(f"✅ Conversion successful!")
    print(f"📦 Output: {output_tflite}")
    print(f"📊 Size: {size_mb:.2f} MB")
    
except Exception as e:
    print(f"❌ Conversion failed: {e}")
    print("\nTrying alternative method...")
```

**What to do:**
1. Run this cell
2. Wait for conversion (may take 30-60 seconds)
3. If successful, you'll see "✅ Conversion successful!"
4. If failed, continue to Step 8

---

## Step 8: Alternative Conversion (If Step 7 Failed)

### Cell 6: Conversion with Float16 quantization

```python
import tensorflow as tf

saved_model_dir = model_dir
output_tflite = "efficientdet-lite2-float16.tflite"

print(f"🔄 Converting with Float16 quantization...")

try:
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
    
    # Float16 quantization (smaller, faster, minimal accuracy loss)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    # Allow TF ops
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS
    ]
    
    # Convert
    tflite_model = converter.convert()
    
    # Save
    with open(output_tflite, 'wb') as f:
        f.write(tflite_model)
    
    size_mb = os.path.getsize(output_tflite) / (1024 * 1024)
    
    print(f"✅ Conversion successful!")
    print(f"📦 Output: {output_tflite}")
    print(f"📊 Size: {size_mb:.2f} MB (smaller due to float16)")
    
except Exception as e:
    print(f"❌ Still failed: {e}")
```

**What to do:**
1. Only run if Step 7 failed
2. This creates a smaller model with float16 precision
3. Minimal accuracy loss (~0.5%)

---

## Step 9: Verify the Model

### Cell 7: Test the converted model

```python
import tensorflow as tf
import numpy as np

# Load the TFLite model
tflite_file = "efficientdet-lite2.tflite"  # or "efficientdet-lite2-float16.tflite"

print(f"🔍 Verifying {tflite_file}...")

try:
    # Load interpreter
    interpreter = tf.lite.Interpreter(model_path=tflite_file)
    interpreter.allocate_tensors()
    
    # Get input details
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print("✅ Model loaded successfully!\n")
    
    print("📥 INPUT:")
    for i, inp in enumerate(input_details):
        print(f"   Input {i}:")
        print(f"      Shape: {inp['shape']}")
        print(f"      Type: {inp['dtype']}")
        print(f"      Name: {inp['name']}\n")
    
    print("📤 OUTPUTS:")
    for i, out in enumerate(output_details):
        print(f"   Output {i}:")
        print(f"      Shape: {out['shape']}")
        print(f"      Type: {out['dtype']}")
        print(f"      Name: {out['name']}\n")
    
    # Test inference with dummy data
    input_shape = input_details[0]['shape']
    input_data = np.random.rand(*input_shape).astype(input_details[0]['dtype'])
    
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    
    print("✅ Test inference successful!")
    print("✅ Model is ready to use!")
    
except Exception as e:
    print(f"❌ Verification failed: {e}")
```

**What to do:**
1. Run this cell
2. Check the output shapes:
   - Input should be `[1, 512, 512, 3]` or `[1, 640, 640, 3]`
   - Outputs should be 4 tensors (boxes, classes, scores, count)
3. If you see "✅ Test inference successful!" - you're good!

---

## Step 10: Download the Model

### Cell 8: Download to your computer

```python
from google.colab import files

# Download the converted model
tflite_file = "efficientdet-lite2.tflite"  # or the float16 version

print(f"📥 Downloading {tflite_file}...")
files.download(tflite_file)

print("✅ Download started! Check your browser's download folder.")
```

**What to do:**
1. Run this cell
2. Your browser will download the `.tflite` file
3. Save it to your computer

---

## Step 11: Use in Your App

### On your computer:

```bash
# Copy to your Flutter project
cp ~/Downloads/efficientdet-lite2.tflite aeye/assets/models/

# Update pubspec.yaml (already done)
# Update app_constants.dart (already done)

# Build and test
cd aeye
flutter clean
flutter pub get
flutter run
```

---

## Complete Colab Notebook (All-in-One)

If you want everything in one cell:

```python
# ========================================
# COMPLETE EFFICIENTDET CONVERSION SCRIPT
# ========================================

# 1. Upload
from google.colab import files
import zipfile
import os
import tensorflow as tf
import numpy as np

print("=" * 50)
print("EFFICIENTDET .PB TO .TFLITE CONVERTER")
print("=" * 50)

# Upload zip
print("\n📤 STEP 1: Upload your model zip file")
uploaded = files.upload()

# Unzip
print("\n📦 STEP 2: Extracting...")
zip_filename = list(uploaded.keys())[0]
with zipfile.ZipFile(zip_filename, 'r') as zip_ref:
    zip_ref.extractall('.')

# Find model
print("\n🔍 STEP 3: Finding saved_model.pb...")
def find_saved_model(root_dir='.'):
    for dirpath, dirnames, filenames in os.walk(root_dir):
        if 'saved_model.pb' in filenames:
            return dirpath
    return None

model_dir = find_saved_model()
if not model_dir:
    print("❌ ERROR: saved_model.pb not found!")
    exit()

print(f"✅ Found: {model_dir}")

# Convert
print("\n🔄 STEP 4: Converting to TFLite...")
output_tflite = "efficientdet-lite2.tflite"

try:
    converter = tf.lite.TFLiteConverter.from_saved_model(model_dir)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS
    ]
    
    tflite_model = converter.convert()
    
    with open(output_tflite, 'wb') as f:
        f.write(tflite_model)
    
    size_mb = os.path.getsize(output_tflite) / (1024 * 1024)
    print(f"✅ SUCCESS! Size: {size_mb:.2f} MB")
    
except Exception as e:
    print(f"❌ FAILED: {e}")
    exit()

# Verify
print("\n🔍 STEP 5: Verifying model...")
interpreter = tf.lite.Interpreter(model_path=output_tflite)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"Input shape: {input_details[0]['shape']}")
print(f"Number of outputs: {len(output_details)}")

# Test
input_shape = input_details[0]['shape']
input_data = np.random.rand(*input_shape).astype(input_details[0]['dtype'])
interpreter.set_tensor(input_details[0]['index'], input_data)
interpreter.invoke()

print("✅ Test inference successful!")

# Download
print("\n📥 STEP 6: Downloading...")
files.download(output_tflite)

print("\n" + "=" * 50)
print("✅ CONVERSION COMPLETE!")
print("=" * 50)
print(f"\nYour file: {output_tflite}")
print("Check your browser's download folder!")
```

---

## Troubleshooting

### Error: "No saved_model.pb found"
**Solution**: 
- Check your zip file structure
- Make sure you zipped the folder, not just the .pb file
- The structure should be: `efficientdet-lite2/saved_model.pb`

### Error: "Some ops are not supported"
**Solution**: Already handled with:
```python
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
    tf.lite.OpsSet.SELECT_TF_OPS  # This allows TF ops
]
```

### Error: "Model is too large"
**Solution**: Use float16 quantization (Step 8)

### Error: "Conversion takes too long"
**Solution**: 
- Normal for large models (2-5 minutes)
- Colab might disconnect if >10 minutes
- Try float16 quantization (faster)

---

## Expected Results

### EfficientDet-Lite2:
- **Input**: `[1, 512, 512, 3]` or `[1, 640, 640, 3]`
- **Output 0**: Boxes `[1, 25, 4]`
- **Output 1**: Classes `[1, 25]`
- **Output 2**: Scores `[1, 25]`
- **Output 3**: Count `[1]`
- **Size**: 7-8 MB (or 4-5 MB with float16)

---

## Quick Reference

### Colab Shortcuts:
- **Run cell**: `Ctrl+Enter` or `Cmd+Enter`
- **Run and move to next**: `Shift+Enter`
- **Add cell below**: `Ctrl+M B` or `Cmd+M B`
- **Delete cell**: `Ctrl+M D` or `Cmd+M D`

### Important Notes:
- ✅ Colab sessions timeout after ~12 hours
- ✅ Files are deleted when session ends
- ✅ Download your .tflite file before closing!
- ✅ Free Colab has GPU/TPU access (not needed for conversion)

---

## Summary

1. ✅ Open Google Colab
2. ✅ Upload your .pb zip file
3. ✅ Run conversion cells
4. ✅ Verify the model works
5. ✅ Download .tflite file
6. ✅ Copy to your Flutter project
7. ✅ Test in app

**Total time**: 5-10 minutes

---

## Next Steps After Conversion

1. Copy `efficientdet-lite2.tflite` to `aeye/assets/models/`
2. Update `app_constants.dart`:
   ```dart
   static const String objectDetectionModel = 'assets/models/efficientdet-lite2.tflite';
   ```
3. The code is already updated for EfficientDet format!
4. Build and test:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

**Need help?** The conversion script handles most edge cases automatically. If you still have issues, check the error message and refer to the troubleshooting section.
