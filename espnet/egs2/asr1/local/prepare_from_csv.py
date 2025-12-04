#!/usr/bin/env python3
import argparse
import csv
import os
import sys
from pathlib import Path
from typing import Optional, Tuple, List, Dict


def parse_int_or_name(value: Optional[str]) -> Optional[str]:
    if value is None or value == "":
        return None
    return value


def detect_columns(header: List[str]) -> Tuple[str, str, Optional[str]]:
    # Heuristics for common column names
    audio_candidates = {"path", "audio", "wav", "wav_path", "audio_path", "file", "filename"}
    text_candidates = {"text", "transcript", "transcription", "sentence", "label"}
    id_candidates = {"id", "utt_id", "uttid", "utt", "uid"}

    lower = [h.lower() for h in header]
    audio_col = None
    text_col = None
    id_col = None
    for cand in audio_candidates:
        if cand in lower:
            audio_col = header[lower.index(cand)]
            break
    for cand in text_candidates:
        if cand in lower:
            text_col = header[lower.index(cand)]
            break
    for cand in id_candidates:
        if cand in lower:
            id_col = header[lower.index(cand)]
            break
    if audio_col is None or text_col is None:
        raise ValueError(
            f"Could not auto-detect required columns. Found header: {header}. "
            f"Please specify --audio-column and --text-column explicitly."
        )
    return audio_col, text_col, id_col


def resolve_column_indices(reader: csv.DictReader, args) -> Tuple[str, str, Optional[str]]:
    # If the input has no header, DictReader will use provided fieldnames or default None
    if reader.fieldnames is None:
        # No header. Require explicit column names as indices are not supported in DictReader.
        raise ValueError(
            "CSV appears to have no header. Please provide a header or use a TSV/CSV with header "
            "including columns for audio path and text."
        )
    audio_col = parse_int_or_name(args.audio_column)
    text_col = parse_int_or_name(args.text_column)
    id_col = parse_int_or_name(args.id_column)
    if audio_col is None or text_col is None:
        # Try auto-detect
        audio_col, text_col, auto_id = detect_columns(reader.fieldnames)
        if id_col is None:
            id_col = auto_id
    # Validate existence
    for c in [audio_col, text_col] + ([id_col] if id_col else []):
        if c and c not in reader.fieldnames:
            raise ValueError(f"Column '{c}' not found in header: {reader.fieldnames}")
    return audio_col, text_col, id_col


def normalize_wav_path(wav_root: Optional[Path], value: str) -> str:
    p = Path(value)
    if p.is_absolute():
        return str(p)
    if wav_root is None:
        # treat as relative to CWD
        return str((Path.cwd() / p).resolve())
    return str((wav_root / p).resolve())


def generate_utt_id(row: Dict[str, str], id_col: Optional[str], audio_path_value: str) -> str:
    if id_col and row.get(id_col):
        return row[id_col].strip()
    # Derive from audio filename stem
    stem = Path(audio_path_value).stem
    return stem


