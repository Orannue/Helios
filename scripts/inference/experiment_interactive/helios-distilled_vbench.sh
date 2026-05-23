#!/usr/bin/env bash
set -euo pipefail

# Batch-generate videos with Helios-Distilled for VBench/VBench-Long standard evaluation.
# Output files are named exactly as VBench expects:
#   <original prompt>-0.mp4 ... <original prompt>-4.mp4

CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

PROMPT_FILE="${PROMPT_FILE:-vbench_prompts/all_dimension.txt}"
EXTENDED_PROMPT_FILE="${EXTENDED_PROMPT_FILE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-output_helios/vbench_all_dimension_distilled}"

# Local or Hugging Face model paths. Override these from CLI or environment.
BASE_MODEL_PATH="${BASE_MODEL_PATH:-BestWishYsh/Helios-Distilled}"
TRANSFORMER_PATH="${TRANSFORMER_PATH:-BestWishYsh/Helios-Distilled}"
LORA_PATH="${LORA_PATH:-}"
PARTIAL_PATH="${PARTIAL_PATH:-}"

NUM_SAMPLES_PER_PROMPT="${NUM_SAMPLES_PER_PROMPT:-5}"
NUM_FRAMES="${NUM_FRAMES:-1452}"
FPS="${FPS:-24}"
HEIGHT="${HEIGHT:-384}"
WIDTH="${WIDTH:-640}"
SEED="${SEED:-42}"
GUIDANCE_SCALE="${GUIDANCE_SCALE:-1.0}"
NUM_INFERENCE_STEPS="${NUM_INFERENCE_STEPS:-50}"
NUM_LATENT_FRAMES_PER_CHUNK="${NUM_LATENT_FRAMES_PER_CHUNK:-9}"
PYRAMID_STEPS=(${PYRAMID_STEPS:-2 2 2})
ENABLE_COMPILE="${ENABLE_COMPILE:-1}"
ENABLE_STAGE2="${ENABLE_STAGE2:-1}"
AMPLIFY_FIRST_CHUNK="${AMPLIFY_FIRST_CHUNK:-1}"
LOCAL_FILES_ONLY="${LOCAL_FILES_ONLY:-1}"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/inference/experiment_interactive/helios-distilled_vbench.sh [options]

Options:
  --prompt-file PATH            Original VBench prompt file used for filenames.
  --extended-prompt-file PATH   Optional aligned generation prompts, e.g. longer prompts.
                                Filenames still use --prompt-file.
  --output-dir PATH             Output directory for VBench-named mp4 files.
  --base-model-path PATH        Local or Hugging Face base model path.
  --transformer-path PATH       Local or Hugging Face transformer path.
  --lora-path PATH              Optional LoRA weights path.
  --partial-path PATH           Optional extra components path.
  --num-samples N               Samples per prompt. VBench standard expects 5.
  --num-frames N                Output video frames. Default: 1452.
  --fps N                       Output FPS. Default: 24.
  --height N                    Output height. Default: 384.
  --width N                     Output width. Default: 640.
  --seed N                      Base random seed.
  --guidance-scale N            Guidance scale. Default: 1.0.
  --num-inference-steps N       Diffusion steps. Default: 50.
  --num-latent-frames-per-chunk N
                                Helios chunk size. Default: 9.
  --pyramid-steps "A B C"       Stage2 pyramid steps. Default: "2 2 2".
  --no-stage2                   Disable --is_enable_stage2.
  --no-amplify-first-chunk      Disable --is_amplify_first_chunk.
  --no-compile                  Disable --enable_compile.
  --allow-download              Allow Hugging Face downloads if local files are missing.

Examples:
  bash scripts/inference/experiment_interactive/helios-distilled_vbench.sh \
    --base-model-path /models/Helios-Distilled \
    --transformer-path /models/Helios-Distilled \
    --num-frames 1452 \
    --output-dir output_helios/vbench_all_dimension_distilled

  bash scripts/inference/experiment_interactive/helios-distilled_vbench.sh \
    --extended-prompt-file vbench_prompts/all_dimension_longer.txt \
    --output-dir output_helios/vbench_all_dimension_distilled_longer
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --extended-prompt-file) EXTENDED_PROMPT_FILE="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --base-model-path) BASE_MODEL_PATH="$2"; shift 2 ;;
    --transformer-path) TRANSFORMER_PATH="$2"; shift 2 ;;
    --lora-path) LORA_PATH="$2"; shift 2 ;;
    --partial-path) PARTIAL_PATH="$2"; shift 2 ;;
    --num-samples) NUM_SAMPLES_PER_PROMPT="$2"; shift 2 ;;
    --num-frames) NUM_FRAMES="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --width) WIDTH="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --guidance-scale) GUIDANCE_SCALE="$2"; shift 2 ;;
    --num-inference-steps) NUM_INFERENCE_STEPS="$2"; shift 2 ;;
    --num-latent-frames-per-chunk) NUM_LATENT_FRAMES_PER_CHUNK="$2"; shift 2 ;;
    --pyramid-steps) read -r -a PYRAMID_STEPS <<< "$2"; shift 2 ;;
    --no-stage2) ENABLE_STAGE2="0"; shift ;;
    --no-amplify-first-chunk) AMPLIFY_FIRST_CHUNK="0"; shift ;;
    --no-compile) ENABLE_COMPILE="0"; shift ;;
    --allow-download) LOCAL_FILES_ONLY="0"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

CMD=(
  python infer_helios.py
  --base_model_path "$BASE_MODEL_PATH"
  --transformer_path "$TRANSFORMER_PATH"
  --sample_type "t2v"
  --prompt_txt_path "$PROMPT_FILE"
  --output_folder "$OUTPUT_DIR"
  --num_samples_per_prompt "$NUM_SAMPLES_PER_PROMPT"
  --save_with_vbench_names
  --num_frames "$NUM_FRAMES"
  --fps "$FPS"
  --height "$HEIGHT"
  --width "$WIDTH"
  --seed "$SEED"
  --guidance_scale "$GUIDANCE_SCALE"
  --num_inference_steps "$NUM_INFERENCE_STEPS"
  --num_latent_frames_per_chunk "$NUM_LATENT_FRAMES_PER_CHUNK"
  --pyramid_num_inference_steps_list "${PYRAMID_STEPS[@]}"
)

if [[ -n "$EXTENDED_PROMPT_FILE" ]]; then
  CMD+=(--extended_prompt_txt_path "$EXTENDED_PROMPT_FILE")
fi
if [[ -n "$LORA_PATH" ]]; then
  CMD+=(--lora_path "$LORA_PATH")
fi
if [[ -n "$PARTIAL_PATH" ]]; then
  CMD+=(--partial_path "$PARTIAL_PATH")
fi
if [[ "$ENABLE_STAGE2" == "1" ]]; then
  CMD+=(--is_enable_stage2)
fi
if [[ "$AMPLIFY_FIRST_CHUNK" == "1" ]]; then
  CMD+=(--is_amplify_first_chunk)
fi
if [[ "$ENABLE_COMPILE" == "1" ]]; then
  CMD+=(--enable_compile)
fi
if [[ "$LOCAL_FILES_ONLY" == "1" ]]; then
  CMD+=(--local_files_only)
fi

CUDA_VISIBLE_DEVICES="$CUDA_VISIBLE_DEVICES" "${CMD[@]}"
