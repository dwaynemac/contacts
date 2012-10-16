class StudentsCount

  # TODO tern into a Mixin module for Contact

  # @param options [Hash]
  # @option options account_name [String] account's global identifier.
  # @option options account [Account]
  # @option options account_id [String] accounts local id in contacts-ws
  # @option options teacher_name [String]
  # @option options year [Integer]
  # @option options month [Integer]
  def self.calculate(options={})
    raise_if_invalid(options)

    teacher_name = options[:teacher_name]

    if options[:year]
      ids = []
      ref_date = Date.civil(options[:year],options[:month]||12,1).to_time.end_of_month

      account_name = get_account_name(options)
      if account_name

        ids = HistoryEntry.element_ids_with(
            "local_status_for_#{account_name}" => 'student',
            at: ref_date,
            class: 'Contact'
        )

        if teacher_name
          intersection_ids = HistoryEntry.element_ids_with(
              "local_teacher_for_#{account_name}" => teacher_name,
              at: ref_date,
              class: 'Contact'
          )
          # TODO make a HistoryEntry method that receives multiple attribute to avoid this memory expensive intersection
          ids = ids & intersection_ids
        end

      else
        ids = HistoryEntry.element_ids_with(
            attribute_name: 'status',
            at: ref_date,
            class: 'Contact',
        )
      end

      ids.count
    else
      criteria = Contact
      account_id = get_account_id(options)
      if account_id
        criteria = criteria.where(local_unique_attributes: {'$elemMatch' => { '_type' => 'LocalStatus',
                                                                              'value' => 'student',
                                                                              'account_id' => account_id}})
      else
        criteria = criteria.where(status: :student)
      end

      if teacher_name
        local_teacher_matcher = { '_type' => 'LocalTeacher',
                                  'value' => teacher_name}
        if account_id
          local_teacher_matcher.merge!({'account_id' => account_id})
        end
        criteria = criteria.where(local_unique_attributes: { '$elemMatch' => local_teacher_matcher})
      end

      criteria.count
    end
  end

  private

  def self.raise_if_invalid(op)

    if ((op[:account].nil?? 0 : 1) + (op[:account_name].nil?? 0 : 1) + (op[:account_id].nil?? 0 : 1)) > 1
      raise 'you have to specify account in only one way'
    end

    if (op[:month] && !op[:year])
      raise 'cant specify month without year'
    end
  end

  def self.get_account_id(op)
    if op[:account_id]
      op[:account_id]
    elsif op[:account]
      @account = op[:account]
      @account.id
    elsif op[:account_name]
      a = Account.where(name: op[:account_name]).first
      a.try(:id)
    end
  end

  def self.get_account_name(op)
    if op[:account_name]
      op[:account_name]
    elsif op[:account]
      op[:account].name
    elsif op[:account_id]
      a = Account.find(op[:account_id])
      a.try :name
    end
  end
end