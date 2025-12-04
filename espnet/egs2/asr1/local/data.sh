#!/usr/bin/env bash

# Copyright 2020 Johns Hopkins University (Shinji Watanabe)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

. ./path.sh || exit 1;
. ./cmd.sh || exit 1;
. ./db.sh || exit 1;

# general configuration
stage=0       # start from 0 if you need to start from data preparation
stop_stage=100
SECONDS=0
lang=pt # en de fr cy tt kab ca zh-TW it fa eu es ru tr nl eo zh-CN rw pt zh-HK cs pl uk

# Custom CSV mode (optional) - defaults must be set BEFORE parse_options.sh
csv_train=/store/amatos/pasta/projects/metadados_/train_teste.csv
csv_dev=/store/amatos/pasta/projects/metadados_/dev_teste.csv
csv_test=/store/amatos/pasta/projects/metadados_/teste.csv
wav_root=
wav_root_train=/scratch/amatos/Mupe_train
wav_root_dev=/scratch/amatos/Mupe_Val/validation_all_mupe
wav_root_test=/scratch/amatos/Mupe_Test
csv_delimiter='\t'
audio_column=file_path
text_column=normalized_text
id_column=speaker_code
train_set_name=mupe_train
valid_set_name=mupe_dev
test_set_names=mupe_test
strip_dir_levels=0

 . utils/parse_options.sh || exit 1;

# base url for downloads.
# Deprecated url:https://voice-prod-bundler-ee1969a6ce8178826482b88e843c335139bd3fb4.s3.amazonaws.com/cv-corpus-3/$lang.tar.gz
data_url=https://voice-prod-bundler-ee1969a6ce8178826482b88e843c335139bd3fb4.s3.amazonaws.com/cv-corpus-5.1-2020-06-22/${lang}.tar.gz

log() {
    local fname=${BASH_SOURCE[1]##*/}
    echo -e "$(date '+%Y-%m-%dT%H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}

mkdir -p ${COMMONVOICE}
if [ -z "${COMMONVOICE}" ]; then
    log "Fill the value of 'COMMONVOICE' of db.sh"
    exit 1
fi

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

train_set=train_"$(echo "${lang}" | tr - _)"
train_dev=dev_"$(echo "${lang}" | tr - _)"
test_set=test_"$(echo "${lang}" | tr - _)"

log "data preparation started"

# If CSV mode is enabled, bypass CommonVoice download/prep and build from CSVs
if [ -n "${csv_train}" ] || [ -n "${csv_dev}" ] || [ -n "${csv_test}" ]; then
    log "CSV mode detected. Preparing data dirs from CSV(s)."
    # Allow overriding set names
    if [ -n "${train_set_name}" ]; then train_set="${train_set_name}"; fi
    if [ -n "${valid_set_name}" ]; then train_dev="${valid_set_name}"; fi
    if [ -n "${test_set_names}" ]; then test_set="${test_set_names}"; fi

    if [ -n "${csv_train}" ]; then
        log "Preparing train set: data/${train_set} from ${csv_train}"
        _strip="${strip_dir_levels}"
        if [ -n "${strip_dir_levels_train:-}" ]; then _strip="${strip_dir_levels_train}"; fi
        python3 local/prepare_from_csv.py \
            --csv "${csv_train}" \
            --data-dir "data/${train_set}" \
            --wav-root "${wav_root_train:-${wav_root}}" \
            --delimiter "${csv_delimiter}" \
            --strip_dir_levels "${_strip}" \
            ${audio_column:+--audio-column "${audio_column}"} \
            ${text_column:+--text-column "${text_column}"} \
            ${id_column:+--id-column "${id_column}"}
        utils/fix_data_dir.sh data/${train_set}
    fi
    if [ -n "${csv_dev}" ]; then
        log "Preparing dev set: data/${train_dev} from ${csv_dev}"
        _strip="${strip_dir_levels}"
        if [ -n "${strip_dir_levels_dev:-}" ]; then _strip="${strip_dir_levels_dev}"; fi
        python3 local/prepare_from_csv.py \
            --csv "${csv_dev}" \
            --data-dir "data/${train_dev}" \
            --wav-root "${wav_root_dev:-${wav_root}}" \
            --delimiter "${csv_delimiter}" \
            --strip_dir_levels "${_strip}" \
            ${audio_column:+--audio-column "${audio_column}"} \
            ${text_column:+--text-column "${text_column}"} \
            ${id_column:+--id-column "${id_column}"}
        utils/fix_data_dir.sh data/${train_dev}
    fi
    if [ -n "${csv_test}" ]; then
        # test_set can contain multiple names; if multiple CSVs are needed,
        # call this script multiple times via post_process_local_data_opts.
        log "Preparing test set: data/${test_set} from ${csv_test}"
        _strip="${strip_dir_levels}"
        if [ -n "${strip_dir_levels_test:-}" ]; then _strip="${strip_dir_levels_test}"; fi
        python3 local/prepare_from_csv.py \
            --csv "${csv_test}" \
            --data-dir "data/${test_set}" \
            --wav-root "${wav_root_test:-${wav_root}}" \
            --delimiter "${csv_delimiter}" \
            --strip_dir_levels "${_strip}" \
            ${audio_column:+--audio-column "${audio_column}"} \
            ${text_column:+--text-column "${text_column}"} \
            ${id_column:+--id-column "${id_column}"}
        utils/fix_data_dir.sh data/${test_set}
    fi
    log "CSV mode preparation finished."
    log "Successfully finished. [elapsed=${SECONDS}s]"
    exit 0
fi

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    log "stage1: Download data to ${COMMONVOICE}"
    log "The default data of this recipe is from commonvoice 5.1, for newer version, you need to register at \
         https://commonvoice.mozilla.org/"
    local/download_and_untar.sh ${COMMONVOICE} ${data_url} ${lang}.tar.gz
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    log "stage2: Preparing data for commonvoice"
    ### Task dependent. You have to make data the following preparation part by yourself.
    for part in "validated" "test" "dev"; do
        # use underscore-separated names in data directories.
        local/data_prep.pl "${COMMONVOICE}/cv-corpus-5.1-2020-06-22/${lang}" ${part} data/"$(echo "${part}_${lang}" | tr - _)"
    done

    # remove test&dev data from validated sentences
    utils/copy_data_dir.sh data/"$(echo "validated_${lang}" | tr - _)" data/${train_set}
    utils/filter_scp.pl --exclude data/${train_dev}/wav.scp data/${train_set}/wav.scp > data/${train_set}/temp_wav.scp
    utils/filter_scp.pl --exclude data/${test_set}/wav.scp data/${train_set}/temp_wav.scp > data/${train_set}/wav.scp
    utils/fix_data_dir.sh data/${train_set}
fi

log "Successfully finished. [elapsed=${SECONDS}s]"
