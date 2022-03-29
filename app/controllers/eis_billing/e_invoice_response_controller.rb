class EisBilling::EInvoiceResponseController < EisBilling::BaseController
  def update
    invoice_number = params[:invoice_number]

    set_e_invoice_sent_at(invoice_number)
    render status: :ok, json: { messege: 'Response received' }
  end

  private

  def set_e_invoice_sent_at(invoice_number)
    invoice = Invoice.find_by(number: invoice_number)
    invoice.update(e_invoice_sent_at: Time.zone.now)
  end
end
