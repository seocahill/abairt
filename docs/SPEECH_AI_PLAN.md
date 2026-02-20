# Mayo Irish Speech AI Plan

A comprehensive plan for building ASR (Automatic Speech Recognition), TTS (Text-to-Speech), and voice cloning capabilities using the abairt transcript dataset.

---

## Executive Summary

### Vision

Create an **open foundation for Mayo Irish language technology** — a suite of speech AI tools that anyone can build upon to develop applications for this dialect. While we will continue to maintain core applications like abairt, the underlying speech models and datasets will be made available to support a broader ecosystem of language tools, educational apps, and accessibility services.

### What We're Building

| Capability | What It Does | Who Benefits |
|------------|--------------|--------------|
| **Voice Cloning** | Pronounce any word in an authentic Mayo voice | Learners, dictionary apps, accessibility tools |
| **Speech Recognition** | Convert Mayo Irish speech to text accurately | Transcription services, voice assistants, archivists |
| **Text-to-Speech** | Generate natural Mayo Irish speech from text | Screen readers, audiobooks, language apps |
| **Dialect AI** | Write and translate in authentic Mayo Irish | Educational tools, translation services, content creators |

### Data Requirements at a Glance

| Capability | Minimum Data Needed | Ideal Data | Current Status |
|------------|---------------------|------------|----------------|
| **Voice Cloning** | 30 seconds per voice | 2-3 minutes | ✅ Ready now |
| **Speech Recognition** | 5 hours transcribed | 20+ hours | TBD after audit |
| **Text-to-Speech** | 5 hours (single speaker) | 15-20 hours | TBD after audit |
| **Dialect AI** | 1,000 translated phrases | 5,000+ phrases | TBD after audit |

### The Four Phases

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: VOICE CLONING                                                     │
│  ───────────────────────                                                    │
│  Hear any Irish word spoken in a Mayo accent                                │
│                                                                             │
│  • Data: Select best speaker recordings (30 sec - 2 min)                    │
│  • Effort: 1-2 weeks to deploy                                              │
│  • Output: Web feature + API for third-party apps                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 2: SPEECH RECOGNITION (ASR)                                          │
│  ─────────────────────────────────                                          │
│  Accurately transcribe Mayo Irish speakers                                  │
│                                                                             │
│  • Data: 5-20 hours of transcribed audio from native speakers               │
│  • Effort: 2-4 weeks (data prep + training)                                 │
│  • Output: Transcription API, improved abairt pipeline, open model          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3: TEXT-TO-SPEECH (TTS)                                              │
│  ─────────────────────────────                                              │
│  Generate natural-sounding Mayo Irish speech                                │
│                                                                             │
│  • Data: 5-20 hours from ONE consistent speaker (clean audio)               │
│  • Effort: 4-8 weeks (significant audio preprocessing)                      │
│  • Output: TTS API, screen reader voice, open model                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 4: DIALECT AI                                                        │
│  ───────────────────                                                        │
│  AI that writes authentic Mayo Irish (not just "standard" Irish)            │
│                                                                             │
│  • Data: Translated phrase pairs (Mayo Irish ↔ English)                     │
│  • Effort: 2-4 weeks                                                        │
│  • Output: Translation API, writing assistant, dialect checker              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Why This Matters

**For Language Preservation:**
Mayo Irish has distinct vocabulary, grammar, and idioms that standard Irish language tools don't capture. "Tig leat" (Mayo) vs "is féidir leat" (standard) — these aren't just accent differences, they're different ways of speaking that define the dialect.

**For the Community:**
- Learners get tools that teach *actual* Mayo Irish, not textbook Irish
- Native speakers hear their own dialect reflected in technology
- Researchers and archivists get better transcription of historical recordings

**For the Ecosystem:**
By releasing open models, we enable others to build:
- Mobile apps for learners
- Accessibility tools (screen readers, voice input)
- Educational games
- Archival and research tools
- Voice assistants that understand the dialect

### Data Foundation

All capabilities build on the **abairt transcript database** — recordings of native Mayo Irish speakers, transcribed and translated. The quality and quantity of this data determines what's possible:

| Data Volume | What It Unlocks |
|-------------|-----------------|
| **Current baseline** | Voice cloning (immediate) |
| **5+ hours confirmed** | Speech recognition (good accuracy) |
| **10+ hours single speaker** | Text-to-speech (natural voice) |
| **5,000+ translated phrases** | Dialect AI (authentic writing) |

