require 'test_helper'

class EppContactInfoBaseTest < EppTestCase
  setup do
    @contact = contacts(:john)
  end

  def test_returns_valid_response
    assert_equal 'john-001', @contact.code
    assert_equal [Contact::OK, Contact::LINKED], @contact.statuses
    assert_equal 'john@inbox.test', @contact.email
    assert_equal '+555.555', @contact.phone
    assert_equal 'bestnames', @contact.registrar.code
    assert_equal Time.zone.parse('2010-07-05'), @contact.created_at

    # https://github.com/internetee/registry/issues/415
    @contact.update_columns(code: @contact.code.upcase)

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <info>
            <contact:info xmlns:contact="#{Xsd::Schema.filename(for_prefix: 'contact-ee', for_version: '1.1')}">
              <contact:id>john-001</contact:id>
            </contact:info>
          </info>
        </command>
      </epp>
    XML

    post epp_info_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }

    response_xml = Nokogiri::XML(response.body)
    assert_correct_against_schema response_xml
    assert_epp_response :completed_successfully
    assert_equal 'JOHN-001', response_xml.at_xpath('//contact:id', contact: xml_schema).text
    assert_equal 'ok', response_xml.at_xpath('//contact:status', contact: xml_schema)['s']
    assert_equal 'john@inbox.test', response_xml.at_xpath('//contact:email', contact: xml_schema)
                                      .text
    assert_equal '+555.555', response_xml.at_xpath('//contact:voice', contact: xml_schema).text
    assert_equal 'bestnames', response_xml.at_xpath('//contact:clID', contact: xml_schema).text
    assert_equal '2010-07-05T00:00:00+03:00', response_xml.at_xpath('//contact:crDate',
                                                                    contact: xml_schema).text
  end

  def test_get_info_about_contact_with_prefix
    @contact.update_columns(code: 'TEST:JOHN-001')
    assert @contact.code, 'TEST:JOHN-001'

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <info>
            <contact:info xmlns:contact="#{Xsd::Schema.filename(for_prefix: 'contact-ee', for_version: '1.1')}">
              <contact:id>TEST:JOHN-001</contact:id>
            </contact:info>
          </info>
        </command>
      </epp>
    XML

    post epp_info_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }

    response_xml = Nokogiri::XML(response.body)
    assert_correct_against_schema response_xml
    assert_epp_response :completed_successfully
    assert_equal 'TEST:JOHN-001', response_xml.at_xpath('//contact:id', contact: xml_schema).text
    assert_equal '+555.555', response_xml.at_xpath('//contact:voice', contact: xml_schema).text
  end

  def test_get_info_about_contact_without_prefix
    @contact.update_columns(code: "#{@contact.registrar.code}:JOHN-001".upcase)
    assert @contact.code, "#{@contact.registrar.code}:JOHN-001".upcase

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <info>
            <contact:info xmlns:contact="#{Xsd::Schema.filename(for_prefix: 'contact-ee', for_version: '1.1')}">
              <contact:id>JOHN-001</contact:id>
            </contact:info>
          </info>
        </command>
      </epp>
    XML

    post epp_info_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }

    response_xml = Nokogiri::XML(response.body)
    assert_correct_against_schema response_xml
    assert_epp_response :completed_successfully
    assert_equal "#{@contact.registrar.code}:JOHN-001".upcase, response_xml.at_xpath('//contact:id', contact: xml_schema).text
    assert_equal '+555.555', response_xml.at_xpath('//contact:voice', contact: xml_schema).text
  end

  def test_hides_password_and_name_when_current_registrar_is_not_sponsoring
    non_sponsoring_registrar = registrars(:goodnames)
    @contact.update!(registrar: non_sponsoring_registrar)

    # https://github.com/internetee/registry/issues/415
    @contact.update_columns(code: @contact.code.upcase)

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <info>
            <contact:info xmlns:contact="#{Xsd::Schema.filename(for_prefix: 'contact-ee', for_version: '1.1')}">
              <contact:id>#{@contact.code}</contact:id>
            </contact:info>
          </info>
        </command>
      </epp>
    XML

    post epp_info_path, params: { frame: request_xml }, headers: { 'HTTP_COOKIE' =>
                                                                       'session=api_bestnames' }

    assert_epp_response :completed_successfully
    response_xml = Nokogiri::XML(response.body)
    assert_correct_against_schema response_xml
    assert_nil response_xml.at_xpath('//contact:authInfo', contact: xml_schema)
    assert_equal 'No access', response_xml.at_xpath('//contact:name', contact: xml_schema).text
  end

  private

  def xml_schema
    Xsd::Schema.filename(for_prefix: 'contact-ee', for_version: '1.1')
  end
end
