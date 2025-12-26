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

