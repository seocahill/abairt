import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';
import TimelinePlugin from 'wavesurfertimelinejs';

export default class extends Controller {
  static targets = ["waveform", "playButton", "timeDisplay", "transcription", "translation",
                    "gaeSubs", "engSubs", "speed", "video", "editButton", "zoom", "timelineContainer"]
  static values = {
    url: String,
    regionsUrl: String,
    lazy: Boolean,
    editMode: Boolean,
    entryUpdateUrlTemplate: String
  }

  connect() {
    if (!this.hasWaveformTarget) return;

    if (!this.lazyValue) {
      this.initializeWaveform();
    } else {
      this.showDummyWaveform();
    }
  }

  disconnect() {
    this.waveSurfer?.destroy();
  }

  // ─── Dummy waveform (shown while loading) ─────────────────────────────────

  showDummyWaveform() {
    const container = this.waveformTarget;
    if (document.getElementById('waveform-placeholder')) return;

    const width = container.offsetWidth || 800;
    const height = parseInt(container.style.height) || 80;

    container.style.position ||= 'relative';

    const placeholder = document.createElement('div');
    placeholder.id = 'waveform-placeholder';
    placeholder.style.cssText = 'position: absolute; top: 0; left: 0; right: 0; bottom: 0; z-index: 10; pointer-events: none; background: white;';

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("width", width);
    svg.setAttribute("height", height);
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
    svg.style.cssText = "display: block; width: 100%; height: 100%; background: transparent;";

    const barWidth = 2, barGap = 3, totalBarWidth = barWidth + barGap;
    const barCount = Math.floor(width / totalBarWidth);

    for (let i = 0; i < barCount; i++) {
      const barHeight = Math.random() * (height - 20) + 10;
      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      rect.setAttribute("x", i * totalBarWidth);
      rect.setAttribute("y", (height - barHeight) / 2);
      rect.setAttribute("width", barWidth);
      rect.setAttribute("height", barHeight);
      rect.setAttribute("rx", "3");
      rect.setAttribute("fill", "#E5E7EB");
      svg.appendChild(rect);
    }

    placeholder.appendChild(svg);
    container.appendChild(placeholder);
  }

  removePlaceholder() {
    document.getElementById('waveform-placeholder')?.remove();
  }

  // ─── Playback ─────────────────────────────────────────────────────────────

  async play() {
    if (!this.waveSurfer) {
      this.shouldAutoPlay = true;
      await this.initializeWaveform();
    } else {
      this.waveSurfer.playPause();
    }
  }

  // ─── Initialisation ───────────────────────────────────────────────────────

  async initializeWaveform() {
    if (this.hasPlayButtonTarget) this.playButtonTarget.disabled = true;

    try {
      this.showDummyWaveform();

      const plugins = [
        RegionsPlugin.create({ dragSelection: false, regions: [] })
      ];

      if (this.hasTimelineContainerTarget) {
        plugins.push(
          TimelinePlugin.create({
            container: this.timelineContainerTarget,
            notchPercentHeight: 80,
            labelPadding: 5,
            fontSize: 10,
            primaryColor: '#6B7280',
            secondaryColor: '#9CA3AF',
            primaryFontColor: '#374151',
            secondaryFontColor: '#6B7280'
          })
        );
      }

      this.waveSurfer = WaveSurfer.create({
        container: this.waveformTarget,
        waveColor: '#6366F1',
        progressColor: '#312E81',
        cursorColor: '#F59E0B',
        barWidth: 2,
        barRadius: 3,
        cursorWidth: 1,
        height: 80,
        barGap: 3,
        responsive: true,
        normalize: true,
        backend: 'MediaElement',
        mediaControls: false,
        plugins
      });

      this.setupWaveformEventListeners();

      if (this.hasVideoTarget) {
        await this.waveSurfer.load(this.videoTarget);
      } else {
        const audio = document.createElement('audio');
        audio.preload = 'metadata';
        audio.crossOrigin = 'anonymous';
        audio.src = this.urlValue;
        await this.waveSurfer.load(audio);
      }

      if (this.hasRegionsUrlValue) {
        await this.fetchAndAddRegions();
      }

      if (this.hasPlayButtonTarget) this.playButtonTarget.disabled = false;
    } catch (error) {
      console.error('Error initializing waveform:', error);
      if (this.hasPlayButtonTarget) this.playButtonTarget.disabled = true;
    }
  }

