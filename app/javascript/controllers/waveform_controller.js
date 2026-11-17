import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurferjs"
import RegionsPlugin from 'wavesurferregionsjs';
import TimelinePlugin from 'wavesurfertimelinejs';

export default class extends Controller {
  static targets = ["waveform", "playButton", "timeDisplay", "transcription", "translation",
                    "gaeSubs", "engSubs", "speed", "video", "editButton", "zoom", "timelineContainer", "startButton", "loopButton", "shortcuts"]
  static values = {
    url: String,
    regionsUrl: String,
    peaksUrl: String,
    lazy: Boolean,
    editMode: Boolean,
    entryUpdateUrlTemplate: String,
    startAt: Number,
    startEntryId: Number,
    listening: Boolean,
    earlyPlay: Boolean,
    title: String,
    artist: String
  }

  connect() {
    if (!this.hasWaveformTarget) return;

    if (this.listeningValue) this.bindListeningControls();

    if (!this.lazyValue) {
      this.initializeWaveform();
    } else {
      this.showDummyWaveform();
    }
  }

  disconnect() {
    this.unbindListeningControls();
    this.waveSurfer?.destroy();
  }

  // ─── Listening controls (f81_listening_controls) ──────────────────────────

  bindListeningControls() {
    this._onLineSeek = (event) => this.seekToLine(event.detail.start, event.detail.end);
    this._onKeydown = (event) => this.handleKey(event);
    window.addEventListener('line:seek', this._onLineSeek);
    document.addEventListener('keydown', this._onKeydown);
    this.looping = false;
    this.loopLine = null;
  }

  unbindListeningControls() {
    if (this._onLineSeek) window.removeEventListener('line:seek', this._onLineSeek);
    if (this._onKeydown) document.removeEventListener('keydown', this._onKeydown);
    if (this.listeningValue && 'mediaSession' in navigator) this.clearMediaSession();
  }

  // Lines with a start and end, in playing order.
  lines() {
    return (this._regionsData || [])
      .filter(r => r.region_start != null && r.region_end != null)
      .map(r => ({ start: parseFloat(r.region_start), end: parseFloat(r.region_end) }))
      .sort((a, b) => a.start - b.start);
  }

  async seekToLine(start, end) {
    if (!this.isReady) {
      this.pendingLine = { start, end };
      if (!this.waveSurfer) await this.initializeWaveform();
      return;
    }
    if (this.looping) this.loopLine = { start, end };
    this.seekSeconds(start);
    this.waveSurfer.play();
  }

  seekSeconds(seconds) {
    const duration = this.waveSurfer.getDuration();
    if (duration) this.waveSurfer.seekTo(Math.min(Math.max(seconds / duration, 0), 1));
  }

  // Repeats the looped line; called as the player moves.
  loopTick() {
    if (!this.looping || !this.loopLine || !this.waveSurfer.isPlaying()) return;
    if (this.waveSurfer.getCurrentTime() >= this.loopLine.end) this.seekSeconds(this.loopLine.start);
  }

  // If the listener moves the playhead out of the looped line, loop where they went.
  followSeek() {
    if (!this.looping) return;
    const t = this.currentTime();
    if (!this.loopLine || t < this.loopLine.start - 0.05 || t > this.loopLine.end + 0.05) {
      this.loopLine = this.lineAt(t) || this.loopLine;
    }
  }

  lineAt(time) {
    const inside = this.lines().filter(l => time >= l.start && time <= l.end);
    return inside.length ? inside[inside.length - 1] : null;
  }

  // The line under the playhead, or the last one that began before it.
  activeLine() {
    const t = this.currentTime();
    const before = this.lines().filter(l => l.start <= t);
    return this.lineAt(t) || (before.length ? before[before.length - 1] : this.lines()[0] || null);
  }

  replayLine() {
    const line = this.activeLine();
    if (line) this.seekToLine(line.start, line.end);
  }

  toggleLoop() {
    this.looping = !this.looping;
    if (this.hasLoopButtonTarget) {
      this.loopButtonTarget.setAttribute('aria-pressed', String(this.looping));
      this.loopButtonTarget.classList.toggle('bg-indigo-600', this.looping);
      this.loopButtonTarget.classList.toggle('text-white', this.looping);
    }
    this.loopLine = this.looping ? this.activeLine() : null;
  }

  previousLine() { this.stepLine(-1); }
  nextLine() { this.stepLine(1); }

