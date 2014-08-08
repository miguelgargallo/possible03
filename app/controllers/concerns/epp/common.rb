module Epp::Common
  extend ActiveSupport::Concern

  OBJECT_TYPES = {
    'urn:ietf:params:xml:ns:contact-1.0' => 'contact',
    'urn:ietf:params:xml:ns:domain-1.0' => 'domain'
  }

  included do
    protect_from_forgery with: :null_session
    before_action :validate_request, only: [:proxy]
  end

  def proxy
    @svTRID = "ccReg-#{'%010d' % rand(10 ** 10)}"
    send(params[:command])
  end

  def params_hash
    @params_hash ||= Hash.from_xml(params[:frame]).with_indifferent_access
  end

  def epp_session
    EppSession.find_or_initialize_by(session_id: cookies['session'])
  end

  def epp_errors
    @errors ||= []
  end

  def current_epp_user
    @current_epp_user ||= EppUser.find(epp_session[:epp_user_id]) if epp_session[:epp_user_id]
  end

  def handle_errors(obj)
    obj.construct_epp_errors
    @errors = obj.errors[:epp_errors]
    render '/epp/error'
  end

  def xml_attrs_present?(ph, attributes)
    attributes.each do |x|
      epp_errors << {code: '2003', msg: I18n.t('errors.messages.required_parameter_missing', key: x.last)} unless has_attribute(ph, x)
    end
    epp_errors.empty?
  end

  def has_attribute(ph, path)
    path.inject(ph) do |location, key|
      location.respond_to?(:keys) ? location[key] : nil
    end
  end

  def validate_request
    type = OBJECT_TYPES[params_hash['epp']['xmlns:ns2']]
    return unless type

    xsd = Nokogiri::XML::Schema(File.read("doc/schemas/#{type}-1.0.xsd"))
    doc = Nokogiri::XML(params[:frame])
    ext_values = xsd.validate(doc)
    if ext_values.any?
      epp_errors << {code: '2001', msg: 'Command syntax error', ext_values: ext_values}
      render '/epp/error' and return
    end
  end
end
