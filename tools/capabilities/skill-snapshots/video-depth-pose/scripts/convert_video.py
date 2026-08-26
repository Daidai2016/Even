#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import cv2
import numpy as np
import torch
import torch.nn.functional as F
from transformers import AutoImageProcessor, AutoModelForDepthEstimation
from ultralytics import YOLO


DEFAULT_DEPTH_MODEL = "depth-anything/Depth-Anything-V2-Small-hf"
DEFAULT_POSE_MODEL = "yolo11n-pose.pt"

COCO_NAMES = [
    "nose",
    "left_eye",
    "right_eye",
    "left_ear",
    "right_ear",
    "left_shoulder",
    "right_shoulder",
    "left_elbow",
    "right_elbow",
    "left_wrist",
    "right_wrist",
    "left_hip",
    "right_hip",
    "left_knee",
    "right_knee",
    "left_ankle",
    "right_ankle",
]

# (start, end, BGR color)
SKELETON = [
    (0, 1, (255, 235, 40)),
    (0, 2, (255, 235, 40)),
    (1, 3, (255, 235, 40)),
    (2, 4, (255, 235, 40)),
    (5, 6, (255, 255, 255)),
    (5, 7, (255, 105, 65)),
    (7, 9, (255, 105, 65)),
    (6, 8, (65, 170, 255)),
    (8, 10, (65, 170, 255)),
    (5, 11, (255, 105, 65)),
    (6, 12, (65, 170, 255)),
    (11, 12, (255, 255, 255)),
    (11, 13, (255, 105, 65)),
    (13, 15, (255, 105, 65)),
    (12, 14, (65, 170, 255)),
    (14, 16, (65, 170, 255)),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert a human motion video into depth, pose, and combined control videos."
    )
    parser.add_argument("input", type=Path, help="Input MP4/MOV/MKV/WebM video")
    parser.add_argument("--output-dir", type=Path, required=True, help="Folder for generated artifacts")
    parser.add_argument("--fps", type=float, default=15.0, help="Output sampling FPS; clip duration is preserved")
    parser.add_argument("--max-side", type=int, default=1280, help="Maximum output frame side; aspect ratio is preserved")
    parser.add_argument("--pose-imgsz", type=int, default=640, help="YOLO pose inference size")
    parser.add_argument("--person-conf", type=float, default=0.25, help="Person detection confidence")
    parser.add_argument("--keypoint-conf", type=float, default=0.30, help="Joint drawing confidence")
    parser.add_argument("--depth-model", default=DEFAULT_DEPTH_MODEL, help="Hugging Face depth model ID or local folder")
    parser.add_argument("--pose-model", default=DEFAULT_POSE_MODEL, help="Ultralytics pose model or local weights")
    parser.add_argument("--keep-audio", action="store_true", help="Mux source audio into generated videos")
    parser.add_argument("--max-seconds", type=float, default=None, help="Process only the first N seconds (smoke tests)")
    parser.add_argument("--device", choices=["auto", "cpu", "cuda", "mps"], default="auto")
    return parser.parse_args()


def choose_device(requested: str) -> str:
    if requested != "auto":
        if requested == "cuda" and not torch.cuda.is_available():
            raise RuntimeError("CUDA was requested but is not available.")
        if requested == "mps" and not getattr(torch.backends, "mps", None):
            raise RuntimeError("MPS was requested but is not available.")
        return requested
    if torch.cuda.is_available():
        return "cuda"
    if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def even(value: int) -> int:
    return max(2, value - value % 2)


def output_size(width: int, height: int, max_side: int) -> tuple[int, int]:
    longest = max(width, height)
    if max_side > 0 and longest > max_side:
        scale = max_side / longest
        width, height = round(width * scale), round(height * scale)
    return even(width), even(height)


def resize_exact(frame: np.ndarray, width: int, height: int) -> np.ndarray:
    if frame.shape[1] == width and frame.shape[0] == height:
        return frame
    interpolation = cv2.INTER_AREA if width < frame.shape[1] else cv2.INTER_CUBIC
    return cv2.resize(frame, (width, height), interpolation=interpolation)


def new_writer(path: Path, fps: float, size: tuple[int, int]) -> cv2.VideoWriter:
    writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), fps, size)
    if not writer.isOpened():
        raise RuntimeError(f"Could not open video writer for {path}")
    return writer