  stepLine(direction) {
    const lines = this.lines();
    if (!lines.length) return;
    const t = this.currentTime();
    const current = this.activeLine();
    let index = current ? lines.indexOf(this.lines().find(l => l.start === current.start && l.end === current.end)) : -1;
    // A few seconds in, "previous" first returns to the start of this line.
    if (direction < 0 && current && t - current.start > 2) {
      return this.seekToLine(current.start, current.end);
    }
    index = Math.min(Math.max(index + direction, 0), lines.length - 1);
    this.seekToLine(lines[index].start, lines[index].end);
  }

  skip(seconds) {
    if (!this.waveSurfer || !this.isReady) return;
    this.seekSeconds(this.currentTime() + seconds);
  }

  changeSpeedBy(step) {
    if (!this.hasSpeedTarget) return;
    const options = Array.from(this.speedTarget.options);
    const index = Math.min(Math.max(this.speedTarget.selectedIndex + step, 0), options.length - 1);
    this.speedTarget.selectedIndex = index;
    this.speedTarget.dispatchEvent(new Event('change', { bubbles: true }));
  }

  handleKey(event) {
    if (event.metaKey || event.ctrlKey || event.altKey || event.shiftKey || event.repeat || event.defaultPrevented) return;
    if (this.editModeValue) return;
    const target = event.target;
    if (target.isContentEditable || target.closest?.('input, textarea, select, button, a, summary, [role=button], [role=slider], [role=tab], [role=menuitem], dialog')) return;

    const actions = {
      ' ': () => this.play(),
      ArrowLeft: () => this.previousLine(),
      ArrowRight: () => this.nextLine(),
      r: () => this.replayLine(),
      l: () => this.toggleLoop(),
      ',': () => this.changeSpeedBy(-1),
      '.': () => this.changeSpeedBy(1)
    };
    const action = actions[event.key.toLowerCase()];
    if (!action) return;
    event.preventDefault();
    action();
  }

  toggleShortcuts() {
    if (this.hasShortcutsTarget) this.shortcutsTarget.classList.toggle('hidden');
  }

