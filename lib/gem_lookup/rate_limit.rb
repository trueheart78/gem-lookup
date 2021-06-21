# frozen_string_literal: true

module GemLookup
  module RateLimit
    # @return [Numeric] the max requests that can be made per second.
    MAX_REQUESTS_PER_SECOND = 10

    # @return [String] the url that documents the rate limit
    RATE_LIMIT_DOCUMENTATION_URL = 'https://guides.rubygems.org/rubygems-org-rate-limits/'
  end
end