def load_depth_model(model_arg: str, skill_root: Path, device: str):
    bundled = skill_root / "assets" / "models" / "depth-anything-v2-small"
    source = str(bundled) if (bundled / "config.json").exists() else model_arg
    cache_dir = skill_root / "assets" / "models" / "huggingface-cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    processor = AutoImageProcessor.from_pretrained(source, cache_dir=cache_dir)
    model = AutoModelForDepthEstimation.from_pretrained(source, cache_dir=cache_dir)
    model.eval().to(device)
    return processor, model, source


def load_pose_model(model_arg: str, skill_root: Path) -> tuple[YOLO, str]:
    model_path = Path(model_arg)
    if model_path.exists():
        return YOLO(str(model_path.resolve())), str(model_path.resolve())

    model_dir = skill_root / "assets" / "models"
    model_dir.mkdir(parents=True, exist_ok=True)
    bundled = model_dir / Path(model_arg).name
    if bundled.exists():
        return YOLO(str(bundled)), str(bundled)

    old_cwd = Path.cwd()
    try:
        os.chdir(model_dir)
        model = YOLO(Path(model_arg).name)
    finally:
        os.chdir(old_cwd)
    if bundled.exists():
        return model, str(bundled)
    return model, model_arg


@dataclass
class DepthNormalizer:
    low: float | None = None
    high: float | None = None
    momentum: float = 0.88

    def colorize(self, depth: np.ndarray) -> np.ndarray:
        frame_low, frame_high = np.percentile(depth, (2.0, 98.0))
        if self.low is None:
            self.low, self.high = float(frame_low), float(frame_high)
        else:
            self.low = self.momentum * self.low + (1.0 - self.momentum) * float(frame_low)
            self.high = self.momentum * self.high + (1.0 - self.momentum) * float(frame_high)
        denom = max(1e-6, self.high - self.low)
        normalized = np.clip((depth - self.low) / denom, 0.0, 1.0)
        normalized = np.power(normalized, 0.82)
        gray = np.round(normalized * 255.0).astype(np.uint8)
        return cv2.applyColorMap(gray, cv2.COLORMAP_TURBO)


@dataclass
class PoseSmoother:
    points: np.ndarray | None = None
    confidence: np.ndarray | None = None
    missing: np.ndarray | None = None
    smoothing: float = 0.28
    hold_frames: int = 1

    def update(self, points: np.ndarray, confidence: np.ndarray, threshold: float) -> tuple[np.ndarray, np.ndarray]:
        if self.points is None:
            self.points = points.copy()
            self.confidence = confidence.copy()
            self.missing = np.zeros(len(points), dtype=np.int32)
            return self.points.copy(), self.confidence.copy()

        for i in range(len(points)):
            if confidence[i] >= threshold:
                if self.confidence[i] >= threshold:
                    self.points[i] = self.smoothing * self.points[i] + (1.0 - self.smoothing) * points[i]
                else:
                    self.points[i] = points[i]
                self.confidence[i] = confidence[i]
                self.missing[i] = 0
            else:
                self.missing[i] += 1
                if self.missing[i] > self.hold_frames:
                    self.confidence[i] = 0.0
        return self.points.copy(), self.confidence.copy()

    def clear(self) -> None:
        if self.confidence is not None:
            self.confidence[:] = 0.0


def estimate_depth(
    frame_bgr: np.ndarray,
    processor,
    model,
    device: str,
) -> np.ndarray:
    rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
    inputs = processor(images=rgb, return_tensors="pt")
    inputs = {key: value.to(device) for key, value in inputs.items()}
    with torch.inference_mode():
        prediction = model(**inputs).predicted_depth
    prediction = F.interpolate(
        prediction.unsqueeze(1),
        size=frame_bgr.shape[:2],
        mode="bicubic",
        align_corners=False,
    ).squeeze()
    return prediction.detach().float().cpu().numpy()


