class SandboxEmailInterceptor
  def self.delivering_email(message)
    message.to = ['seosamh@seocahill.com']
  end
end

if ENV['SANDBOX'] == "true"
  ActionMailer::Base.register_interceptor(SandboxEmailInterceptor)
end
