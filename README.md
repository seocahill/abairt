# Abairt

**A comprehensive Irish language learning and corpus platform**

[![Live Demo](https://img.shields.io/badge/demo-live-brightgreen)](https://abairt.com)
[![License](https://img.shields.io/badge/license-Open_Source-blue)](LICENSE)
[![Ruby](https://img.shields.io/badge/ruby-3.4-red)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/rails-7.1-red)](https://rubyonrails.org/)

Abairt is an open-source platform for Irish language learning, featuring voice recording transcription, dictionary management, and comprehensive language tools. Share, search, and download Irish sentences, translations, and pronunciations with advanced AI-powered features.

## ✨ Features

### 🎙️ Voice & Audio Processing
- **Voice Recording Management** - Upload, transcribe, and manage Irish language recordings
- **Speaker Diarization** - Automatically identify and separate different speakers using Pyannote.ai
- **Audio Import** - Support for YouTube, RTÉ.ie, and Canuint.ie content import
- **Text-to-Speech** - Generate Irish pronunciations using Abair.ie TTS
- **Speech-to-Text** - Transcribe audio using TCD Phonetics ASR service

### 📚 Dictionary & Language Tools
- **Collaborative Dictionary** - User-generated Irish-English dictionary entries
- **Smart Tagging** - AI-powered automatic tagging of content
- **Word Lists** - Create and manage custom vocabulary lists
- **Full-Text Search** - Fast FTS5-powered search across all content
- **CSV Export** - Export word lists for Anki and other SRS applications

### 🌍 Community & Learning
- **User Authentication** - Secure user accounts and permissions
- **Practice Mode** - Interactive pronunciation practice
- **Translator Leaderboard** - Gamified contribution tracking
- **Admin Panel** - Comprehensive administrative interface

### 🔧 Technical Features
- **AI Integration** - OpenAI GPT for vocabulary extraction and translation
- **Service Monitoring** - Real-time health monitoring of external APIs
- **Email System** - Mailjet-powered email notifications and broadcasts
- **Responsive Design** - Modern UI with Tailwind CSS and Hotwire
- **API Endpoints** - RESTful API for external integrations

## 🚀 Quick Start

### Prerequisites

- Ruby 3.4+
- Node.js and npm
- Docker and Docker Compose
- SQLite 3 (primary database)

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone https://gitlab.com/abairt/web-application
   cd abairt
   ```

2. **Install dependencies**
   ```bash
   bundle install
   npm install
   ```

3. **Start services with Docker**
   ```bash
   docker-compose up -d
   ```

4. **Setup database**
   ```bash
   rails db:prepare
   rails db:seed  # Optional: load sample data
   ```

5. **Install external tools**
   ```bash
   # For YouTube import functionality
   pip install yt-dlp
   ```

6. **Start the server**
   ```bash
   rails server
   ```

7. **Visit** http://localhost:3000

### Environment Configuration

Create a `.env` file with required credentials:

```bash
# External Services
OPENAI_ACCESS_TOKEN=your_openai_compatiable_api_key
MAILJET_API_KEY=your_mailjet_key
MAILJET_SECRET_KEY=your_mailjet_secret

# For production proxy (optional)
PROXY_HOST=your_proxy_host
PROXY_USER=your_proxy_user
PROXY_PASS=your_proxy_password
PROXY_PORT=10001

# Sentry error tracking (optional)
SENTRY_DSN=your_sentry_dsn
```

## 🏗️ Architecture

### Database
- **Primary**: SQLite with Litestack for production performance
- **FTS**: Full-text search via SQLite FTS5 virtual tables
- **Backups**: Litestream for continuous backup and replication

### Key Models
- **DictionaryEntry** - Core translation pairs with metadata
- **VoiceRecording** - Audio files with transcriptions and speakers
- **User** - Authentication and user management
- **WordList** - Custom vocabulary collections
- **ServiceStatus** - Health monitoring for external APIs

### External Services
- **Abair.ie** - Irish text-to-speech synthesis
- **TCD Phonetics** - Automatic speech recognition
- **Pyannote.ai** - Speaker diarization and identification
- **OpenAI GPT** - AI-powered content analysis and translation

## 🔧 Development

### Testing
```bash
# Run full test suite
rails test

# Run specific test files
rails test test/models/dictionary_entry_test.rb
```

### Database Management

**PostgreSQL to SQLite migration**:
```bash
gem install sequel
sequel -C postgres://postgres@localhost:5432/abairt_development sqlite://db/development.sqlite3
```

**FTS index maintenance**:
```bash
rails runner "
ActiveRecord::Base.connection.execute(\"INSERT INTO fts_dictionary_entries(fts_dictionary_entries) VALUES('rebuild')\")
"
```

### Service Monitoring
```bash
# Manual service health check
bundle exec rake cron:monitor_services

# View status page
open http://localhost:3000/status
```

### Visual Debugging with VNC (Production)

To visually debug browser automation (e.g., Fotheidil uploads) in production:

1. **Create SSH tunnel from your local machine:**
   ```bash
   ssh -i ~/.ssh/old/id_rsa -L 17900:127.0.0.1:7900 -N root@<your-server-ip>
   ```
   Keep this terminal open. The `-N` flag keeps it running without opening a shell.

2. **Open VNC in your browser:**
   ```
   http://localhost:17900
   ```
   You'll see the noVNC interface showing the Selenium Grid status.

3. **Enable headful mode** (if not already enabled):
   Ensure `SELENIUM_HEADFUL: "true"` is set in `docker-compose.production.yml` rails service environment.

4. **Run your operation:**
   When you run Fotheidil operations, you'll see the browser automation happening in real-time in the VNC viewer.

**Note:** The VNC service is exposed on port 7900 on the server. The SSH tunnel forwards your local port 17900 to the server's port 7900.

## 📦 Deployment

The application supports Docker-based deployment and is production-ready with:
- SQLite database with Litestack for production performance
- Background job processing via Litequeue
- Comprehensive error tracking and monitoring
- Asset compilation and optimization

### Docker Deployment
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## 🤝 Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following Rails conventions
4. Add tests for new functionality
5. Ensure all tests pass (`rails test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to your branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Development Guidelines
- Follow Rails conventions and idioms
- Use existing patterns and services
- Write tests for new features
- Update documentation as needed
- Check for existing gems before creating custom solutions

## 📄 License

This project is open source. Please check the LICENSE file for specific terms.

## 🙏 Acknowledgments

- **Abair.ie** - Irish TTS service
- **TCD Phonetics** - Speech recognition
- **Pyannote.ai** - Speaker diarization
- **RTÉ** - Irish media content
- **OpenAI** - AI language processing
- Irish language community and contributors

## 📞 Support

- **Issues**: Report bugs and request features via GitHub Issues
- **Status Page**: Monitor service health at `/status`

---

**Abairt** - Empowering Irish language learning through technology 🇮🇪