module EisBilling
  class GetReferenceNumber < EisBilling::Base
    def self.send_request
      send_it
    end

    def self.obj_data
      {
        initiator: INITIATOR,
      }
    end

    def self.send_it
      http = EisBilling::Base.base_request(url: reference_number_generator_url)
      http.post(reference_number_generator_url, obj_data.to_json, EisBilling::Base.headers)
    end

    def self.reference_number_generator_url
      "#{EisBilling::Base::BASE_URL}/api/v1/invoice_generator/reference_number_generator"
    end
  end
end