def estimate_pose(
    frame_bgr: np.ndarray,
    model: YOLO,
    imgsz: int,
    person_conf: float,
    device: str,
) -> tuple[np.ndarray | None, np.ndarray | None, float, int]:
    yolo_device = 0 if device == "cuda" else device
    result = model.predict(
        frame_bgr,
        imgsz=imgsz,
        conf=person_conf,
        verbose=False,
        device=yolo_device,
    )[0]
    if result.boxes is None or result.keypoints is None or len(result.boxes) == 0:
        return None, None, 0.0, 0

    boxes = result.boxes.xyxy.detach().cpu().numpy()
    box_conf = result.boxes.conf.detach().cpu().numpy()
    areas = np.maximum(0.0, boxes[:, 2] - boxes[:, 0]) * np.maximum(0.0, boxes[:, 3] - boxes[:, 1])
    selected = int(np.argmax(areas * np.maximum(box_conf, 0.01)))
    points = result.keypoints.xy[selected].detach().cpu().numpy().astype(np.float32)
    if result.keypoints.conf is None:
        confidence = np.ones(len(points), dtype=np.float32)
    else:
        confidence = result.keypoints.conf[selected].detach().cpu().numpy().astype(np.float32)
    return points, confidence, float(box_conf[selected]), len(boxes)


def draw_skeleton(
    canvas: np.ndarray,
    points: np.ndarray | None,
    confidence: np.ndarray | None,
    threshold: float,
) -> np.ndarray:
    output = canvas.copy()
    if points is None or confidence is None:
        return output

    torso = [5, 6, 12, 11]
    if all(confidence[i] >= threshold for i in torso):
        overlay = output.copy()
        polygon = np.round(points[torso]).astype(np.int32)
        cv2.fillConvexPoly(overlay, polygon, (90, 40, 120), lineType=cv2.LINE_AA)
        output = cv2.addWeighted(overlay, 0.28, output, 0.72, 0)

    line_width = max(3, round(min(output.shape[:2]) / 150))
    joint_radius = max(4, round(min(output.shape[:2]) / 115))
    for start, end, color in SKELETON:
        if confidence[start] >= threshold and confidence[end] >= threshold:
            p1 = tuple(np.round(points[start]).astype(int))
            p2 = tuple(np.round(points[end]).astype(int))
            cv2.line(output, p1, p2, (10, 10, 10), line_width + 4, cv2.LINE_AA)
            cv2.line(output, p1, p2, color, line_width, cv2.LINE_AA)

    for index, point in enumerate(points):
        if confidence[index] < threshold:
            continue
        center = tuple(np.round(point).astype(int))
        if "left" in COCO_NAMES[index]:
            color = (255, 105, 65)
        elif "right" in COCO_NAMES[index]:
            color = (65, 170, 255)
        else:
            color = (40, 255, 210)
        cv2.circle(output, center, joint_radius + 2, (8, 8, 8), -1, cv2.LINE_AA)
        cv2.circle(output, center, joint_radius, color, -1, cv2.LINE_AA)
        cv2.circle(output, center, max(1, joint_radius // 3), (255, 255, 255), -1, cv2.LINE_AA)
    return output


def label_view(frame: np.ndarray, label: str, width: int = 250) -> np.ndarray:
    height = round(frame.shape[0] * width / frame.shape[1])
    view = cv2.resize(frame, (width, height), interpolation=cv2.INTER_AREA)
    bar = max(28, round(height * 0.075))
    cv2.rectangle(view, (0, 0), (width, bar), (10, 10, 10), -1)
    cv2.putText(
        view,
        label,
        (10, round(bar * 0.72)),
        cv2.FONT_HERSHEY_SIMPLEX,
        max(0.45, width / 520),
        (255, 255, 255),
        max(1, round(width / 250)),
        cv2.LINE_AA,
    )
    return view


def preview_panel(original: np.ndarray, depth: np.ndarray, pose: np.ndarray, combined: np.ndarray, seconds: float) -> np.ndarray:
    cells = [
        label_view(original, f"ORIGINAL  {seconds:05.2f}s"),
        label_view(depth, "DEPTH"),
        label_view(pose, "POSE"),
        label_view(combined, "DEPTH + POSE"),
    ]
    return np.vstack((np.hstack((cells[0], cells[1])), np.hstack((cells[2], cells[3]))))


def tile_previews(previews: list[np.ndarray]) -> np.ndarray:
    if not previews:
        raise RuntimeError("No preview frames were collected.")
    while len(previews) < 4:
        previews.append(previews[-1].copy())
    previews = previews[:4]
    return np.vstack((np.hstack((previews[0], previews[1])), np.hstack((previews[2], previews[3]))))


def ffmpeg_finalize(temp: Path, final: Path, source: Path, keep_audio: bool) -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        temp.replace(final)
        return

    command = [ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(temp)]
    if keep_audio:
        command += ["-i", str(source), "-map", "0:v:0", "-map", "1:a:0?"]
    command += [
        "-c:v",
        "libx264",
        "-preset",
        "fast",
        "-crf",
        "18",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
    ]
    if keep_audio:
        command += ["-c:a", "aac", "-b:a", "128k", "-shortest"]
    else:
        command += ["-an"]
    command.append(str(final))
    subprocess.run(command, check=True)
    temp.unlink(missing_ok=True)


def inspect_video(path: Path) -> dict:
    capture = cv2.VideoCapture(str(path))
    if not capture.isOpened():
        return {"exists": path.exists(), "readable": False}
    fps = float(capture.get(cv2.CAP_PROP_FPS) or 0.0)
    frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    result = {
        "exists": path.exists(),
        "readable": True,
        "width": int(capture.get(cv2.CAP_PROP_FRAME_WIDTH)),
        "height": int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT)),
        "fps": fps,
        "frames": frames,
        "duration_seconds": frames / fps if fps > 0 else None,
        "bytes": path.stat().st_size if path.exists() else 0,
    }
    capture.release()
    return result


