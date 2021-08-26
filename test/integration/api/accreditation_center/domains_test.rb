require 'test_helper'

class DomainsTest < ApplicationIntegrationTest
  def setup
    super

		@domain = domains(:shop)
  end

	def test_get_domain_info
		get "/api/v1/accreditation_center/domains/?name=#{@domain.name}"
		json = JSON.parse(response.body, symbolize_names: true)

		assert_equal json[:domain][:name], @domain.name
	end

	def test_return_code_error_if_valid_domain_name
		get "/api/v1/accreditation_center/domains/?name=some.ee"
		json = JSON.parse(response.body, symbolize_names: true)

		assert_equal json[:errors], "Domain not found"
	end
end