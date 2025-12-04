#!/usr/bin/env bash
# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

lang=pt # en de fr cy tt kab ca zh-TW it fa eu es ru tr nl eo zh-CN rw pt zh-HK cs pl uk

# train_set=train_"$(echo "${lang}" | tr - _)"
# train_dev=dev_"$(echo "${lang}" | tr - _)"
# test_set="${train_dev} test_$(echo ${lang} | tr - _)"

# asr_config=conf/tuning/train_asr_e_branchformer_e12_mlp1024_linear1024.yaml
lm_config=conf/train_lm.yaml
inference_config=conf/decode_asr.yaml
# 0.9 1.0 1.1
train_set=mupe_train
train_dev=mupe_dev
test_set=mupe_test

local_data_opts="\
  --csv_train /store/amatos/pasta/projects/metadados_/train_teste.csv \
  --csv_dev   /store/amatos/pasta/projects/metadados_/dev_teste.csv \
  --csv_test  /store/amatos/pasta/projects/metadados_/teste.csv \
  --wav_root_train /scratch/amatos/Mupe_train \
  --wav_root_dev   /scratch/amatos/Mupe_Val/validation_all_mupe \
  --wav_root_test  /scratch/amatos/Mupe_Test \
  --csv_delimiter tab \
  --train_set_name ${train_set} \
  --valid_set_name ${train_dev} \
  --test_set_names ${test_set} \
  --audio_column file_path \
  --text_column normalized_text"



# local_data_opts="\
#   --csv_train /store/amatos/pasta/projects/metadados_mupe/test_train.tsv \
#   --csv_dev   /store/amatos/pasta/projects/metadados_mupe/output_dev.csv \
#   --csv_test  /store/amatos/pasta/projects/metadados_mupe/metadata_test_mupe.csv \
#   --wav_root_train /scratch/amatos/Mupe_train \
#   --wav_root_dev   /scratch/amatos/Mupe_Val/validation_all_mupe   \
#   --wav_root_test  /scratch/amatos/Mupe_Test \
#   --csv_delimiter tab \
#   --train_set_name ${train_set} \
#   --valid_set_name ${train_dev} \
#   --test_set_names ${test_set} \
#   --audio_column file_path \
#   --text_column normalized_text"

asr_config=conf/tuning/train_asr_e_branchformer_e12_mlp1024_linear1024.yaml
if [[ "zh" == *"${lang}"* ]]; then
  nbpe=2500
elif [[ "fr" == *"${lang}"* ]]; then
  nbpe=350
elif [[ "es" == *"${lang}"* ]]; then
  nbpe=235
else
  nbpe=150
fi


./asr.sh \
  --ngpu 1 \
  --lang "${lang}" \
  --local_data_opts "${local_data_opts}" \
  --use_lm true \
  --lm_config "${lm_config}" \
  --token_type bpe \
  --nbpe $nbpe \
  --feats_type raw \
  --speed_perturb_factors "" \
  --asr_config "${asr_config}" \
  --inference_config "${inference_config}" \
  --train_set "${train_set}" \
  --valid_set "${train_dev}" \
  --test_sets "${test_set}" \
  --bpe_train_text "data/${train_set}/text" \
  --lm_train_text "data/${train_set}/text" "$@"

# ./asr.sh \
#   --ngpu 4 \
#   --lang "${lang}" \
#   --local_data_opts "${local_data_opts}" \
#   --use_lm true \
#   --lm_config "${lm_config}" \
#   --token_type bpe \
#   --nbpe $nbpe \
#   --feats_type raw \
#   --speed_perturb_factors "" \
#   --asr_config "${asr_config}" \
#   --inference_config "${inference_config}" \
#   --train_set "${train_set}" \
#   --valid_set "${train_dev}" \
#   --test_sets "${test_set}" \
#   --bpe_train_text "data/${train_set}/text" \
#   --lm_train_text "data/${train_set}/text" "$@"

# ./asr.sh \
#     --ngpu 4 \
#     --lang "${lang}" \
#     --local_data_opts "--lang ${lang}" \
#     --use_lm true \
#     --lm_config "${lm_config}" \
#     --token_type bpe \
#     --nbpe $nbpe \
#     --feats_type raw \
#     --speed_perturb_factors "0.9 1.0 1.1" \
#     --asr_config "${asr_config}" \
#     --inference_config "${inference_config}" \
#     --train_set "${train_set}" \
#     --valid_set "${train_dev}" \
#     --test_sets "${test_set}" \
#     --bpe_train_text "data/${train_set}/text" \
#     --lm_train_text "data/${train_set}/text" "$@"


# cd /store/amatos/pasta/projects/segmentation/src/espnet/egs2/commonvoice/asr1
# ./run.sh \
#   --skip_data_prep true \
#   --stage 10 \
#   --lm_exp /store/amatos/pasta/projects/segmentation/src/espnet/egs2/commonvoice/asr1/exp/lm_stats_pt_bpe150 \
#   --inference_lm valid.loss.ave.pth

#        cd /store/amatos/pasta/projects/segmentation/src/espnet/tools
#      make TH_VERSION=cpu     # or gpu, as appropriate

    #  python -c "import espnet; print(espnet.__version__)"
# python3 -c "import espnet2; print(espnet2.__file__)"


# ./run.sh \
#   --skip_data_prep true \
#   --stage 10 \
#   --lm_exp /store/amatos/pasta/projects/segmentation/src/espnet/egs2/commonvoice/asr1/exp/lm_stats_pt_bpe150 \
#   --inference_lm valid.loss.ave.pth