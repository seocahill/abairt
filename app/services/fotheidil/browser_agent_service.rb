# frozen_string_literal: true

module Fotheidil
  # LLM-powered browser agent for more resilient web automation
  # Uses OpenAI to understand page context and find elements via natural language instructions
  class BrowserAgentService
    def initialize(driver)
      @driver = driver
      @client = OpenAI::Client.new(
        access_token: Rails.application.credentials.dig(:openai, :openai_key),
        organization_id: Rails.application.credentials.dig(:openai, :openai_org)
      )
    end

    # Execute a natural language instruction on the current page
    # @param instruction [String] What to do (e.g., "find and return the CSS selector for the upload button")
    # @return [String, nil] The CSS selector or XPath that matches the instruction
    def find_element_selector(instruction)
      page_context = extract_page_context

      response = @client.chat(parameters: {
        model: "gpt-4o",
        messages: [
          {role: "system", content: system_prompt},
          {role: "user", content: user_prompt(instruction, page_context)}
        ],
        temperature: 0.1
      })

      parse_selector_response(response)
    rescue => e
      Rails.logger.error "Browser agent error: #{e.message}"
      nil
    end

    # Find and click an element based on natural language instruction
    # @param instruction [String] What element to click (e.g., "the upload button")
    # @return [Boolean] Success status
    def click_element(instruction)
      selector = find_element_selector("find the CSS selector for #{instruction}")
      return false unless selector

      element = @driver.find_element(:css, selector)
      element.click if element&.displayed?
      true
    rescue => e
      Rails.logger.error "Click element error: #{e.message}"
      false
    end

    private

    def extract_page_context
      # Get simplified page HTML focusing on interactive elements
      buttons = @driver.find_elements(:tag_name, "button").map do |btn|
        {
          tag: "button",
          text: btn.text.strip,
          id: btn.attribute("id"),
          class: btn.attribute("class"),
          type: btn.attribute("type"),
          displayed: btn.displayed?
        }
      rescue
        nil
      end.compact

      inputs = @driver.find_elements(:tag_name, "input").map do |input|
        {
          tag: "input",
          type: input.attribute("type"),
          id: input.attribute("id"),
          class: input.attribute("class"),
          name: input.attribute("name"),
          placeholder: input.attribute("placeholder"),
          displayed: input.displayed?
        }
      rescue
        nil
      end.compact

      links = @driver.find_elements(:tag_name, "a").map do |link|
        {
          tag: "a",
          text: link.text.strip,
          href: link.attribute("href"),
          class: link.attribute("class"),
          displayed: link.displayed?
        }
      rescue
        nil
      end.compact

      {
        url: @driver.current_url,
        title: @driver.title,
        buttons: buttons,
        inputs: inputs,
        links: links
      }.to_json
    end

    def system_prompt
      <<~PROMPT
        You are a web automation assistant. Your job is to analyze HTML page context and provide CSS selectors or XPath expressions to locate elements.

        Rules:
        1. Return ONLY the selector string, nothing else
        2. Prefer CSS selectors over XPath when possible
        3. Choose the most specific and stable selector (prefer IDs, then data attributes, then semantic attributes)
        4. Avoid brittle selectors like nth-child or text matching when better options exist
        5. If multiple elements match, return the selector for the most likely intended element based on context
        6. Only consider elements where "displayed" is true
        7. If no good match exists, return "NOT_FOUND"

        Examples:
        - For a button with text "Upload": button:contains("Upload") or the specific ID/class if available
        - For a file input: input[type="file"]
        - For a specific link: a[href="/videos"]
      PROMPT
    end

    def user_prompt(instruction, page_context)
      <<~PROMPT
        Instruction: #{instruction}

        Page Context:
        #{page_context}

        Provide the CSS selector or XPath:
      PROMPT
    end

    def parse_selector_response(response)
      content = response.dig("choices", 0, "message", "content")&.strip
      return nil if content.nil? || content == "NOT_FOUND"

      # Remove any markdown code blocks or extra explanation
      content.gsub(/```[a-z]*\n?/, "").strip
    end
  end
end
