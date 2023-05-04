class PagesController < ApplicationController
  Faq = Struct.new(:title, :body)
  def faq
    @faqs = [
      Faq.new("test", "lorem"),
      Faq.new("test2", "lorem2")
    ]
  end
end