  setupWaveformEventListeners() {
    this.waveSurfer.on('ready', () => {
      this.isReady = true;
      if (this.hasPlayButtonTarget) this.playButtonTarget.disabled = false;
      this.setupPitchPreservation();
      setTimeout(() => this.removePlaceholder(), 100);
      this._initZoom();
      if (this.shouldAutoPlay) {
        this.shouldAutoPlay = false;
        this.waveSurfer.play();
      }
    });

    this.waveSurfer.on('play', () => this.updatePlayButtonState(true));
    this.waveSurfer.on('pause', () => this.updatePlayButtonState(false));
    this.waveSurfer.on('finish', () => this.updatePlayButtonState(false));

    this.waveSurfer.on('audioprocess', () => {
      if (!this.waveSurfer.isPlaying()) return;
      const t = this.waveSurfer.getCurrentTime();
      if (this.hasTimeDisplayTarget) this.timeDisplayTarget.textContent = this.formatTime(t);
      this.highlightCurrentEntry(t);
    });

    this.waveSurfer.on('seek', () => {
      const t = this.waveSurfer.getCurrentTime();
      if (this.hasTimeDisplayTarget) this.timeDisplayTarget.textContent = this.formatTime(t);
      this.highlightCurrentEntry(t);
    });

    if (this.hasTranscriptionTarget && this.hasTranslationTarget) {
      this.waveSurfer.on('region-in', (region) => {
        if (this.hasGaeSubsTarget && this.gaeSubsTarget.checked)
          this.transcriptionTarget.textContent = region.data.transcription;
        if (this.hasEngSubsTarget && this.engSubsTarget.checked)
          this.translationTarget.textContent = region.data.translation;
      });

      this.waveSurfer.on('region-out', () => {
        if (this.hasTranscriptionTarget) this.transcriptionTarget.textContent = "";
        if (this.hasTranslationTarget) this.translationTarget.textContent = "";
      });
    }
  }

  // ─── Regions ──────────────────────────────────────────────────────────────

  async fetchAndAddRegions() {
    try {
      const response = await fetch(this.regionsUrlValue);
      if (!response.ok) throw new Error('Failed to fetch regions');
      this._regionsData = await response.json();
      this._renderRegions();
    } catch (error) {
      console.error('Error fetching regions:', error);
    }
  }

  _renderRegions() {
    if (!this.waveSurfer || !this._regionsData) return;

    this.waveSurfer.clearRegions();
    const editable = this.editModeValue;

    this._regionsData.forEach(region => {
      if (region.region_start == null || region.region_end == null) return;
      this.waveSurfer.addRegion({
        start: parseFloat(region.region_start),
        end: parseFloat(region.region_end),
        drag: editable,
        resize: editable,
        color: editable ? 'rgba(234, 179, 8, 0.25)' : 'rgba(99, 102, 241, 0.12)',
        data: {
          id: region.id,
          transcription: region.word_or_phrase,
          translation: region.translation
        }
      });
    });

    if (editable) this._setupRegionUpdateListener();
  }

