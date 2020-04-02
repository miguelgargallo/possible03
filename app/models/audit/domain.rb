module Audit
  class Domain < Base
    self.table_name = 'audit.domains'

    CHILDREN_VERSIONS_HASH = {
      dnskeys: Audit::Dnskey,
      registrant: Audit::Contact,
      nameservers: Nameserver,
      tech_contacts: Audit::Contact,
      admin_contacts: Audit::Contact
    }.with_indifferent_access.freeze

    ransacker :name do |parent|
      Arel::Nodes::InfixOperation.new('->>', parent.table[:new_value],
                                      Arel::Nodes.build_quoted('name'))
    end

    ransacker :registrant_id do |parent|
      Arel::Nodes::InfixOperation.new('->>', parent.table[:new_value],
                                      Arel::Nodes.build_quoted('registrant_id'))
    end

    ransacker :registrar_id do |parent|
      Arel::Nodes::InfixOperation.new('->>', parent.table[:new_value],
                                      Arel::Nodes.build_quoted('registrar_id'))
    end

    scope 'not_creates', -> { where.not(action: 'CREATE') }

    def uuid
      new_value['uuid']
    end

    def prepare_children_history
      children.each_with_object({}) do |(key, value), hash|
        klass = CHILDREN_VERSIONS_HASH[key]
        next unless klass

        value = prepare_value(key: key, value: value)
        parent_klass = klass.name.split('::').last.constantize
        result = klass.where(object_id: value)
                      .where(recorded_at: date_range)

        result = parent_klass.where(id: value) if result.all?(&:blank?)
        hash[key] = result unless result.all?(&:blank?)
      end
    end

    def date_range
      next_version_recorded_at = self.next_version&.recorded_at || Time.zone.now
      (recorded_at..next_version_recorded_at)
    end

    def prepare_value(key:, value:)
      return value unless value.all?(&:blank?)
      case key
      when 'dnskeys'
        self.object.dnskey_ids
      when 'registrant'
        [self.object.registrant_id]
      when 'nameservers'
        self.object.nameserver_ids
      when 'tech_contacts'
        self.object.tech_contact_ids
      when 'admin_contacts'
        self.object.admin_contact_ids
      else # 'legal_documents'
        [self.object.legal_document_id]
      end
    end
  end
end
