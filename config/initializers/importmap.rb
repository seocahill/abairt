# Ensure importmap config is initialized
Rails.application.config.importmap ||= ActiveSupport::OrderedOptions.new
Rails.application.config.importmap.paths ||= []
Rails.application.config.importmap.paths << Rails.root.join("config/importmap.rb")
Rails.application.config.importmap.cache_sweepers ||= []
Rails.application.config.importmap.cache_sweepers << Rails.root.join("app/javascript")