  _setupRegionUpdateListener() {
    if (this._regionUpdateHandler) {
      this.waveSurfer.un('region-update-end', this._regionUpdateHandler);
    }

    this._regionUpdateHandler = async (region) => {
      const entryId = region.data?.id;
      if (!entryId || !this.hasEntryUpdateUrlTemplateValue) return;

      const url = this.entryUpdateUrlTemplateValue.replace('ENTRY_ID', entryId);
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;

      try {
        const response = await fetch(url, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken,
            'Accept': 'application/json'
          },
          body: JSON.stringify({
            dictionary_entry: {
              region_start: region.start.toFixed(3),
              region_end: region.end.toFixed(3)
            }
          })
        });

        if (!response.ok) {
          console.error('Failed to update segment boundary:', await response.text());
        }
      } catch (error) {
        console.error('Error patching segment boundary:', error);
      }
    };

    this.waveSurfer.on('region-update-end', this._regionUpdateHandler);
  }

  // ─── Edit mode ────────────────────────────────────────────────────────────

  toggleEditMode() {
    this.editModeValue = !this.editModeValue;
    this._renderRegions();
    this._updateEditButton();
    this._applyEditModeLayout();
  }

  _updateEditButton() {
    if (!this.hasEditButtonTarget) return;
    const btn = this.editButtonTarget;
    if (this.editModeValue) {
      btn.classList.remove('text-gray-400', 'hover:text-gray-600');
      btn.classList.add('text-yellow-500', 'hover:text-yellow-600');
      btn.title = 'Exit segment edit mode';
    } else {
      btn.classList.remove('text-yellow-500', 'hover:text-yellow-600');
      btn.classList.add('text-gray-400', 'hover:text-gray-600');
      btn.title = 'Edit segment boundaries';
    }
  }

  _applyEditModeLayout() {
    const layout    = document.getElementById('recording-layout');
    const leftPanel = document.getElementById('recording-left-panel');
    const infoboxes = document.getElementById('recording-infoboxes');
    const rightPanel = document.getElementById('recording-right-panel');

    if (!layout) return; // not on the show page

    if (this.editModeValue) {
      // Stack waveform above entries, spanning full width
      layout.style.flexDirection = 'column';

      if (leftPanel) {
        leftPanel.style.width      = '100%';
        leftPanel.style.maxHeight  = 'none';
        leftPanel.style.overflow   = 'visible';
        leftPanel.style.flexShrink = '0';
        leftPanel.style.borderRight = 'none';
      }

      if (infoboxes) infoboxes.style.display = 'none';

      if (rightPanel) {
        rightPanel.style.width = '100%';
      }
    } else {
      // Restore two-column layout
      layout.style.flexDirection = '';

      if (leftPanel) {
        leftPanel.style.cssText = '';
      }

      if (infoboxes) infoboxes.style.display = '';

      if (rightPanel) {
        rightPanel.style.width = '';
      }
    }

    // Give the browser one frame to reflow, then redraw the waveform at new width
    requestAnimationFrame(() => {
      if (this.isReady && this.waveSurfer) {
        this.waveSurfer.zoom(this._currentZoom());
      }
    });
  }

  // ─── Zoom ─────────────────────────────────────────────────────────────────

  _currentZoom() {
    return this.hasZoomTarget ? parseFloat(this.zoomTarget.value) : 1;
  }

  _initZoom() {
    if (!this.waveSurfer || !this.isReady) return;
    const duration = this.waveSurfer.getDuration();
    if (!duration) return;

    const containerWidth = this.waveformTarget.offsetWidth || 800;
    const fitZoom = Math.max(1, Math.floor(containerWidth / duration));

    if (this.hasZoomTarget) this.zoomTarget.value = fitZoom;
    this.waveSurfer.zoom(fitZoom);
  }

  zoom(event) {
    event.preventDefault();
    if (!this.waveSurfer || !this.isReady) return;
    this.waveSurfer.zoom(parseFloat(event.currentTarget.value));
  }

  resetZoom() {
    this._initZoom();
  }

  // ─── Playback speed ───────────────────────────────────────────────────────

  changeSpeed(event) {
    event.preventDefault();
    if (!this.waveSurfer) return;
    const speed = parseFloat(event.currentTarget.value);
    const media = this.waveSurfer.backend?.media;
    if (media) {
      media.playbackRate = speed;
    } else {
      this.waveSurfer.setPlaybackRate(speed);
    }
  }

  // ─── Pitch preservation ───────────────────────────────────────────────────

  setupPitchPreservation() {
    const media = this.waveSurfer.backend?.media;
    if (!media) return;
    media.preservesPitch = true;
    media.mozPreservesPitch = true;
    media.webkitPreservesPitch = true;
  }

  // ─── Highlight current entry ──────────────────────────────────────────────

  highlightCurrentEntry(currentTime) {
    document.querySelectorAll('.waveform-active-entry').forEach(el => {
      el.classList.remove('waveform-active-entry', 'bg-blue-50', 'border-blue-500', 'border-2', 'shadow-lg', 'scale-[1.02]');
    });

    const regions = this.waveSurfer.regions?.list;
    if (!regions) return;

    const currentRegion = Object.values(regions).find(r =>
      currentTime >= r.start && currentTime <= r.end
    );

    if (currentRegion?.data?.id) {
      this.findAndHighlightEntry(currentRegion.data.id);
    }
  }

  async findAndHighlightEntry(entryId) {
    let el = document.getElementById(`dictionary_entry_${entryId}`);

    if (!el) {
      const success = await this.loadEntryIfNeeded(entryId);
      if (success) el = document.getElementById(`dictionary_entry_${entryId}`);
    }

    if (el) this.highlightAndScrollToEntry(el);
  }

  async loadEntryIfNeeded(entryId) {
    const infiniteScrollEl = document.querySelector('[data-controller*="infinite-scroll"]');
    if (!infiniteScrollEl) return false;

    const ctrl = this.application.getControllerForElementAndIdentifier(infiniteScrollEl, 'infinite-scroll');
    if (!ctrl) return false;

    for (let i = 0; i < 10; i++) {
      if (!document.querySelector("a[rel='next']")) return false;
      await ctrl.loadMore();
      await new Promise(r => setTimeout(r, 300));
      if (document.getElementById(`dictionary_entry_${entryId}`)) return true;
    }
    return false;
  }

  highlightAndScrollToEntry(el) {
    el.classList.add('waveform-active-entry', 'bg-blue-50', 'border-blue-500', 'border-2', 'shadow-lg', 'scale-[1.02]');
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

  updatePlayButtonState(isPlaying) {
    if (!this.hasPlayButtonTarget) return;
    const btn = this.playButtonTarget;
    const svg = btn.querySelector('svg');
    const span = btn.querySelector('span');

    if (isPlaying) {
      if (svg) svg.innerHTML = '<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />';
      if (span) span.textContent = 'Pause';
      btn.setAttribute('aria-label', 'Pause');
    } else {
      if (svg) svg.innerHTML = '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" />';
      if (span) span.textContent = 'Play';
      btn.setAttribute('aria-label', 'Play');
    }
  }

  formatTime(seconds) {
    const s = Math.floor(seconds);
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  }
}
