---
name: video-depth-pose
description: Convert a human motion video into a temporally aligned depth-map video, COCO body-keypoint skeleton video, combined depth-plus-skeleton control video, preview sheet, comparison video, and machine-readable validation report. Use when a user supplies MP4/MOV/MKV/WebM footage and asks for depth video, pose/keypoint extraction, skeleton binding, motion-transfer control media, or a Seedance-style action reference.
---

# Video Depth Pose

Turn one visible person's action video into reusable structural control media. Run the bundled deterministic script; do not recreate the computer-vision pipeline ad hoc.

## Workflow

On Windows, a person can also drag a video file directly onto `拖入人物视频到这里.cmd`; the output folder is created beside the input video.

1. Confirm the input is a readable video and that the main performer is visible for most of the clip.
2. Run the environment check:

```powershell
python scripts/check_environment.py
```

3. Convert the video:

```powershell
python scripts/convert_video.py "INPUT_VIDEO" --output-dir "OUTPUT_FOLDER"
```

4. Read `validation_report.json` and inspect `preview_contact_sheet.jpg`.
5. Treat the run as successful only when `success` is `true`, every expected video exists, and the preview shows the skeleton following the performer.

## Outputs

- `depth.mp4`: false-color monocular depth; warm colors are nearer.
- `pose.mp4`: COCO-17 body skeleton on black.
- `depth_pose.mp4`: skeleton over the depth map; use this as the motion/space control reference.
- `comparison.mp4`: original beside the combined control video.
- `preview_contact_sheet.jpg`: four temporal samples with original, depth, pose, and combined views.
- `validation_report.json`: source metadata, detection rate, output checks, model IDs, and success status.

## Useful options

Use 15 fps by default for a good CPU-quality balance. Preserve the clip duration even when sampling fewer frames.

```powershell
# Faster draft
python scripts/convert_video.py "INPUT_VIDEO" --output-dir "OUTPUT_FOLDER" --fps 8 --max-side 720

# Higher temporal fidelity
python scripts/convert_video.py "INPUT_VIDEO" --output-dir "OUTPUT_FOLDER" --fps 24 --max-side 1280

# Keep source audio in the derived videos
python scripts/convert_video.py "INPUT_VIDEO" --output-dir "OUTPUT_FOLDER" --keep-audio
```

Adjust `--keypoint-conf` downward only when the performer is visible but many joints are missing. Raise it when false joints appear. The largest detected person is the controlled subject; crop multi-person footage before conversion when another person is larger.

## Quality rules

- Prefer full-body footage with limited occlusion and stable exposure.
- Preserve the source aspect ratio; never stretch a portrait clip into landscape.
- Do not claim that 2D keypoints are a true 3D character rig.
- Warn that fingers, facial expression, hair, loose clothing, and object semantics are not fully represented.
- If `pose_detection_rate` is below `0.70`, report the limitation and retry with a clearer crop or a lower keypoint threshold.
