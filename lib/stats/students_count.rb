module StudentsCount

  # Counts students scoped according to given options and pushes result to Overmind if :store_in_overmind is given.
  #
  # @example
  #     # Count students of dwayne.macgowan on Cerviño at the end of Octobre 2012
  #     Contact.count_students(account_name: 'cervino',
  #                            teacher_name: 'dwayne.macgowan',
  #                            year: 2012,
  #                            month: 10)
  #
  # @param options [Hash]
  # @option options store_in_overmind [Boolean] POST result to Overmind-ws
  # @option options account_name [String] account's global identifier.
  # @option options account [Account]
  # @option options account_id [String] accounts local id in contacts-ws
  # @option options teacher_name [String] teacher's username
  # @option options year [Integer]
  # @option options month [Integer]
  #
  # @raises ArgumentError. @see raise_if_invalid
  # @raises ArgumentError. @see raise_if_invalid_for_storing
  #
  # @return [Integer]
  def count_students(options={})
    val = calculate(options)
    store_in_overmind(val, options) if options[:store_in_overmind] && val
    val
  end

  private

  # Makes the stat calculation
  #
  # @param options [Hash]
  # @option options account_name [String] account's global identifier.
  # @option options account [Account]
  # @option options account_id [String] accounts local id in contacts-ws
  # @option options teacher_name [String]
  # @option options year [Integer]
  # @option options month [Integer]
  #
  # @return [Integer]
  def calculate(options={})
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

  # POSTs value to Overmind-ws
  # @return [TrueClass,FalseClass,NilClass] for success, failure or connection-error
  def store_in_overmind(value,options={})
    raise_if_invalid_for_storing(options)
    stat = Overmind::MonthlyStat.new(
      value: value,
      name: 'students',
      ref_date: Date.civil(options[:year].to_i,
                           options[:month].to_i,
                           1).end_of_month,
      account_name: get_account_name(options),
      service: 'contacts'
    )
    unless stat.create
      Rails.logger.warn stat.errors.full_messages
    end
  end

  # Validates options and raises exception if invalid.
  # Validates:
  # - only one of :account, :account_name or :account_id has been specified
  # - if :month present, :year should be present too.
  # @raises ArgumentError
  def raise_if_invalid(op)

    if ((op[:account].nil?? 0 : 1) + (op[:account_name].nil?? 0 : 1) + (op[:account_id].nil?? 0 : 1)) > 1
      raise ArgumentError, 'you have to specify account in only one way'
    end

    if (op[:month] && !op[:year])
      raise ArgumentError, 'cant specify month without year'
    end
  end

  # Ensures options are valid for storing in overmind
  # Validates:
  # - presence of :month and :year
  # - account specified
  # - :teacher_name not specified
  # if any fail ArgumentError is raised
  # @raises ArgumentError
  def raise_if_invalid_for_storing(op)
    unless (op[:month] && op[:year])
      raise ArgumentError, 'storing in Overmind only available for MonthlyStats'
    end

    unless op[:account] || op[:account_name] || op[:account_id]
      raise ArgumentError, 'storing in Overmind needs to be scoped to an account'
    end

    if op[:teacher_name]
      raise ArgumentError, 'storing in Overmind not available for teacher stats yet'
    end
  end

  # Gets local account_id from options
  # This is the id of the local Account object.
  # @return [Integer]
  def get_account_id(op)
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

  # Gets account_name from options
  # @return [String]
  def get_account_name(op)
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