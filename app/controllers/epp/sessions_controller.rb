module Epp
  class SessionsController < BaseController
    skip_authorization_check only: [:hello, :login, :logout]
    before_action :set_paper_trail_whodunnit

    def hello
      render_epp_response('greeting')
    end

    def login
      success = true
      @api_user = ApiUser.find_by(login_params)

      webclient_request = ENV['webclient_ips'].split(',').map(&:strip).include?(request.ip)
      if webclient_request && !Rails.env.test? && !Rails.env.development?
        client_md5 = Certificate.parse_md_from_string(request.env['HTTP_SSL_CLIENT_CERT'])
        raise 'webclient cert (cert_path) missing, registrar (r)epp disabled' if ENV['cert_path'].blank?

        server_md5 = Certificate.parse_md_from_string(File.read(ENV['cert_path']))
        if client_md5 != server_md5
          msg = 'Authentication error; server closing connection (certificate is not valid)'
          epp_errors.add(:epp_errors,
                         msg: msg, code: '2501')

          success = false
        end
      end

      if !Rails.env.development? && (!webclient_request && @api_user) &&
         !@api_user.pki_ok?(request.env['HTTP_SSL_CLIENT_CERT'], request.env['HTTP_SSL_CLIENT_S_DN_CN'])
        msg = 'Authentication error; server closing connection (certificate is not valid)'
        epp_errors.add(:epp_errors,
                       msg: msg, code: '2501')

        success = false
      end

      if success && !@api_user
        msg = 'Authentication error; server closing connection (API user not found)'
        epp_errors.add(:epp_errors,
                       msg: msg, code: '2501')

        success = false
      end

      if success && !@api_user.try(:active)
        msg = 'Authentication error; server closing connection (API user is not active)'
        epp_errors.add(:epp_errors,
                       msg: msg, code: '2501')

        success = false
      end

      if success && @api_user.cannot?(:create, :epp_login)
        msg = 'Authentication error; server closing connection (API user does not have epp role)'
        epp_errors.add(:epp_errors,
                       msg: msg, code: '2501')

        success = false
      end

      if success && !ip_white?
        msg = 'Authentication error; server closing connection (IP is not whitelisted)'
        epp_errors.add(:epp_errors,
                       msg: msg, code: '2501')

        success = false
      end

      if success && EppSession.limit_reached?(@api_user.registrar)
        msg = 'Session limit exceeded; server closing connection (connection limit reached)'
        epp_errors.add(:epp_errors,
                       msg: msg, code: '2502')

        success = false
      end

      if success
        new_password = params[:parsed_frame].at_css('newPW')&.text
        password_change = new_password.present?

        if password_change
          @api_user.plain_text_password = new_password
          @api_user.save!
        end

        already_authenticated = EppSession.exists?(session_id: epp_session_id)

        if already_authenticated
          epp_errors.add(:epp_errors,
                         msg: 'Command use error; Already authenticated', code: 2002)
          handle_errors
          return
        end

        epp_session = EppSession.new
        epp_session.session_id = epp_session_id
        epp_session.user = @api_user
        epp_session.save!
        render_epp_response('login_success')
      else
        handle_errors
      end
    end

    def ip_white?
      webclient_request = ENV['webclient_ips'].split(',').map(&:strip).include?(request.ip)
      return true if webclient_request
      return false if @api_user && !@api_user.registrar.api_ip_white?(request.ip)

      true
    end

    def logout
      unless signed_in?
        epp_errors.add(:epp_errors,
                       code: 2201, msg: 'Authorization error')
        handle_errors
        return
      end

      @api_user = current_user # cache current_user for logging
      epp_session.destroy
      render_epp_response('logout')
    end

    ### HELPER METHODS ###

    def login_params
      user = params[:parsed_frame].css('clID').first.text
      pw = params[:parsed_frame].css('pw').first.text
      { username: user, plain_text_password: pw }
    end

    private

    def resource
      @api_user
    end
  end
end
