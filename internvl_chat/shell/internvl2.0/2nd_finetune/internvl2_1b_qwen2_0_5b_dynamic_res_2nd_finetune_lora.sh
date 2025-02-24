set -x

GPUS=${GPUS:-2}
USE_LLM_LORA=${USE_LLM_LORA:-0}
USE_BACKBONE_LORA=${USE_BACKBONE_LORA:-0}
BATCH_SIZE=${BATCH_SIZE:-1}
PER_DEVICE_BATCH_SIZE=${PER_DEVICE_BATCH_SIZE:-1}
GRADIENT_ACC=$((BATCH_SIZE / PER_DEVICE_BATCH_SIZE / GPUS))
OUTPUT_DIR=${OUTPUT_DIR:-'work_dirs/lora_weights'}
NUM_EPOCHS=${NUM_EPOCHS:-1}

export PYTHONPATH="${PYTHONPATH}:$(pwd)"
export MASTER_PORT=34229
export TF_CPP_MIN_LOG_LEVEL=3
export LAUNCHER=pytorch

# OUTPUT_DIR='work_dirs/internvl_chat_v2_0/internvl2_1b_qwen2_0_5b_dynamic_res_2nd_finetune_lora'
# OUTPUT_DIR='work_dirs/lora_epochs_25'


if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
fi

# number of gpus: 2
# batch size per gpu: 4
# gradient accumulation steps: 2
# total batch size: 16
# epoch: 1
torchrun \
  --nnodes=1 \
  --node_rank=0 \
  --master_addr=127.0.0.1 \
  --nproc_per_node=${GPUS} \
  --master_port=${MASTER_PORT} \
  internvl/train/internvl_chat_finetune.py \
  --model_name_or_path "./pretrained/InternVL2_1B" \
  --conv_style "Hermes-2" \
  --output_dir ${OUTPUT_DIR} \
  --meta_path "./shell/data/tcga_kirc.json"\
  --overwrite_output_dir True \
  --force_image_size 224 \
  --max_dynamic_patch 6 \
  --down_sample_ratio 0.5 \
  --drop_path_rate 0.0 \
  --freeze_llm True \
  --freeze_mlp False \
  --freeze_backbone True \
  --use_llm_lora ${USE_LLM_LORA} \
  --use_backbone_lora ${USE_BACKBONE_LORA}\
  --vision_select_layer -1 \
  --dataloader_num_workers 4 \
  --bf16 True \
  --num_train_epochs ${NUM_EPOCHS} \
  --per_device_train_batch_size ${PER_DEVICE_BATCH_SIZE} \
  --gradient_accumulation_steps ${GRADIENT_ACC} \
  --evaluation_strategy "no" \
  --save_strategy "steps" \
  --save_steps 200 \
  --save_total_limit 1 \
  --learning_rate 4e-5 \
  --weight_decay 0.01 \
  --warmup_ratio 0.03 \
  --lr_scheduler_type "cosine" \
  --logging_steps 1 \
  --max_seq_length 4096 \
  --do_train True \
  --grad_checkpoint True \
  --group_by_length True \
  --dynamic_image_size True \
  --use_thumbnail True \
  --ps_version 'v2' \
  --deepspeed "zero_stage1_config.json" \
  --report_to "tensorboard" \
  --vision_path "internvl/model/internvl_chat/virchow.py"\
  2>&1 | tee -a "${OUTPUT_DIR}/training_log.txt"
