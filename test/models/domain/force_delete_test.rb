module Concerns::Domain::ForceDelete
  extend ActiveSupport::Concern

  DAYS_TO_START_HOLD = 15.days

  def force_delete_scheduled?
    statuses.include?(DomainStatus::FORCE_DELETE)
  end

  def schedule_force_delete(type: :fast_track)
    if discarded?
      raise StandardError 'Force delete procedure cannot be scheduled while a domain is discarded'
    end

    case type
    when :fast_track
      force_delete_fast_track
    when :soft
      force_delete_soft
    else
      raise StandardError, 'Wrong type for force delete'
    end
  end

  def force_delete_fast_track
    preserve_current_statuses_for_force_delete
    add_force_delete_statuses
    self.force_delete_date = Time.zone.today + Setting.redemption_grace_period.days
    self.force_delete_start = Time.zone.today
    stop_all_pending_actions
    allow_deletion
    save(validate: false)
  end

  def force_delete_soft
    preserve_current_statuses_for_force_delete
    add_force_delete_statuses
    calculate_soft_delete_date
    stop_all_pending_actions
    check_hold
    allow_deletion
    save(validate: false)
  end

  def cancel_force_delete
    restore_statuses_before_force_delete
    remove_force_delete_statuses
    self.force_delete_date = nil
    self.force_delete_start = nil
    save(validate: false)
  end

  private

  def check_hold
    if force_delete_start.present? &&
      force_delete_start < valid_to &&
      (force_delete_date + DAYS_TO_START_HOLD) > Time.zone.today
      statuses << DomainStatus::CLIENT_HOLD
    end
  end

  def calculate_soft_delete_date
    years = (self.valid_to.to_date - Time.zone.today).to_i / 365
    if years.positive?
      self.force_delete_start = self.valid_to - years.years
      self.force_delete_date = self.force_delete_start + Setting.redemption_grace_period.days
    end
  end

  def stop_all_pending_actions
    statuses.delete(DomainStatus::PENDING_UPDATE)
    statuses.delete(DomainStatus::PENDING_TRANSFER)
    statuses.delete(DomainStatus::PENDING_RENEW)
    statuses.delete(DomainStatus::PENDING_CREATE)
  end

  def preserve_current_statuses_for_force_delete
    self.statuses_before_force_delete = statuses.clone
  end

  def restore_statuses_before_force_delete
    self.statuses = statuses_before_force_delete
    self.statuses_before_force_delete = nil
  end

  def add_force_delete_statuses
    statuses << DomainStatus::FORCE_DELETE
    statuses << DomainStatus::SERVER_RENEW_PROHIBITED
    statuses << DomainStatus::SERVER_TRANSFER_PROHIBITED
  end

  def remove_force_delete_statuses
    statuses.delete(DomainStatus::FORCE_DELETE)
    statuses.delete(DomainStatus::SERVER_RENEW_PROHIBITED)
    statuses.delete(DomainStatus::SERVER_TRANSFER_PROHIBITED)
    statuses.delete(DomainStatus::SERVER_UPDATE_PROHIBITED)
    statuses.delete(DomainStatus::PENDING_DELETE)
    statuses.delete(DomainStatus::SERVER_MANUAL_INZONE)
    statuses.delete(DomainStatus::CLIENT_HOLD)
  end

  def allow_deletion
    statuses.delete(DomainStatus::CLIENT_DELETE_PROHIBITED)
    statuses.delete(DomainStatus::SERVER_DELETE_PROHIBITED)
  end
end