def release_all(writers: Iterable[cv2.VideoWriter]) -> None:
    for writer in writers:
        writer.release()


def main() -> int:
    args = parse_args()
    input_path = args.input.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    if not input_path.is_file():
        raise FileNotFoundError(f"Input video not found: {input_path}")
    if args.fps <= 0:
        raise ValueError("--fps must be greater than zero")
    output_dir.mkdir(parents=True, exist_ok=True)

    started = time.perf_counter()
    skill_root = Path(__file__).resolve().parents[1]
    device = choose_device(args.device)
    if device == "cpu":
        torch.set_num_threads(max(1, min(8, (os.cpu_count() or 4) - 1)))

    capture = cv2.VideoCapture(str(input_path))
    if not capture.isOpened():
        raise RuntimeError(f"OpenCV could not read: {input_path}")
    source_width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    source_height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    source_fps = float(capture.get(cv2.CAP_PROP_FPS) or 0.0)
    source_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    if source_width <= 0 or source_height <= 0 or source_fps <= 0:
        raise RuntimeError("Input video has invalid width, height, or FPS metadata.")

    source_duration = source_frames / source_fps if source_frames > 0 else 0.0
    process_duration = source_duration
    if args.max_seconds is not None:
        process_duration = min(process_duration, max(0.0, args.max_seconds))
    target_fps = min(args.fps, source_fps)
    width, height = output_size(source_width, source_height, args.max_side)
    estimated_output_frames = max(1, math.ceil(process_duration * target_fps))

    print(f"Loading depth model: {args.depth_model}", flush=True)
    depth_processor, depth_model, resolved_depth_model = load_depth_model(
        args.depth_model, skill_root, device
    )
    print(f"Loading pose model: {args.pose_model}", flush=True)
    pose_model, resolved_pose_model = load_pose_model(args.pose_model, skill_root)

    temp_paths = {
        "depth": output_dir / "_depth_silent.mp4",
        "pose": output_dir / "_pose_silent.mp4",
        "depth_pose": output_dir / "_depth_pose_silent.mp4",
        "comparison": output_dir / "_comparison_silent.mp4",
    }
    final_paths = {
        "depth": output_dir / "depth.mp4",
        "pose": output_dir / "pose.mp4",
        "depth_pose": output_dir / "depth_pose.mp4",
        "comparison": output_dir / "comparison.mp4",
    }
    for path in [*temp_paths.values(), *final_paths.values()]:
        path.unlink(missing_ok=True)

    writers = {
        "depth": new_writer(temp_paths["depth"], target_fps, (width, height)),
        "pose": new_writer(temp_paths["pose"], target_fps, (width, height)),
        "depth_pose": new_writer(temp_paths["depth_pose"], target_fps, (width, height)),
        "comparison": new_writer(temp_paths["comparison"], target_fps, (width * 2, height)),
    }

    depth_normalizer = DepthNormalizer()
    pose_smoother = PoseSmoother()
    processed = 0
    source_index = 0
    detected = 0
    summed_pose_confidence = 0.0
    max_people = 0
    previews: list[np.ndarray] = []
    preview_markers = [0.08, 0.35, 0.62, 0.89]
    marker_index = 0
    next_sample_time = 0.0

    try:
        while True:
            ok, frame = capture.read()
            if not ok:
                break
            current_time = source_index / source_fps
            source_index += 1
            if current_time + 1e-9 < next_sample_time:
                continue
            if current_time > process_duration + 1e-9:
                break
            next_sample_time += 1.0 / target_fps

            frame = resize_exact(frame, width, height)
            raw_depth = estimate_depth(frame, depth_processor, depth_model, device)
            depth_color = depth_normalizer.colorize(raw_depth)
            points, key_conf, person_conf, people_count = estimate_pose(
                frame,
                pose_model,
                args.pose_imgsz,
                args.person_conf,
                device,
            )
            max_people = max(max_people, people_count)
            if points is not None and key_conf is not None:
                points, key_conf = pose_smoother.update(points, key_conf, args.keypoint_conf)
                detected += 1
                summed_pose_confidence += float(np.mean(key_conf))
            else:
                pose_smoother.clear()

            pose_canvas = np.full_like(frame, (7, 7, 10))
            pose_frame = draw_skeleton(pose_canvas, points, key_conf, args.keypoint_conf)
            combined = draw_skeleton(depth_color, points, key_conf, args.keypoint_conf)
            comparison = np.hstack((frame, combined))

            writers["depth"].write(depth_color)
            writers["pose"].write(pose_frame)
            writers["depth_pose"].write(combined)
            writers["comparison"].write(comparison)
            processed += 1

            progress = processed / estimated_output_frames
            if marker_index < len(preview_markers) and progress >= preview_markers[marker_index]:
                previews.append(preview_panel(frame, depth_color, pose_frame, combined, current_time))
                marker_index += 1
            if processed == 1 or processed % max(1, round(target_fps)) == 0:
                print(
                    f"Processed {processed}/{estimated_output_frames} frames "
                    f"({min(100.0, progress * 100.0):.1f}%)",
                    flush=True,
                )
    finally:
        capture.release()
        release_all(writers.values())

    if processed == 0:
        raise RuntimeError("No frames were processed.")

    for name in ("depth", "pose", "depth_pose", "comparison"):
        ffmpeg_finalize(temp_paths[name], final_paths[name], input_path, args.keep_audio)

    preview_path = output_dir / "preview_contact_sheet.jpg"
    cv2.imwrite(str(preview_path), tile_previews(previews), [cv2.IMWRITE_JPEG_QUALITY, 94])

    output_checks = {name: inspect_video(path) for name, path in final_paths.items()}
    pose_rate = detected / processed
    average_pose_confidence = summed_pose_confidence / detected if detected else 0.0
    all_outputs_good = all(
        check.get("readable")
        and check.get("frames", 0) >= max(1, processed - 2)
        and check.get("bytes", 0) > 1024
        for check in output_checks.values()
    )
    success = bool(all_outputs_good and pose_rate >= 0.70 and preview_path.exists())
    if pose_rate >= 0.95:
        quality = "excellent"
    elif pose_rate >= 0.85:
        quality = "good"
    elif pose_rate >= 0.70:
        quality = "usable"
    else:
        quality = "retry_recommended"

    report = {
        "success": success,
        "quality": quality,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "source": {
            "path": str(input_path),
            "width": source_width,
            "height": source_height,
            "fps": source_fps,
            "frames": source_frames,
            "duration_seconds": source_duration,
            "processed_duration_seconds": processed / target_fps,
        },
        "settings": {
            "output_fps": target_fps,
            "output_width": width,
            "output_height": height,
            "pose_imgsz": args.pose_imgsz,
            "person_conf": args.person_conf,
            "keypoint_conf": args.keypoint_conf,
            "device": device,
            "audio_preserved": args.keep_audio,
        },
        "models": {
            "depth": resolved_depth_model,
            "pose": resolved_pose_model,
        },
        "metrics": {
            "processed_frames": processed,
            "pose_detected_frames": detected,
            "pose_detection_rate": round(pose_rate, 6),
            "average_keypoint_confidence": round(average_pose_confidence, 6),
            "maximum_people_detected": max_people,
            "processing_seconds": round(time.perf_counter() - started, 3),
        },
        "outputs": {name: str(path) for name, path in final_paths.items()},
        "output_checks": output_checks,
        "preview": str(preview_path),
        "notes": [
            "The pose output is a COCO-17 2D body-keypoint sequence, not a true 3D character rig.",
            "Finger motion, facial expression, hair, loose clothing, and object semantics are not fully encoded.",
        ],
    }
    report_path = output_dir / "validation_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
    return 0 if success else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Cancelled.", file=sys.stderr)
        raise SystemExit(130)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