### Next Steps

1. **Audit production data** — Run queries to determine exact hours of confirmed, high-quality transcripts
2. **Identify best speakers** — Find native speakers with the most clean, transcribed audio
3. **Phase 1 pilot** — Deploy voice cloning as proof of concept
4. **Community engagement** — Share vision, gather feedback, identify priority use cases

---

## Table of Contents
1. [Dataset Overview](#dataset-overview)
2. [Phase 0: Digitization Pipeline](#phase-0-digitization-pipeline-prerequisite)
3. [Phase 1: Voice Cloning for Single Words](#phase-1-voice-cloning-for-single-words-easiest)
4. [Phase 2: ASR Fine-tuning](#phase-2-asr-fine-tuning-medium)
5. [Phase 3: TTS Training](#phase-3-tts-training-most-complex)
6. [Phase 4: Dialect AI](#phase-4-dialect-ai)
7. [Infrastructure & Training Platforms](#infrastructure--training-platforms)
8. [Data Export Scripts](#data-export-scripts)
9. [Production Data Inventory](#production-data-inventory)
10. [Appendix: Scanning Equipment Guide](#appendix-scanning-equipment-guide)

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

## Phase 0: Digitization Pipeline (Prerequisite)

**Goal:** Digitize printed Mayo Irish materials (books, manuscripts, notes) to expand the training corpus for Dialect AI and provide reference materials for all phases.

**Why This Matters:** Many dialectal phrases, idioms, and vocabulary exist only in print — older textbooks, folklore collections, local publications. Digitizing these materials multiplies the available training data for Phase 4 (Dialect AI) and provides reference material for validating ASR/TTS outputs.

### OCR Options for Irish Text

| Service | Best For | Irish/Fada Support | Cost |
|---------|----------|-------------------|------|
| **Surya OCR** | Clean modern print | Excellent | Free (local) |
| **Google Cloud Vision** | Volume processing | Excellent | ~$1.50/1000 pages |
| **Transkribus** | Historical texts, handwriting | Good (trainable) | Free tier + paid |
| **Azure Document Intelligence** | Structured documents | Excellent | ~$1.50/1000 pages |
| **Tesseract** | Basic OCR, offline | Fair (needs config) | Free |

**Recommendation:**
- **Modern print (post-1950):** Surya OCR locally or Google Cloud Vision
- **Historical texts / old orthography:** Transkribus with custom model training
- **Handwritten materials:** Transkribus only

### The Digitization Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. CAPTURE                                                                  │
│  ───────────                                                                 │
│  Scan or photograph source materials                                         │
│  • 300 DPI minimum (600 for older/faded text)                               │
│  • Flat pages, consistent lighting                                          │
│  • Organize by source (book title, page numbers)                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│  2. OCR PROCESSING                                                           │
│  ─────────────────                                                           │
│  Extract text from images                                                    │
│  • Run through chosen OCR service                                           │
│  • Batch process for efficiency                                             │
│  • Preserve page/source metadata                                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│  3. POST-PROCESSING                                                          │
│  ─────────────────                                                           │
│  Fix common OCR errors for Irish                                             │
│  • Verify fadas using abairt vocabulary dictionary                          │
│  • Correct common character confusions (í/i, á/a, etc.)                     │
│  • Handle old orthography if preserving (Gaedhilge → Gaeilge optional)      │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│  4. HUMAN REVIEW                                                             │
│  ─────────────                                                               │
│  Quality assurance (essential for training data)                             │
│  • Sample review: check 5-10% of pages                                      │
│  • Flag problematic sources for full review                                 │
│  • Mark confidence levels                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│  5. INTEGRATION                                                              │
│  ────────────                                                                │
│  Import into abairt / training pipeline                                      │
│  • Store as DigitizedText records (new model)                               │
│  • Link to source metadata                                                  │
│  • Available for RAG and fine-tuning                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Irish-Specific OCR Challenges

| Challenge | Example | Solution |
|-----------|---------|----------|
| **Missing fadas** | "cailin" instead of "cailín" | Post-process with vocabulary lookup |
| **Wrong fadas** | "cáilín" instead of "cailín" | Vocabulary verification |
| **Old orthography** | "Gaedhilge", "béul" | Normalize or preserve (configurable) |
| **Seanchló (old script)** | ꞇ ꞅ ꞃ characters | Transkribus with custom model |
| **Dialect spellings** | Non-standard but correct | Preserve — this is the valuable data! |

### Post-Processing Service

Build a correction service using the existing abairt vocabulary:

```ruby
# app/services/irish_ocr_cleanup_service.rb
class IrishOcrCleanupService
  def initialize
    # Build vocabulary from confirmed entries
    @known_words = DictionaryEntry
      .where(accuracy_status: :confirmed)
      .pluck(:word_or_phrase)
      .flat_map { |phrase| phrase.downcase.split(/\s+/) }
      .uniq
      .to_set
  end

  def cleanup(text)
    words = text.split(/(\s+)/)  # Preserve whitespace

    words.map do |word|
      next word if word.match?(/^\s+$/)  # Keep whitespace

      # Check if word (or fada variants) exists in vocabulary
      corrected = find_correct_spelling(word.downcase)
      corrected ? match_case(word, corrected) : word
    end.join
  end

  private

  def find_correct_spelling(word)
    return word if @known_words.include?(word)

    # Try adding/correcting fadas
    FADA_VARIANTS[word] || suggest_fada_correction(word)
  end

  FADA_VARIANTS = {
    'cailin' => 'cailín',
    'failte' => 'fáilte',
    'slan' => 'slán',
    'gaeilge' => 'Gaeilge',
    # Expanded from corpus analysis...
  }.freeze
end
```

### Surya OCR Local Setup

```bash
# Install Surya OCR
pip install surya-ocr

# Process a single image
surya_ocr page_001.png --langs ga --output results/

# Batch process a directory
for f in scans/*.png; do
  surya_ocr "$f" --langs ga --output ocr_output/
done
```

### Data Model for Digitized Text

```ruby
# db/migrate/xxx_create_digitized_texts.rb
class CreateDigitizedTexts < ActiveRecord::Migration[7.1]
  def change
    create_table :digitized_texts do |t|
      t.string :source_title        # Book/document title
      t.string :source_author
      t.integer :source_year
      t.integer :page_number
      t.text :raw_ocr_text          # Original OCR output
      t.text :cleaned_text          # Post-processed
      t.string :ocr_service         # surya, google, transkribus
      t.float :confidence_score
      t.string :review_status       # pending, reviewed, verified
      t.references :reviewer, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
```

### Effort Estimate

| Task | Effort |
|------|--------|
| Set up OCR pipeline (Surya local) | 1-2 days |
| Build post-processing service | 2-3 days |
| Process 100 pages | ~1 hour (automated) + 2-4 hours (review) |
| Process 1000 pages | ~1 day (automated) + 2-3 days (review) |

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

## Phase 4: Dialect AI

**Goal:** Create an AI that writes authentic Mayo Irish — not "textbook" Irish, but the actual dialect with its distinctive vocabulary, grammar, and idioms.

**Approach:** Fine-tune an open-source LLM (Llama 3 8B or 70B) using Unsloth/QLoRA on your translated phrase pairs.

### Why Standard Irish AI Fails for Mayo

| Standard Irish | Mayo Irish | Type |
|----------------|------------|------|
| is féidir leat | tig leat | Modal construction |
| tagann sé | tigeann sé | Verb form |
| ag dul | ag goil | Verbal noun |
| anseo | anso | Pronunciation spelling |
| cad é | caidé | Question word |

These aren't random variations — they're systematic patterns a model can learn.

### Training Data Format

Your existing `DictionaryEntry` records are perfect:

```json
[
  {
    "instruction": "Translate to Mayo Irish (Gaeilge Mhaigh Eo)",
    "input": "You can do it if you try",
    "output": "Tig leat é a dhéanamh má dhéanann tú iarracht"
  },
  {
    "instruction": "Translate to Mayo Irish (Gaeilge Mhaigh Eo)",
    "input": "He comes here every day",
    "output": "Tigeann sé anso gach lá"
  }
]
```

### Export Service

```ruby
# app/services/ml_export/dialect_dataset_service.rb
module MlExport
  class DialectDatasetService
    def initialize(output_dir:, dialect: :tuaisceart_mhaigh_eo)
      @output_dir = Pathname.new(output_dir)
      @dialect = dialect
    end

    def call
      entries = DictionaryEntry
        .joins(:speaker)
        .where(users: { dialect: @dialect })
        .where(accuracy_status: :confirmed)
        .where.not(translation: [nil, ''])
        .where.not(word_or_phrase: [nil, ''])

      dataset = entries.map do |entry|
        {
          instruction: "Translate to Mayo Irish (Gaeilge Mhaigh Eo)",
          input: entry.translation.strip,
          output: entry.word_or_phrase.strip
        }
      end

      # Split 90/10 train/validation
      dataset.shuffle!
      split_idx = (dataset.size * 0.9).to_i

      File.write(@output_dir.join('train.jsonl'), dataset[0...split_idx].map(&:to_json).join("\n"))
      File.write(@output_dir.join('val.jsonl'), dataset[split_idx..].map(&:to_json).join("\n"))

      puts "Exported #{dataset.size} entries (#{split_idx} train, #{dataset.size - split_idx} val)"
    end
  end
end
```

### Fine-tuning with Unsloth

Unsloth makes LoRA fine-tuning fast and memory-efficient:

```python
# scripts/finetune_dialect.py
from unsloth import FastLanguageModel
import torch

# Load model with 4-bit quantization
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/llama-3-8b-bnb-4bit",  # or 70b for better quality
    max_seq_length=2048,
    load_in_4bit=True,
)

# Add LoRA adapters
model = FastLanguageModel.get_peft_model(
    model,
    r=16,  # LoRA rank
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_alpha=16,
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",
)

# Format dataset
def format_prompt(example):
    return f"""### Instruction:
{example['instruction']}

### Input:
{example['input']}

### Response:
{example['output']}"""

# Load your exported data
from datasets import load_dataset
dataset = load_dataset('json', data_files={
    'train': 'ml_exports/dialect/train.jsonl',
    'validation': 'ml_exports/dialect/val.jsonl'
})

# Training
from trl import SFTTrainer
from transformers import TrainingArguments

trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset['train'],
    eval_dataset=dataset['validation'],
    formatting_func=format_prompt,
    max_seq_length=2048,
    args=TrainingArguments(
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        warmup_steps=100,
        max_steps=1000,  # Adjust based on dataset size
        learning_rate=2e-4,
        fp16=not torch.cuda.is_bf16_supported(),
        bf16=torch.cuda.is_bf16_supported(),
        logging_steps=10,
        output_dir="outputs/mayo-irish-llama",
        evaluation_strategy="steps",
        eval_steps=100,
    ),
)

trainer.train()

# Save the LoRA adapter
model.save_pretrained("mayo-irish-llama-lora")
```

### Hardware Requirements

| Model | Quantization | RAM/VRAM | M4 64GB? | Training Time |
|-------|-------------|----------|----------|---------------|
| Llama 3 8B | 4-bit QLoRA | ~6GB | ✅ Yes | 2-6 hours |
| Llama 3 70B | 4-bit QLoRA | ~40GB | ✅ Yes (tight) | 12-24 hours |
| Mistral 7B | 4-bit QLoRA | ~5GB | ✅ Yes | 2-4 hours |

**Note:** M4 Mac training uses MPS (Metal Performance Shaders). It's slower than CUDA but works. For the 70B model, cloud GPU recommended.

### Deployment Options

**Option A: Local via Ollama**
```bash
# Export to GGUF format
python -m unsloth.save_to_gguf mayo-irish-llama-lora --quantization q4_k_m

# Import to Ollama
ollama create mayo-irish -f Modelfile

# Use locally
ollama run mayo-irish "Translate: How are you today?"
```

**Option B: API Service**
```ruby
# app/services/dialect_translation_service.rb
class DialectTranslationService
  OLLAMA_URL = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')

  def translate_to_mayo(english_text)
    response = HTTParty.post("#{OLLAMA_URL}/api/generate", body: {
      model: 'mayo-irish',
      prompt: "### Instruction:\nTranslate to Mayo Irish\n\n### Input:\n#{english_text}\n\n### Response:\n",
      stream: false
    }.to_json)

    JSON.parse(response.body)['response'].strip
  end
end
```

### Integration with GPT-4 (Hybrid Approach)

For complex tasks, use GPT-4 for intelligence + Mayo model for dialect accuracy:

```ruby
class MayoIrishGeneratorService
  def generate(prompt)
    # Step 1: GPT-4 generates content (in English or standard Irish)
    draft = GptService.generate(
      system: "Generate a response in simple English that can be translated.",
      user: prompt
    )

    # Step 2: Fine-tuned model converts to Mayo Irish
    mayo_irish = DialectTranslationService.new.translate_to_mayo(draft)

    # Step 3: Deterministic post-process for any remaining misses
    DialectPostProcessor.new.apply_rules(mayo_irish)
  end
end
```

### Evaluation

Test on held-out phrases:

| Metric | What It Measures |
|--------|------------------|
| **BLEU score** | N-gram overlap with reference translations |
| **Dialect accuracy** | % of Mayo-specific constructions correctly used |
| **Human evaluation** | Native speaker ratings on naturalness |

### Estimated Effort

| Task | Effort |
|------|--------|
| Export dataset | 1 day |
| Fine-tune model | 1-2 days (mostly training time) |
| Evaluation | 1 day |
| Integration | 1-2 days |
| **Total** | 1-2 weeks |

### Data Requirements

| Dataset Size | Expected Quality |
|--------------|------------------|
| 500 phrases | Basic dialect patterns |
| 1,000 phrases | Good coverage of common constructions |
| 5,000+ phrases | Robust, handles edge cases |
| 10,000+ phrases | Near-native quality |

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

---

## Appendix: Scanning Equipment Guide

### Quick Recommendations

| Scenario | Recommended Setup | Budget |
|----------|-------------------|--------|
| **Small project (<100 pages)** | Smartphone + good lighting | Free |
| **Medium project (100-1000 pages)** | Document scanner or book scanner | €200-500 |
| **Large archive (1000+ pages)** | Overhead book scanner | €500-2000 |
| **Professional/fragile materials** | Professional digitization service | Variable |

### Smartphone Scanning (Budget Option)

Modern smartphones produce excellent results with proper technique.

**Apps:**
- **Adobe Scan** (free) — automatic edge detection, perspective correction
- **Microsoft Lens** (free) — good OCR built-in
- **vFlat Scan** (free) — specifically designed for books, handles curved pages
- **Genius Scan** (free/paid) — batch scanning, good organization

**Tips for smartphone scanning:**
- Use natural daylight or two lights at 45° angles (reduces shadows)
- Keep phone parallel to page (not angled)
- Use a tripod or phone mount for consistency
- Shoot in RAW if possible for better OCR results
- Disable flash (creates hotspots)

**DIY book scanning rig:**
```
        [Phone/Camera mounted above]
                   │
                   ▼
    ┌─────────────────────────────┐
    │                             │
    │     ┌───────────────┐      │
    │     │               │      │
    │     │     Book      │      │  ← Glass/acrylic to flatten pages
    │     │               │      │
    │     └───────────────┘      │
    │                             │
    └─────────────────────────────┘
         ↑                   ↑
      Light               Light
     (45° angle)        (45° angle)
```

### Document Scanners (Flatbed)

Good for loose pages, pamphlets, unbound materials.

| Scanner | Resolution | Speed | Price | Notes |
|---------|------------|-------|-------|-------|
| **Epson Perfection V600** | 6400 DPI | ~15 sec/page | ~€250 | Great quality, good software |
| **Canon CanoScan LiDE 400** | 4800 DPI | ~8 sec/page | ~€80 | Fast, portable, USB-powered |
| **Fujitsu ScanSnap iX1600** | 600 DPI | 40 pages/min | ~€400 | ADF, batch scanning |

**When to use flatbed:**
- Loose pages or pamphlets
- High-quality scans of covers/illustrations
- Materials that can be unbound

### Overhead Book Scanners

Essential for bound books that can't be pressed flat.

| Scanner | Type | Price | Notes |
|---------|------|-------|-------|
| **CZUR ET24 Pro** | Overhead + laser flatten | ~€350 | Auto page-curve correction |
| **IRIScan Desk 6** | Overhead | ~€250 | Good for books |
| **Fujitsu ScanSnap SV600** | Overhead | ~€600 | Professional quality |
| **DIY V-cradle + camera** | Custom | ~€100-200 | Flexible, requires setup |

**CZUR scanners** are particularly good value — they use laser lines to detect page curvature and automatically flatten the image in software.

### V-Cradle Setup (For Fragile Books)

For valuable or fragile materials, a V-cradle keeps the book at a safe angle:

```
           [Camera above]
                 │
                 ▼
         ┌───────────────┐
        /                 \
       /    Book spine     \
      /      ↓↓↓↓↓          \
     /   ┌─────────┐         \
    /    │  Page   │          \
   ┴─────┴─────────┴───────────┴

   V-cradle at 90-120° angle
   Glass/acrylic presses page flat
```

**Benefits:**
- Spine isn't stressed (book doesn't open flat)
- Consistent positioning
- One page at a time (no gutter shadow)

### Lighting

Poor lighting is the #1 cause of bad OCR results.

**Requirements:**
- Even illumination across the page
- No shadows (especially from phone/camera)
- No hotspots or reflections
- Colour temperature ~5000-6500K (daylight)

**Budget setup:**
- Two desk lamps at 45° angles
- Daylight LED bulbs (5000K+)
- Diffusers (even a white sheet works)

**Better setup:**
- LED light panels (e.g., Neewer, Viltrox)
- Positioned 45° from each side
- ~€50-100 for a pair

### Recommended Settings

| Parameter | Value | Why |
|-----------|-------|-----|
| **Resolution** | 300 DPI minimum, 600 for small text | Below 300 DPI, OCR accuracy drops |
| **Colour mode** | Greyscale for text, Colour for illustrations | Smaller files, faster processing |
| **Format** | PNG or TIFF (lossless) | JPEG compression hurts OCR |
| **Bit depth** | 8-bit greyscale / 24-bit colour | Standard for OCR |

### Workflow for Batch Scanning

```
1. PREPARATION
   ├── Number pages lightly in pencil (if needed)
   ├── Remove loose inserts, note their position
   └── Clean scanner glass / lens

2. SCANNING
   ├── Scan in batches of 20-50 pages
   ├── Check first few images for quality
   ├── Maintain consistent positioning
   └── Save with sequential naming: book_001.png, book_002.png

3. POST-CAPTURE
   ├── Review images for problems (blur, shadow, cut-off)
   ├── Re-scan problem pages immediately
   ├── Rotate/crop if needed (ScanTailor is excellent for this)
   └── Convert to final format

4. ORGANIZATION
   ├── Folder per source: /scans/book_title_year/
   ├── Metadata file: source.json with title, author, year, etc.
   └── Backup before processing
```

### Software for Post-Processing

| Tool | Purpose | Platform | Cost |
|------|---------|----------|------|
| **ScanTailor Advanced** | Page cleanup, deskew, crop | Win/Mac/Linux | Free |
| **Unpaper** | Clean up scanned pages | Linux/Mac | Free |
| **ImageMagick** | Batch processing | All | Free |
| **GIMP** | Manual image editing | All | Free |
| **Adobe Acrobat** | PDF assembly, OCR | All | Paid |

**ScanTailor workflow:**
1. Load images → auto-detect pages
2. Deskew (straighten tilted pages)
3. Split pages (if scanning two-up)
4. Select content area
5. Remove margins/noise
6. Export clean images for OCR

### Professional Digitization Services

For large or valuable collections, professional services may be cost-effective:

| Service | Specialization | Notes |
|---------|----------------|-------|
| **Internet Archive** | Free digitization (if donated) | Books become publicly available |
| **Local libraries** | May offer digitization services | Check university libraries |
| **National Library of Ireland** | Irish heritage materials | May digitize significant collections |
| **Commercial services** | Volume digitization | 1DollarScan, ScanCafe, etc. |

### Cost-Benefit Analysis

| Method | Time per 100 pages | Quality | Total Cost |
|--------|-------------------|---------|------------|
| **Smartphone + app** | 2-3 hours | Good | Free |
| **Flatbed scanner** | 3-4 hours | Excellent | €80-250 (one-time) |
| **Overhead scanner** | 1-2 hours | Very good | €250-600 (one-time) |
| **Professional service** | 0 (your time) | Excellent | €50-200 |

### Recommendations by Project Scale

**Just getting started (testing the pipeline):**
- Use smartphone + Adobe Scan or vFlat
- Scan 20-30 pages as a test
- Validate OCR quality before investing in equipment

**Regular scanning (ongoing project):**
- CZUR ET24 Pro (~€350) — best value for books
- Or Fujitsu ScanSnap iX1600 (~€400) if mostly loose pages

**Serious archival work:**
- Fujitsu ScanSnap SV600 or professional overhead scanner
- Proper lighting rig
- V-cradle for fragile materials
- Consider partnering with a library or archive
