require "active_storage/service/s3_service"
require 'uri'

class ActiveStorage::Service::CloudflareService < ActiveStorage::Service::S3Service
  private

    def public_url(key, **)
      url = object_for(key).public_url
      "https://assets.abairt.com#{URI(url).path}"
    end
end