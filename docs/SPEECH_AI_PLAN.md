# Mayo Irish Speech AI Plan

A comprehensive plan for building ASR (Automatic Speech Recognition), TTS (Text-to-Speech), and voice cloning capabilities using the abairt transcript dataset.

## Table of Contents
1. [Dataset Overview](#dataset-overview)
2. [Phase 1: Voice Cloning for Single Words](#phase-1-voice-cloning-for-single-words-easiest)
3. [Phase 2: ASR Fine-tuning](#phase-2-asr-fine-tuning-medium)
4. [Phase 3: TTS Training](#phase-3-tts-training-most-complex)
5. [Infrastructure & Training Platforms](#infrastructure--training-platforms)
6. [Data Export Scripts](#data-export-scripts)
7. [Production Data Inventory](#production-data-inventory)

---

## Dataset Overview

### Current Data Structure

Your abairt database contains:

| Model | Description |
|-------|-------------|
| `DictionaryEntry` | Individual transcript segments with audio snippets |
| `VoiceRecording` | Source recordings (full audio + metadata) |
| `User` (as speaker) | Speaker metadata (dialect, gender, ability) |

### Key Fields for ML Training

**DictionaryEntry:**
- `word_or_phrase` - Irish text (transcript)
- `translation` - English translation
- `region_start` / `region_end` - Timestamps (seconds)
- `media` - Audio snippet (MP3 via ActiveStorage)
- `quality` - low/fair/good/excellent
- `accuracy_status` - Human verification status
- `speaker_id` - Links to User

**User (Speaker):**
- `dialect` - `tuaisceart_mhaigh_eo`, `connacht_ó_thuaidh`, `acaill`, `lár_chonnachta`, `canúintí_eile`
- `voice` - `male`/`female`
- `ability` - CEFR levels (A1-C2, native)

### Data Quality Tiers

For training, we should prioritize data by quality:

| Tier | Criteria | Use Case |
|------|----------|----------|
| **Gold** | `accuracy_status: confirmed` + `quality: good/excellent` | Primary training data |
| **Silver** | `accuracy_status: confirmed` OR `quality: fair+` | Extended training |
| **Bronze** | All other entries with audio | Data augmentation only |

---

## Phase 1: Voice Cloning for Single Words (Easiest)

**Goal:** Allow users to hear any Irish word pronounced in a Mayo dialect voice, similar to airid.ie

**Approach:** Use a pre-trained voice cloning model (XTTS v2) with reference audio from your best speakers

### How It Works

1. Select 1-3 "reference speakers" with the cleanest audio (10-30 seconds each)
2. When user requests pronunciation:
   - Pass the Irish text + reference audio to XTTS
   - Model generates speech that sounds like the reference speaker
3. Cache generated audio for repeated requests

### Implementation Steps

#### 1.1 Select Reference Speakers

```ruby
# Find speakers with most high-quality entries
User.joins(:spoken_dictionary_entries)
    .where(dialect: :tuaisceart_mhaigh_eo, ability: :native)
    .where(dictionary_entries: { quality: [:good, :excellent], accuracy_status: :confirmed })
    .group(:id)
    .order('COUNT(dictionary_entries.id) DESC')
    .limit(10)
```

#### 1.2 Create Reference Audio Compilation

For each selected speaker, concatenate 10-30 seconds of their clearest audio:
- Select entries with single words/short phrases (cleaner pronunciation)
- Normalize audio levels
- Export as WAV 22050Hz mono

#### 1.3 Service Implementation

```ruby
# app/services/voice_cloning_service.rb
class VoiceCloningService
  XTTS_API_URL = ENV['XTTS_API_URL'] # Self-hosted or cloud API

  def initialize(speaker_reference: :default)
    @reference_audio = load_reference(speaker_reference)
  end

  def synthesize(irish_text)
    # Check cache first
    cached = SynthesizedAudio.find_by(text: irish_text, voice: @reference_voice)
    return cached.audio if cached

    # Call XTTS API
    response = HTTParty.post(XTTS_API_URL, body: {
      text: irish_text,
      speaker_wav: @reference_audio,
      language: 'ga'
    })

    # Cache and return
    SynthesizedAudio.create!(text: irish_text, voice: @reference_voice, audio: response.body)
  end
end
```

#### 1.4 Self-Hosting XTTS

```bash
# Docker setup for XTTS v2 server
docker run -d --gpus all -p 8000:8000 \
  -v /path/to/references:/references \
  ghcr.io/coqui-ai/xtts-streaming-server:latest
```

**M4 Mac Note:** XTTS can run on CPU but is slow (~5-10s per generation). For a website feature, consider:
- Pre-generating common words
- Using a small GPU cloud instance for real-time requests
- RunPod/Vast.ai spot instances are cheap (~$0.20/hr for RTX 3090)

### Estimated Effort
- **Time:** 1-2 days for basic implementation
- **Prerequisites:** Select reference speakers, export reference audio
- **Hosting:** Self-hosted XTTS or cloud API

---

## Phase 2: ASR Fine-tuning (Medium)

**Goal:** Create a Whisper model fine-tuned for Mayo Irish that significantly outperforms base Whisper

**Approach:** Fine-tune `whisper-large-v3` on your transcribed segments

### Why Fine-tune Whisper?

- Whisper already knows Irish but struggles with:
  - Dialect-specific pronunciations
  - Older speakers' speech patterns
  - Domain-specific vocabulary (place names, traditional terms)
- Fine-tuning teaches it your specific dialect patterns
- 5-20 hours of data is often enough to see major improvements

### Data Preparation

#### 2.1 Export Training Data

Required format for HuggingFace datasets:

```json
{
  "audio": {"path": "audio_001.wav", "sampling_rate": 16000},
  "sentence": "Tá sé go maith"
}
```

Export script (see [Data Export Scripts](#data-export-scripts)):

```ruby
# lib/tasks/ml_export.rake
namespace :ml do
  desc "Export data for Whisper fine-tuning"
  task export_asr: :environment do
    ExportAsrDatasetService.new(
      output_dir: Rails.root.join('ml_exports/asr'),
      quality_filter: [:good, :excellent],
      min_duration: 1.0,  # Skip very short clips
      max_duration: 30.0  # Whisper works best < 30s
    ).call
  end
end
```

#### 2.2 Audio Preprocessing

Whisper expects:
- 16kHz sample rate
- Mono channel
- WAV or FLAC format

```bash
# Convert existing MP3 snippets to Whisper format
ffmpeg -i input.mp3 -ar 16000 -ac 1 output.wav
```

#### 2.3 Dataset Split

| Split | Percentage | Purpose |
|-------|------------|---------|
| Train | 85% | Model training |
| Validation | 10% | Hyperparameter tuning |
| Test | 5% | Final evaluation |

**Important:** Split by speaker, not by entry, to avoid data leakage.

### Training Process

#### 2.4 Fine-tuning Script

```python
# scripts/finetune_whisper.py
from transformers import WhisperForConditionalGeneration, WhisperProcessor
from transformers import Seq2SeqTrainer, Seq2SeqTrainingArguments
from datasets import load_dataset, Audio

# Load model
model_name = "openai/whisper-large-v3"
processor = WhisperProcessor.from_pretrained(model_name)
model = WhisperForConditionalGeneration.from_pretrained(model_name)

# Load your dataset
dataset = load_dataset("audiofolder", data_dir="./ml_exports/asr")
dataset = dataset.cast_column("audio", Audio(sampling_rate=16000))

# Preprocessing
def prepare_dataset(batch):
    audio = batch["audio"]
    batch["input_features"] = processor(
        audio["array"],
        sampling_rate=audio["sampling_rate"],
        return_tensors="pt"
    ).input_features[0]
    batch["labels"] = processor.tokenizer(batch["sentence"]).input_ids
    return batch

dataset = dataset.map(prepare_dataset, remove_columns=dataset.column_names["train"])

# Training arguments
training_args = Seq2SeqTrainingArguments(
    output_dir="./whisper-mayo-irish",
    per_device_train_batch_size=8,  # Adjust for your GPU memory
    gradient_accumulation_steps=2,
    learning_rate=1e-5,
    warmup_steps=500,
    max_steps=5000,
    fp16=True,  # Use bf16=True for newer GPUs
    evaluation_strategy="steps",
    eval_steps=500,
    save_steps=500,
    logging_steps=100,
    predict_with_generate=True,
    generation_max_length=225,
)

# Train
trainer = Seq2SeqTrainer(
    args=training_args,
    model=model,
    train_dataset=dataset["train"],
    eval_dataset=dataset["validation"],
    data_collator=DataCollatorSpeechSeq2SeqWithPadding(processor=processor),
    tokenizer=processor.feature_extractor,
)

trainer.train()
```

#### 2.5 Evaluation Metrics

- **WER (Word Error Rate)** - Primary metric
- **CER (Character Error Rate)** - Useful for Irish with mutations

Compare:
1. Base Whisper large-v3 on test set
2. Fine-tuned model on test set

Target: **>30% relative WER reduction**

### Hardware Requirements

| Platform | Config | Training Time (10 hrs data) | Cost |
|----------|--------|----------------------------|------|
| M4 Mac 64GB | CPU/MPS | ~3-5 days | $0 (electricity) |
| RunPod RTX 4090 | 24GB VRAM | ~6-12 hours | ~$10-15 |
| Lambda Labs A100 | 40GB VRAM | ~3-6 hours | ~$10-20 |
| Google Colab Pro+ | A100 | ~6-12 hours | ~$50/month |

**Recommendation:** Start with a small subset (1-2 hours) locally to validate the pipeline, then train full model on cloud GPU.

### Integration with abairt

After training, integrate the model:

```ruby
# app/services/mayo_asr_service.rb
class MayoAsrService
  MODEL_PATH = Rails.root.join('ml_models/whisper-mayo-irish')

  def transcribe(audio_path)
    # Call local model or API
    result = WhisperClient.transcribe(
      audio_path,
      model: MODEL_PATH,
      language: 'ga'
    )
    result[:text]
  end
end
```

### Estimated Effort
- **Data Prep:** 2-3 days
- **Training:** 1-2 days (mostly waiting)
- **Integration:** 1 day
- **Total:** ~1 week

---

## Phase 3: TTS Training (Most Complex)

**Goal:** Train a custom TTS model that speaks Mayo Irish naturally

**Approach:** Train VITS or Piper TTS on your highest-quality single-speaker data

### Why TTS is Harder

- Requires **more data per speaker** (ideally 5-20+ hours)
- Needs **consistent audio quality** throughout
- **Preprocessing is critical** - bad alignments = bad model
- Training is more compute-intensive

### Speaker Selection Strategy

For TTS, focus on **one speaker at a time**:

```ruby
# Find your best TTS candidate
User.joins(:spoken_dictionary_entries)
    .where(dialect: :tuaisceart_mhaigh_eo)
    .where(dictionary_entries: { quality: [:good, :excellent] })
    .group(:id)
    .having('SUM(dictionary_entries.region_end - dictionary_entries.region_start) > ?', 3600) # >1 hour
    .order('SUM(dictionary_entries.region_end - dictionary_entries.region_start) DESC')
    .select('users.*, SUM(dictionary_entries.region_end - dictionary_entries.region_start) as total_duration')
```

### Data Preparation (Most Labor-Intensive)

#### 3.1 Audio Requirements

| Requirement | Value | Notes |
|-------------|-------|-------|
| Sample rate | 22050 Hz | Standard for TTS |
| Channels | Mono | |
| Format | WAV | Uncompressed |
| Bit depth | 16-bit | |
| Loudness | -23 LUFS | Normalized |
| Silence | Trimmed | <0.5s at start/end |

#### 3.2 Text Normalization

TTS models need normalized text:
- Expand abbreviations (Dr. → Dochtúir)
- Numbers to words (3 → trí)
- Handle Irish-specific: mutations, eclipsis, etc.

```ruby
# app/services/text_normalizer_service.rb
class TextNormalizerService
  MUTATIONS = {
    /\bb([^h])/ => 'bh\1', # Track lenition
    # ... more patterns
  }

  def normalize(text)
    text = expand_numbers(text)
    text = expand_abbreviations(text)
    text = normalize_punctuation(text)
    text.strip
  end
end
```

#### 3.3 Phoneme Alignment (Optional but Recommended)

For best results, align text to phonemes:

**Option A: Use existing phonemizer**
```python
from phonemizer import phonemize
# Note: Irish support may be limited
phonemes = phonemize(text, language='ga', backend='espeak')
```

**Option B: Train character-level model** (skip phonemes)
- VITS and Piper can train on characters directly
- Works fine for Irish, just needs more data

#### 3.4 Export Script

```ruby
# lib/tasks/ml_export.rake
namespace :ml do
  desc "Export data for TTS training"
  task export_tts: :environment do
    ExportTtsDatasetService.new(
      output_dir: Rails.root.join('ml_exports/tts'),
      speaker_id: ENV['SPEAKER_ID'],
      quality_filter: [:good, :excellent],
      min_duration: 1.0,
      max_duration: 15.0,  # TTS works best with shorter clips
      normalize_audio: true,
      normalize_text: true
    ).call
  end
end
```

Output structure:
```
ml_exports/tts/
├── wavs/
│   ├── entry_001.wav
│   ├── entry_002.wav
│   └── ...
├── metadata.csv       # filename|text|normalized_text
└── speaker_info.json  # Speaker metadata
```

### Training Options

#### Option A: Piper TTS (Recommended for Beginners)

Piper is from the Rhasspy project - designed to be easy to train and fast at inference.

```bash
# Install piper-tts training tools
pip install piper-tts[training]

# Prepare dataset
piper_train preprocess \
  --language ga \
  --input-dir ./ml_exports/tts \
  --output-dir ./ml_exports/tts_processed

# Train
piper_train \
  --input-dir ./ml_exports/tts_processed \
  --output-dir ./piper-mayo-irish \
  --max-epochs 10000 \
  --batch-size 32
```

**Pros:** Easy setup, fast inference, good documentation
**Cons:** Less natural than VITS for small datasets

#### Option B: VITS (Higher Quality)

```python
# Clone VITS repo
# git clone https://github.com/jaywalnut310/vits.git

# Prepare config
# configs/mayo_irish.json
{
  "train": {
    "log_interval": 200,
    "eval_interval": 1000,
    "seed": 1234,
    "epochs": 10000,
    "learning_rate": 2e-4,
    "batch_size": 32
  },
  "data": {
    "training_files": "filelists/train.txt",
    "validation_files": "filelists/val.txt",
    "text_cleaners": ["basic_cleaners"],
    "sampling_rate": 22050
  },
  "model": {
    "inter_channels": 192,
    "hidden_channels": 192,
    "filter_channels": 768,
    "n_heads": 2,
    "n_layers": 6
  }
}

# Train
python train.py -c configs/mayo_irish.json -m mayo_irish
```

#### Option C: Coqui TTS (Most Flexible)

```python
from TTS.api import TTS
from TTS.tts.configs.vits_config import VitsConfig
from TTS.tts.models.vits import Vits

# Configure
config = VitsConfig(
    audio={"sample_rate": 22050},
    characters={
        "characters": "aábcdeéfghiíjklmnoópqrstuúvwxyz",
        "punctuations": ".,!?;:-",
    },
    datasets=[{
        "name": "mayo_irish",
        "path": "./ml_exports/tts/",
        "meta_file_train": "metadata.csv",
        "language": "ga"
    }]
)

# Train
model = Vits(config)
trainer = Trainer(model, config)
trainer.fit()
```

### Multi-Speaker TTS (Advanced)

If you have enough data from multiple speakers:

```python
# YourTTS / VITS multi-speaker config
config = VitsConfig(
    use_speaker_embedding=True,
    num_speakers=5,  # Number of speakers in dataset
    # ... rest of config
)
```

This allows:
- Voice selection at inference time
- Potential voice interpolation
- Better generalization

### Hardware Requirements

| Platform | Config | Training Time (10 hrs data) | Cost |
|----------|--------|----------------------------|------|
| M4 Mac 64GB | MPS | ~1-2 weeks | $0 |
| RunPod RTX 4090 | 24GB VRAM | ~2-4 days | ~$50-80 |
| Lambda Labs A100 | 40GB VRAM | ~1-2 days | ~$50-100 |

**Note:** TTS training is more compute-intensive than ASR. Cloud GPU strongly recommended for serious training.

### Estimated Effort
- **Data Prep:** 1-2 weeks (audio cleaning, text normalization, alignment)
- **Training:** 2-7 days (depending on hardware)
- **Fine-tuning:** 1-2 days
- **Integration:** 1-2 days
- **Total:** 3-4 weeks for production-quality model

---

## Infrastructure & Training Platforms

### Local Development (M4 Mac 64GB)

**Good for:**
- Data preprocessing
- Small experiments
- Voice cloning inference
- ASR inference

**Setup:**
```bash
# Install dependencies
brew install ffmpeg sox
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
pip install transformers datasets librosa soundfile

# For MPS (Apple Silicon GPU) acceleration
pip install torch torchvision torchaudio  # MPS is auto-detected
```

**Limitations:**
- No CUDA → slower training
- MPS support varies by library
- Full ASR training: feasible but slow
- Full TTS training: not recommended

### Cloud GPU Options

#### RunPod (Recommended for Cost)

```bash
# Deploy a pod
# Go to runpod.io, select:
# - RTX 4090 (24GB) for ASR: ~$0.44/hr
# - A100 (40GB) for TTS: ~$1.09/hr

# Use their PyTorch template
# SSH in and clone your training scripts
```

**Pros:** Cheap, flexible, good GPU selection
**Cons:** Spot instances can be interrupted

#### Lambda Labs

```bash
# More stable than RunPod
# A100 instances: ~$1.10/hr
# Good for longer training runs
```

#### Vast.ai

```bash
# Cheapest option for spot instances
# RTX 3090: ~$0.20-0.30/hr
# Good for experimentation
```

#### Google Colab Pro+

```python
# Free tier: T4 (limited)
# Pro+: A100 access (~$50/month)
# Good for notebooks and experimentation
```

### Recommended Setup

| Phase | Local | Cloud |
|-------|-------|-------|
| Data prep | ✅ All preprocessing | - |
| Voice cloning | ✅ Inference | ✅ Heavy use |
| ASR training | ✅ Small experiments | ✅ Full training |
| TTS training | ❌ Too slow | ✅ Required |

---

## Data Export Scripts

### Export Service Base

```ruby
# app/services/ml_export/base_service.rb
module MlExport
  class BaseService
    def initialize(output_dir:, quality_filter: [:good, :excellent], min_duration: 1.0, max_duration: 30.0)
      @output_dir = Pathname.new(output_dir)
      @quality_filter = quality_filter
      @min_duration = min_duration
      @max_duration = max_duration
    end

    def base_query
      DictionaryEntry
        .includes(:speaker, :voice_recording, media_attachment: :blob)
        .where(quality: @quality_filter)
        .where.not(media_attachment: nil)
        .where('region_end - region_start >= ?', @min_duration)
        .where('region_end - region_start <= ?', @max_duration)
    end

    def export_audio(entry, filename)
      return unless entry.media.attached?

      input_path = ActiveStorage::Blob.service.path_for(entry.media.blob.key)
      output_path = @output_dir.join('wavs', "#{filename}.wav")

      # Convert to standard format
      system("ffmpeg -y -i '#{input_path}' -ar #{sample_rate} -ac 1 '#{output_path}'")
      output_path
    end

    def sample_rate
      raise NotImplementedError
    end
  end
end
```

### ASR Export Service

```ruby
# app/services/ml_export/asr_dataset_service.rb
module MlExport
  class AsrDatasetService < BaseService
    def sample_rate
      16000  # Whisper expects 16kHz
    end

    def call
      FileUtils.mkdir_p(@output_dir.join('wavs'))

      entries = base_query.where.not(word_or_phrase: [nil, ''])
      metadata = []

      entries.find_each.with_index do |entry, idx|
        filename = "entry_#{entry.id.to_s.rjust(6, '0')}"

        if export_audio(entry, filename)
          metadata << {
            file_name: "wavs/#{filename}.wav",
            sentence: normalize_text(entry.word_or_phrase),
            speaker_id: entry.speaker_id,
            duration: entry.region_end - entry.region_start
          }
        end

        print "\rExported #{idx + 1} entries..." if idx % 100 == 0
      end

      # Write metadata
      File.write(@output_dir.join('metadata.jsonl'), metadata.map(&:to_json).join("\n"))

      # Create HuggingFace dataset config
      write_dataset_config(metadata)

      puts "\nExported #{metadata.size} entries to #{@output_dir}"
    end

    private

    def normalize_text(text)
      text.to_s.strip.downcase
    end

    def write_dataset_config(metadata)
      # Split by speaker for proper train/val/test splits
      # ... implementation
    end
  end
end
```

### TTS Export Service

```ruby
# app/services/ml_export/tts_dataset_service.rb
module MlExport
  class TtsDatasetService < BaseService
    def initialize(speaker_id:, **options)
      super(**options)
      @speaker_id = speaker_id
    end

    def sample_rate
      22050  # Standard TTS sample rate
    end

    def call
      FileUtils.mkdir_p(@output_dir.join('wavs'))

      entries = base_query.where(speaker_id: @speaker_id)
      metadata = []

      entries.find_each.with_index do |entry, idx|
        filename = "entry_#{entry.id.to_s.rjust(6, '0')}"

        if export_audio_normalized(entry, filename)
          metadata << [
            filename,
            entry.word_or_phrase,
            normalize_text(entry.word_or_phrase)
          ].join('|')
        end

        print "\rExported #{idx + 1} entries..." if idx % 100 == 0
      end

      # LJSpeech-style metadata.csv
      File.write(@output_dir.join('metadata.csv'), metadata.join("\n"))

      puts "\nExported #{metadata.size} entries to #{@output_dir}"
    end

    private

    def export_audio_normalized(entry, filename)
      return unless entry.media.attached?

      input_path = ActiveStorage::Blob.service.path_for(entry.media.blob.key)
      output_path = @output_dir.join('wavs', "#{filename}.wav")

      # Convert, normalize loudness, trim silence
      system(<<~CMD)
        ffmpeg -y -i '#{input_path}' \
          -af 'loudnorm=I=-23:TP=-1.5:LRA=11,silenceremove=1:0:-50dB:1:1:-50dB' \
          -ar #{sample_rate} -ac 1 \
          '#{output_path}'
      CMD

      output_path.exist?
    end

    def normalize_text(text)
      TextNormalizerService.new.normalize(text)
    end
  end
end
```

### Rake Tasks

```ruby
# lib/tasks/ml_export.rake
namespace :ml do
  desc "Export ASR training data"
  task export_asr: :environment do
    MlExport::AsrDatasetService.new(
      output_dir: Rails.root.join('ml_exports/asr'),
      quality_filter: [:good, :excellent],
      min_duration: 1.0,
      max_duration: 30.0
    ).call
  end

  desc "Export TTS training data for a specific speaker"
  task export_tts: :environment do
    speaker_id = ENV.fetch('SPEAKER_ID') { raise "SPEAKER_ID required" }

    MlExport::TtsDatasetService.new(
      output_dir: Rails.root.join("ml_exports/tts_speaker_#{speaker_id}"),
      speaker_id: speaker_id,
      quality_filter: [:good, :excellent],
      min_duration: 1.0,
      max_duration: 15.0
    ).call
  end

  desc "Generate dataset statistics"
  task stats: :environment do
    MlExport::DatasetStatsService.new.print_report
  end
end
```

---

## Production Data Inventory

**Instructions:** Run these queries against your production database and fill in the values. This will help size the training effort.

### Overall Statistics

```ruby
# Run in rails console
puts "=== Overall Statistics ==="
puts "Total DictionaryEntries: #{DictionaryEntry.count}"
puts "Entries with audio: #{DictionaryEntry.joins(:media_attachment).count}"
puts "Total duration (hours): #{DictionaryEntry.sum('region_end - region_start') / 3600.0}"
```

| Metric | Value |
|--------|-------|
| Total DictionaryEntries | ___ |
| Entries with audio attached | ___ |
| Total audio duration (hours) | ___ |

### Quality Distribution

```ruby
puts "=== Quality Distribution ==="
DictionaryEntry.group(:quality).count.each { |q, c| puts "#{q}: #{c}" }
```

| Quality | Count | Duration (hrs) |
|---------|-------|----------------|
| excellent | ___ | ___ |
| good | ___ | ___ |
| fair | ___ | ___ |
| low | ___ | ___ |

### Accuracy Status Distribution

```ruby
puts "=== Accuracy Status ==="
DictionaryEntry.group(:accuracy_status).count.each { |s, c| puts "#{s}: #{c}" }
```

| Status | Count |
|--------|-------|
| confirmed | ___ |
| unconfirmed | ___ |
| other | ___ |

### Speaker Statistics

```ruby
puts "=== Top Speakers by Duration ==="
User.joins(:spoken_dictionary_entries)
    .group('users.id', 'users.name', 'users.dialect', 'users.voice')
    .select('users.id, users.name, users.dialect, users.voice,
             SUM(dictionary_entries.region_end - dictionary_entries.region_start) as total_duration,
             COUNT(dictionary_entries.id) as entry_count')
    .order('total_duration DESC')
    .limit(20)
    .each do |u|
      puts "#{u.name} (#{u.dialect}, #{u.voice}): #{(u.total_duration / 3600.0).round(2)} hrs, #{u.entry_count} entries"
    end
```

| Speaker | Dialect | Gender | Duration (hrs) | Entry Count |
|---------|---------|--------|----------------|-------------|
| ___ | ___ | ___ | ___ | ___ |
| ___ | ___ | ___ | ___ | ___ |
| ___ | ___ | ___ | ___ | ___ |

### Dialect Distribution

```ruby
puts "=== Dialect Distribution ==="
User.joins(:spoken_dictionary_entries)
    .group(:dialect)
    .select('dialect,
             SUM(dictionary_entries.region_end - dictionary_entries.region_start) as total_duration,
             COUNT(DISTINCT users.id) as speaker_count')
    .each { |r| puts "#{r.dialect}: #{(r.total_duration / 3600.0).round(2)} hrs, #{r.speaker_count} speakers" }
```

| Dialect | Duration (hrs) | Speaker Count |
|---------|----------------|---------------|
| tuaisceart_mhaigh_eo | ___ | ___ |
| connacht_ó_thuaidh | ___ | ___ |
| acaill | ___ | ___ |
| lár_chonnachta | ___ | ___ |
| canúintí_eile | ___ | ___ |

### High-Quality Data Subset

```ruby
puts "=== High-Quality Training Data ==="
hq = DictionaryEntry
  .joins(:media_attachment)
  .where(quality: [:good, :excellent])
  .where(accuracy_status: :confirmed)

puts "Count: #{hq.count}"
puts "Duration: #{hq.sum('region_end - region_start') / 3600.0} hours"
```

| Metric | Value |
|--------|-------|
| High-quality confirmed entries | ___ |
| High-quality duration (hours) | ___ |

---

## Next Steps

Based on your production data inventory, we can:

1. **If you have 5+ hours of high-quality data:**
   - Proceed with all three phases
   - Voice cloning → ASR → TTS

2. **If you have 1-5 hours:**
   - Start with voice cloning (immediate win)
   - ASR fine-tuning (will still help)
   - TTS may need more data collection

3. **If you have <1 hour:**
   - Voice cloning only for now
   - Focus on collecting/transcribing more data
   - Consider data augmentation techniques

Fill in the data inventory above and we can refine the plan with specific training parameters and timelines!
