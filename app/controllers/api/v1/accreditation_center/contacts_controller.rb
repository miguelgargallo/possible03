require 'serializers/repp/domain'

module Api
  module V1
    module AccreditationCenter
      class ContactsController < ::Api::V1::AccreditationCenter::BaseController
        def show
          @contact = Contact.find_by(code: params[:id])

          if @contact
            render json: { contact: Serializers::Repp::Contact.new(@contact,
                                                                     show_address: false).to_json  }, status: :found
          else
            render json: { errors: 'Contact not found' }, status: :not_found
          end
        end
      end
    end
  end
end