def write_lines(path: Path, lines: List[str]) -> None:
    with path.open("w", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")


def main():
    parser = argparse.ArgumentParser(description="Prepare Kaldi-style data dir from CSV + wav root")
    parser.add_argument("--csv", required=True, help="Path to CSV/TSV with header")
    parser.add_argument("--data-dir", required=True, help="Output Kaldi data dir (data/<name>)")
    parser.add_argument("--wav-root", default="", help="Root directory containing audio files")
    parser.add_argument("--delimiter", default=",", help="CSV delimiter: ',', '\\t', 'tab', 'space', '|' etc.")
    parser.add_argument("--audio-column", default="", help="Header name for audio path column")
    parser.add_argument("--text-column", default="", help="Header name for transcript text column")
    parser.add_argument("--id-column", default="", help="Header name for utterance id column (optional)")
    parser.add_argument(
        "--prefix_map",
        action="append",
        default=[],
        help="Rewrite leading path prefix in audio column, format OLD=NEW. "
             "Can be specified multiple times.",
    )
    parser.add_argument(
        "--strip_dir_levels",
        type=int,
        default=0,
        help="Remove the first N leading directory components from the audio column "
             "before joining with wav_root (after applying prefix_map).",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv)
    data_dir = Path(args.data_dir)
    wav_root = Path(args.wav_root).resolve() if args.wav_root else None
    data_dir.mkdir(parents=True, exist_ok=True)

    # Parse prefix maps
    prefix_maps: List[Tuple[str, str]] = []
    for item in args.prefix_map:
        if "=" not in item:
            raise ValueError(f"--prefix_map must be in OLD=NEW format, got '{item}'")
        old, new = item.split("=", 1)
        old = old.strip().strip("/ ")
        new = new.strip().strip("/ ")
        if not old:
            raise ValueError(f"--prefix_map has empty OLD in '{item}'")
        prefix_maps.append((old, new))

    # Normalize delimiter (strip quotes, accept keywords)
    raw_delim = (args.delimiter or "").strip()
    if len(raw_delim) >= 2 and ((raw_delim[0] == raw_delim[-1]) and raw_delim[0] in ("'", '"')):
        raw_delim = raw_delim[1:-1]
    lower_delim = raw_delim.lower()
    if lower_delim in ("\\t", r"\t", "tab", "tabs"):
        delimiter = "\t"
    elif lower_delim in ("space", "\\s"):
        delimiter = " "
    elif lower_delim in ("comma", "csv"):
        delimiter = ","
    elif lower_delim in ("pipe", "bar"):
        delimiter = "|"
    elif len(raw_delim) == 1:
        delimiter = raw_delim
    else:
        raise ValueError(
            f"Invalid delimiter '{args.delimiter}'. Use one character or keywords: tab, space, comma, pipe."
        )

    # Read CSV
    with csv_path.open("r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter=delimiter)
        audio_col, text_col, id_col = resolve_column_indices(reader, args)

        wav_scp: List[str] = []
        text: List[str] = []
        utt2spk: List[str] = []
        seen_utts = set()
        missing_files = 0
        skipped_no_audio = 0
        skipped_no_text = 0
        sample_checks: List[Tuple[str, bool]] = []
        total_rows = 0

        for row in reader:
            total_rows += 1
            raw_audio = (row.get(audio_col) or "").strip()
            raw_text = (row.get(text_col) or "").strip()
            if not raw_audio or not raw_text:
                if not raw_audio:
                    skipped_no_audio += 1
                if not raw_text:
                    skipped_no_text += 1
                continue

            # Apply leading prefix remapping if requested
            if prefix_maps:
                for old, new in prefix_maps:
                    old_slash = old + "/"
                    if raw_audio == old:
                        raw_audio = new
                        break
                    if raw_audio.startswith(old_slash):
                        raw_audio = new + "/" + raw_audio[len(old_slash):]
                        break

            # Strip N leading directory components if requested
            if args.strip_dir_levels and "/" in raw_audio:
                parts = raw_audio.split("/")
                if len(parts) > args.strip_dir_levels:
                    raw_audio = "/".join(parts[args.strip_dir_levels:])
                else:
                    # If stripping removes everything, keep basename
                    raw_audio = parts[-1]

            full_audio = normalize_wav_path(wav_root, raw_audio)
            if len(sample_checks) < 5:
                sample_checks.append((full_audio, os.path.isfile(full_audio)))
            utt_id = generate_utt_id(row, id_col, full_audio)
            if not utt_id:
                continue
            if utt_id in seen_utts:
                # Make id unique by appending a numeric suffix
                suffix = 1
                new_id = f"{utt_id}-{suffix}"
                while new_id in seen_utts:
                    suffix += 1
                    new_id = f"{utt_id}-{suffix}"
                utt_id = new_id
            seen_utts.add(utt_id)

            if not os.path.isfile(full_audio):
                missing_files += 1
                continue

            # Write entries
            wav_scp.append(f"{utt_id} {full_audio}")
            # Kaldi text allows spaces after utt_id
            text.append(f"{utt_id} {raw_text}")
            # One-speaker-per-utterance fallback
            utt2spk.append(f"{utt_id} {utt_id}")

    kept = len(wav_scp)
    if kept == 0:
        print("No valid audio/text entries found. Check your columns and paths.", file=sys.stderr)
        print(f"Diagnostics:", file=sys.stderr)
        print(f"  Total rows read: {total_rows}", file=sys.stderr)
        print(f"  Skipped rows with empty audio field [{audio_col}]: {skipped_no_audio}", file=sys.stderr)
        print(f"  Skipped rows with empty text field [{text_col}]: {skipped_no_text}", file=sys.stderr)
        print(f"  Rows with non-existent audio files after join: {missing_files}", file=sys.stderr)
        if wav_root:
            print(f"  wav_root used: {wav_root}", file=sys.stderr)
        else:
            print(f"  wav_root used: <none>", file=sys.stderr)
        if sample_checks:
            print("  Sample constructed paths (exists?):", file=sys.stderr)
            for pth, ok in sample_checks:
                print(f"    {pth} -> {ok}", file=sys.stderr)
        else:
            print("  No sample paths available (input may be empty after header).", file=sys.stderr)
        sys.exit(1)

    write_lines(data_dir / "wav.scp", wav_scp)
    write_lines(data_dir / "text", text)
    write_lines(data_dir / "utt2spk", utt2spk)

    if missing_files > 0:
        print(f"Warning: {missing_files} audio files listed in CSV were not found on disk and were skipped.", file=sys.stderr)

    print(f"Wrote {kept} utterances to {data_dir}", file=sys.stderr)


if __name__ == "__main__":
    main()