  // Lock-screen and notification controls, crediting the speaker.
  setupMediaSession() {
    if (!this.listeningValue || !('mediaSession' in navigator)) return;

    if (typeof MediaMetadata !== 'undefined') {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: this.titleValue,
        artist: this.artistValue,
        album: 'Abairt'
      });
    }

    const handlers = {
      play: () => this.waveSurfer.play(),
      pause: () => this.waveSurfer.pause(),
      previoustrack: () => this.previousLine(),
      nexttrack: () => this.nextLine(),
      seekbackward: (details) => this.skip(-(details?.seekOffset || 10)),
      seekforward: (details) => this.skip(details?.seekOffset || 10),
      seekto: (details) => { if (details?.seekTime != null) this.seekSeconds(details.seekTime); }
    };
    Object.entries(handlers).forEach(([name, handler]) => {
      try { navigator.mediaSession.setActionHandler(name, handler); } catch (_) { /* unsupported action */ }
    });
  }

  clearMediaSession() {
    navigator.mediaSession.metadata = null;
    ['play', 'pause', 'previoustrack', 'nexttrack', 'seekbackward', 'seekforward', 'seekto'].forEach(name => {
      try { navigator.mediaSession.setActionHandler(name, null); } catch (_) { /* unsupported action */ }
    });
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
      this.shouldAutoPlay = false;
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

      // With stored peaks wavesurfer draws straight away and only reads the
      // media's metadata; without them it downloads and decodes the whole file.
      const peaks = await this.fetchPeaks();
      const media = this.hasVideoTarget ? this.videoTarget : this.buildAudioElement();
      if (this.earlyPlayValue) this.enablePlayWhenPlayable(media);
      await this.waveSurfer.load(media, peaks, 'metadata');

      // With early play the regions fill in behind playback and never hold the button.
      const regions = this.hasRegionsUrlValue ? this.fetchAndAddRegions() : null;
      if (this.earlyPlayValue) return;
      await regions;

      if (this.hasPlayButtonTarget) this.playButtonTarget.disabled = false;

    } catch (error) {
      this.pendingLine = null;
      console.error('Error initializing waveform:', error);
      if (this.hasPlayButtonTarget) this.playButtonTarget.disabled = true;
    }
  }

  // Early play (f125_early_play): the button works as soon as the browser
  // can play the audio, without waiting for the waveform or the regions.
  enablePlayWhenPlayable(media) {
    const enable = () => { if (this.hasPlayButtonTarget) this.playButtonTarget.disabled = false; };
    if (media.readyState >= 1) return enable();
    media.addEventListener('loadedmetadata', enable, { once: true });
    media.addEventListener('canplay', enable, { once: true });
  }

  // A shared moment link: park the player on that moment and offer a button,
  // since browsers will not start audio on their own.
  applyStartAt() {
    if (!this.hasStartAtValue || !this.hasStartButtonTarget) return;

    // Early play: the listener may already be playing; don't yank the playhead.
    if (this.waveSurfer.isPlaying()) return;

    this.startButtonTarget.classList.remove('hidden');

    const duration = this.waveSurfer.getDuration();
    if (duration) this.waveSurfer.seekTo(Math.min(this.startAtValue / duration, 1));

    if (this.hasStartEntryIdValue) {
      const el = document.getElementById(`dictionary_entry_${this.startEntryIdValue}`);
      if (el) this.highlightAndScrollToEntry(el);
    }
  }

  playFromStart() {
    this.startButtonTarget.classList.add('hidden');
    const duration = this.waveSurfer?.getDuration();
    if (duration) this.waveSurfer.seekTo(Math.min(this.startAtValue / duration, 1));
    this.waveSurfer?.play();
  }

  currentTime() {
    return this.waveSurfer?.getCurrentTime() || 0;
  }

  buildAudioElement() {
    const audio = document.createElement('audio');
    audio.preload = 'metadata';
    audio.crossOrigin = 'anonymous';
    audio.src = this.urlValue;
    return audio;
  }

  async fetchPeaks() {
    if (!this.hasPeaksUrlValue || !this.peaksUrlValue) return undefined;

    try {
      const response = await fetch(this.peaksUrlValue, { headers: { Accept: 'application/json' } });
      if (!response.ok) return undefined;
      const { data } = await response.json();
      return Array.isArray(data) && data.length > 0 ? data : undefined;
    } catch (error) {
      console.warn('Could not load waveform peaks, decoding audio instead:', error);
      return undefined;
    }
  }

  setupWaveformEventListeners() {
    // Stored peaks draw before the media is playable, and phones never report
    // "ready" with metadata-only preload, so the placeholder must not wait for it.
    this.waveSurfer.on('waveform-ready', () => this.removePlaceholder());

    this.waveSurfer.on('ready', () => {
      this.isReady = true;
      if (this.hasPlayButtonTarget) this.playButtonTarget.disabled = false;
      this.setupPitchPreservation();
      setTimeout(() => this.removePlaceholder(), 100);
      this._initZoom();
      this.applyStartAt();
      this.setupMediaSession();
      if (this.pendingLine) {
        const { start, end } = this.pendingLine;
        this.pendingLine = null;
        this.seekToLine(start, end);
      } else if (this.shouldAutoPlay) {
        this.shouldAutoPlay = false;
        if (!this.waveSurfer.isPlaying()) this.waveSurfer.play();
      }
    });

    this.waveSurfer.on('play', () => this.updatePlayButtonState(true));
    this.waveSurfer.on('pause', () => this.updatePlayButtonState(false));
    this.waveSurfer.on('finish', () => this.updatePlayButtonState(false));

    this.waveSurfer.on('audioprocess', () => {
      if (this.listeningValue) this.loopTick();
      if (!this.waveSurfer.isPlaying()) return;
      const t = this.waveSurfer.getCurrentTime();
      if (this.hasTimeDisplayTarget) this.timeDisplayTarget.textContent = this.formatTime(t);
      this.highlightCurrentEntry(t);
    });

    this.waveSurfer.on('seek', () => {
      if (this.listeningValue) this.followSeek();
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

    // Give the browser one frame to reflow, then redraw at new width.
    // When entering edit mode snap zoom to 50% of slider range for useful granularity.
    requestAnimationFrame(() => {
      if (!this.isReady || !this.waveSurfer) return;
      if (this.editModeValue) {
        const mid = Math.round((parseFloat(this.zoomTarget?.min || 1) + parseFloat(this.zoomTarget?.max || 500)) / 2);
        if (this.hasZoomTarget) this.zoomTarget.value = mid;
        this.waveSurfer.zoom(mid);
      } else {
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

    // When multiple regions overlap at currentTime, prefer the most specific
    // (latest-starting) one — it's the innermost/narrowest match.
    const matchingRegions = Object.values(regions).filter(r =>
      currentTime >= r.start && currentTime <= r.end
    );
    const currentRegion = matchingRegions.length > 0
      ? matchingRegions.reduce((best, r) => r.start > best.start ? r : best)
      : null;

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
