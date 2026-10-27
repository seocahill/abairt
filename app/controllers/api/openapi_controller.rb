# frozen_string_literal: true

module Api
  class OpenapiController < ActionController::API
    def show
      render json: openapi_schema
    end

    private

    def openapi_schema
      {
        openapi: "3.0.0",
        info: {
          title: "Abairt Transcription API",
          version: "1.0.0",
          description: "API for accessing confirmed transcription data from Abairt"
        },
        servers: [
          {
            url: "#{request.protocol}#{request.host_with_port}",
            description: "Current server"
          }
        ],
        security: [
          {
            bearerAuth: []
          }
        ],
        paths: {
          "/api/transcriptions": {
            get: {
              summary: "List transcriptions",
              description: "Returns a paginated list of confirmed transcriptions",
              operationId: "listTranscriptions",
              tags: ["Transcriptions"],
              parameters: [
                {
                  name: "page",
                  in: "query",
                  description: "Page number",
                  required: false,
                  schema: {
                    type: "integer",
                    default: 1
                  }
                },
                {
                  name: "per_page",
                  in: "query",
                  description: "Items per page",
                  required: false,
                  schema: {
                    type: "integer",
                    default: 50,
                    maximum: 100
                  }
                },
                {
                  name: "updated_since",
                  in: "query",
                  description: "Filter transcriptions updated after this timestamp (ISO 8601)",
                  required: false,
                  schema: {
                    type: "string",
                    format: "date-time"
                  }
                },
                {
                  name: "q",
                  in: "query",
                  description: "Only transcriptions whose Irish contains these words, as a phrase (accents and case ignored), best match first",
                  required: false,
                  schema: { type: "string" }
                },
                {
                  name: "mayo",
                  in: "query",
                  description: "Only transcriptions spoken in a Mayo dialect",
                  required: false,
                  schema: { type: "boolean" }
                },
                {
                  name: "has_audio",
                  in: "query",
                  description: "Only transcriptions with a recording",
                  required: false,
                  schema: { type: "boolean" }
                }
              ],
              responses: {
                "200": {
                  description: "Successful response",
                  content: {
                    "application/json": {
                      schema: {
                        type: "object",
                        properties: {
                          entries: {
                            type: "array",
                            items: { "$ref": "#/components/schemas/Transcription" }
                          },
                          pagination: {
                            "$ref": "#/components/schemas/Pagination"
                          }
                        }
                      }
                    }
                  }
                },
                "401": {
                  "$ref": "#/components/responses/Unauthorized"
                },
                "429": {
                  "$ref": "#/components/responses/RateLimitExceeded"
                }
              }
            }
          },
          "/api/island_context": {
            post: {
              summary: "Find island context entries",
              description: "Given an English description of a Caotharnach island scenario, returns relevant confirmed Mayo dialect dictionary entries with audio. Uses hybrid search (FTS keyword matching + vector similarity) to find the best matches.",
              operationId: "createIslandContext",
              tags: ["Island Context"],
              requestBody: {
                required: true,
                content: {
                  "application/json": {
                    schema: {
                      type: "object",
                      properties: {
                        description: {
                          type: "string",
                          description: "English description of the island scenario (e.g. 'Ordering food and drinks in a pub, asking for recommendations')"
                        },
                        limit: {
                          type: "integer",
                          description: "Maximum number of entries to return",
                          default: 20,
                          minimum: 1,
                          maximum: 50
                        }
                      },
                      required: ["description"]
                    }
                  }
                }
              },
              responses: {
                "200": {
                  description: "Successful response",
                  content: {
                    "application/json": {
                      schema: {
                        type: "object",
                        properties: {
                          entries: {
                            type: "array",
                            items: { "$ref": "#/components/schemas/Transcription" }
                          },
                          meta: {
                            type: "object",
                            properties: {
                              count: {
                                type: "integer",
                                description: "Number of entries returned"
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                "401": {
                  "$ref": "#/components/responses/Unauthorized"
                },
                "422": {
                  description: "Description parameter is missing or blank",
                  content: {
                    "application/json": {
                      schema: {
                        type: "object",
                        properties: {
                          error: {
                            type: "string"
                          }
                        }
                      }
                    }
                  }
                },
                "429": {
                  "$ref": "#/components/responses/RateLimitExceeded"
                }
              }
            }
          },
          "/api/transcriptions/{id}": {
            get: {
              summary: "Get transcription",
              description: "Returns a single transcription by ID",
              operationId: "getTranscription",
              tags: ["Transcriptions"],
              parameters: [
                {
                  name: "id",
                  in: "path",
                  required: true,
                  description: "Transcription ID",
                  schema: {
                    type: "integer"
                  }
                }
              ],
              responses: {
                "200": {
                  description: "Successful response",
                  content: {
                    "application/json": {
                      schema: { "$ref": "#/components/schemas/Transcription" }
                    }
                  }
                },
                "401": {
                  "$ref": "#/components/responses/Unauthorized"
                },
                "404": {
                  "$ref": "#/components/responses/NotFound"
                },
                "429": {
                  "$ref": "#/components/responses/RateLimitExceeded"
                }
              }
            }
          },
          "/api/voice_recordings/{id}": {
            get: {
              summary: "Get a recording with its transcript",
              description: "Returns a whole recording to listen to, with its confirmed transcript line by line, each line timed in seconds from the start. For playing a recording to learners with the words following along.",
              operationId: "getVoiceRecording",
              tags: ["Recordings"],
              parameters: [
                { name: "id", in: "path", required: true, description: "Recording ID", schema: { type: "integer" } }
              ],
              responses: {
                "200": {
                  description: "Successful response",
                  content: { "application/json": { schema: { "$ref": "#/components/schemas/RecordingTranscript" } } }
                },
                "401": { "$ref": "#/components/responses/Unauthorized" },
                "404": { description: "No such recording, or it has no audio" },
                "429": { "$ref": "#/components/responses/RateLimitExceeded" }
              }
            }
          },
          "/api/questions": {
            post: {
              summary: "Ask a native speaker",
              description: "Sends a spoken question to a native speaker over Telegram, on behalf of someone using another app. The API user is the asker; asker_label says who actually asked. The question is sent straight away (no draft step) and waits in the queue if no speaker is connected. Only accounts allowed to ask questions can use it.",
              operationId: "createQuestion",
              tags: ["Questions"],
              requestBody: {
                required: true,
                content: {
                  "multipart/form-data": {
                    schema: {
                      type: "object",
                      required: ["audio"],
                      properties: {
                        audio: { type: "string", format: "binary", description: "The spoken question: any audio a browser records, up to 10 MB" },
                        asker_label: { type: "string", description: "Who is asking, e.g. a learner's name and app (up to 100 characters)" }
                      }
                    }
                  }
                }
              },
              responses: {
                "201": {
                  description: "Question sent",
                  content: { "application/json": { schema: { "$ref": "#/components/schemas/Question" } } }
                },
                "401": { "$ref": "#/components/responses/Unauthorized" },
                "403": { description: "This account can't ask questions" },
                "422": { description: "Missing or unsupported audio" },
                "429": { "$ref": "#/components/responses/RateLimitExceeded" }
              }
            }
          },
          "/api/questions/{id}": {
            get: {
              summary: "Get a question",
              description: "Returns one of the API user's questions, with the answer's audio once a speaker has replied",
              operationId: "getQuestion",
              tags: ["Questions"],
              parameters: [
                { name: "id", in: "path", required: true, description: "Question ID", schema: { type: "integer" } }
              ],
              responses: {
                "200": {
                  description: "Successful response",
                  content: { "application/json": { schema: { "$ref": "#/components/schemas/Question" } } }
                },
                "401": { "$ref": "#/components/responses/Unauthorized" },
                "404": { "$ref": "#/components/responses/NotFound" },
                "429": { "$ref": "#/components/responses/RateLimitExceeded" }
              }
            }
          }
        },
        components: {
          securitySchemes: {
            bearerAuth: {
              type: "http",
              scheme: "bearer",
              bearerFormat: "Token"
            }
          },
          schemas: {
            RecordingTranscript: {
              type: "object",
              properties: {
                id: { type: "integer" },
                title: { type: "string" },
                duration_seconds: { type: "number", format: "float" },
                dialect_region: { type: "string", nullable: true },
                audio_url: { type: "string", format: "uri", description: "The recording's audio (the extracted track for a video)" },
                lines: {
                  type: "array",
                  description: "Confirmed lines of the transcript, in the order they are heard",
                  items: {
                    type: "object",
                    properties: {
                      id: { type: "integer", description: "Transcription ID" },
                      irish: { type: "string" },
                      translation: { type: "string", nullable: true },
                      start: { type: "number", format: "float", description: "Start time in seconds" },
                      end: { type: "number", format: "float", description: "End time in seconds" },
                      speaker: { "$ref": "#/components/schemas/Speaker" }
                    }
                  }
                }
              }
            },
            Question: {
              type: "object",
              properties: {
                id: { type: "integer" },
                status: { type: "string", enum: ["draft", "waiting", "sent", "answered"], description: "waiting: queued for a speaker; sent: with a speaker; answered: the reply is in answer_audio_url" },
                asker_label: { type: "string", nullable: true },
                created_at: { type: "string", format: "date-time" },
                sent_at: { type: "string", format: "date-time", nullable: true },
                answered_at: { type: "string", format: "date-time", nullable: true },
                audio_url: { type: "string", format: "uri", description: "The question as asked" },
                answer_audio_url: { type: "string", format: "uri", nullable: true, description: "The speaker's spoken answer (Ogg Opus), once answered" }
              }
            },
            Transcription: {
              type: "object",
              properties: {
                id: {
                  type: "integer",
                  description: "Transcription ID"
                },
                word_or_phrase: {
                  type: "string",
                  description: "The Irish word or phrase"
                },
                translation: {
                  type: "string",
                  description: "English translation"
                },
                region_id: {
                  type: "integer",
                  description: "Region ID within the voice recording"
                },
                region_start: {
                  type: "number",
                  format: "float",
                  description: "Start time in seconds"
                },
                region_end: {
                  type: "number",
                  format: "float",
                  description: "End time in seconds"
                },
                updated_at: {
                  type: "string",
                  format: "date-time",
                  description: "Last update timestamp"
                },
                audio_url: {
                  type: "string",
                  format: "uri",
                  description: "URL to the audio snippet for this transcription (always present for entries returned by the API)"
                },
                speaker: {
                  "$ref": "#/components/schemas/Speaker"
                },
                voice_recording: {
                  "$ref": "#/components/schemas/VoiceRecording"
                }
              },
              required: %w[id word_or_phrase translation region_id region_start region_end updated_at audio_url speaker voice_recording]
            },
            Speaker: {
              type: "object",
              properties: {
                id: {
                  type: "integer"
                },
                name: {
                  type: "string"
                },
                dialect: {
                  type: "string"
                }
              }
            },
            VoiceRecording: {
              type: "object",
              properties: {
                id: {
                  type: "integer"
                },
                title: {
                  type: "string"
                },
                external_id: {
                  type: "string",
                  description: "Fotheidil video ID"
                }
              }
            },
            Pagination: {
              type: "object",
              properties: {
                page: {
                  type: "integer"
                },
                per_page: {
                  type: "integer"
                },
                total: {
                  type: "integer"
                }
              }
            }
          },
          responses: {
            Unauthorized: {
              description: "Authentication required",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: {
                      error: {
                        type: "string"
                      }
                    }
                  }
                }
              }
            },
            NotFound: {
              description: "Resource not found",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: {
                      error: {
                        type: "string"
                      }
                    }
                  }
                }
              }
            },
            RateLimitExceeded: {
              description: "Rate limit exceeded (100 requests per hour)",
              content: {
                "application/json": {
                  schema: {
                    type: "object",
                    properties: {
                      error: {
                        type: "string"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    end
  end
end

