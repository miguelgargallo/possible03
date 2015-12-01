class Registrant::DomainsController < RegistrantController

  def index

  authorize! :view, :registrant_domains
  params[:q] ||= {}

  domains = Domain.includes(:registrar, :registrant).where(registrant_id: 76246)

  normalize_search_parameters do
    @q = domains.search(params[:q])
    @domains = @q.result.page(params[:page])
  end
  @domains = @domains.per(params[:results_per_page]) if params[:results_per_page].to_i > 0
  end

  def show
    @domain = Domain.find(params[:id])
    @domain.valid?
  end

  def set_domain
    @domain = Domain.find(params[:id])
  end

  def normalize_search_parameters

    ca_cache = params[:q][:valid_to_lteq]
    begin
      end_time = params[:q][:valid_to_lteq].try(:to_date)
      params[:q][:valid_to_lteq] = end_time.try(:end_of_day)
    rescue
      logger.warn('Invalid date')
    end

    yield

    params[:q][:valid_to_lteq] = ca_cache
  end

end