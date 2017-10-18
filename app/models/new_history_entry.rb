# Stores history in changes to attributes
#
# NOTE: LocalStatus#status changes are stored on a special way:
#   They are considered in the history as local_status_for_AccountName of object Contact
class NewHistoryEntry < ActiveRecord::Base
  self.table_name = "history_entries"

  belongs_to :historiable, polymorphic: true

  # Returns value at a given date
  #
  # @param [String] ref_attribute
  # @param [Date] ref_date
  # @param [Hash] options
  # @option [String] class - historiable_type
  # @option [String] id    - historiable_id
  #
  # @return [depends on attr type?] value
  def self.value_at(ref_attribute, ref_date, options = {})

    scope = self.where(attr: ref_attribute).where("changed_at >= ?", ref_date.to_time).order(changed_at: :asc)
    scope = scope.where(historiable_type: options[:class]) if options[:class]
    scope = scope.where(historiable_id: options[:id]) if options[:id]

    scope.first.try :old_value
  end

  # Returns last value for a given attr
  #
  # @param [String] ref_attribute
  # @param [Hash] options
  # @option [String] class - historiable_type
  # @option [String] id    - historiable_id
  #
  # @return [depends on attr type?] value
  def self.last_value(ref_attribute, options = {})

    scope = self
    scope = scope.where(historiable_type: options[:class]) if options[:class]
    scope = scope.where(historiable_id: options[:id]) if options[:id]

    # find last change
    scope.first(
        conditions: {
            attr: ref_attribute,
        },
        order: [:changed_at => :desc]
    ).try :old_value
  end


  # Returns all element ids for elements with given value in given attr at a given date
  #
  # @param [Hash] options
  #
  # @option options [Hash] :attribute_name - required - first key-value will be used as attr(key) and value(value)
  # @option options [Time] :at - required - ref_date
  # @option options [String] class        - historiable_type
  # @option options [String] id           - historiable_id
  # @option options [Account] account
  # @option options [String] account_name
  #
  # @raise ArgumentError if attribute_name and :at options not given
  #
  # @example
  #     HistoryEntry.element_ids_with status: 'student', at: 1.month.ago, class: 'Contact', account_name: 'belgrano'
  #
  # @return [Array<String>] element_ids
  def self.element_ids_with(options = {})

    raise ArgumentError if options.keys.size < 2
    raise ArgumentError unless options[:at]
  
    # use first key of options as attr
    ref_attribute = options.keys.first
    ref_value = options[options.keys.first]
    ref_date      = options[:at].to_time.end_of_day
    if options[:account_name] && !options[:account]
      options[:account] = NewAccount.where(name: options.delete(:account_name)).first
    end

    ret = Rails.cache.read(cache_key_for_element_ids_with(options))
    if ret.nil?

      elements_with_history = NewHistoryEntry.where(attr: ref_attribute).where("changed_at >= ?",ref_date).order("changed_at asc")
      
      elements_with_history = elements_with_history.where({historiable_type: options[:class]}) if options[:class]

      if options[:account].present? && options[:class].present?
        ActiveSupport::Notifications.instrument('get_object_ids.attribute_at_given_time.refine_scope.contacts_search') do
          # if Account and Object class where given we can find Objects linked to Account
          accessor = options[:class].underscore.pluralize

          if accessor == "new_contacts"
            accessor = "contacts"
          end

          @object_ids = Rails.cache.fetch("#{options[:account].name}#{accessor}ids", expires_in: 10.minutes) do 
            options[:account].send(accessor).map(&:id)
          end
          elements_with_history = elements_with_history.where("historiable_id IN (?)", @object_ids)
        end
      end
      
      elements_with_history = elements_with_history.group_by(&:historiable_id).collect{|k,v| v.first}

      unfiltered_elements = elements_with_history.collect(&:historiable_id)

      elements_with_history = elements_with_history.select {|entry| entry.old_value == ref_value}.collect(&:historiable_id)

      ret = elements_with_history + elements_without_history(unfiltered_elements,options)

      Rails.cache.write(cache_key_for_element_ids_with(options),ret,{expires_in: 5.minutes})
    end

    ret
  end

  private
  # @param [Array] ids_array
  # @param [Hash] options
  def self.elements_without_history(ids_array,options)
    return [] unless options[:class]

    appsignal_key = "add_entries_wout_history.attribute_at_given_time.refine_scope.contacts_search"

    ref_attribute = options.keys.first
    ref_value     = options[options.keys.first]

    elems_wout_hist = options[:class].constantize

    ActiveSupport::Notifications.instrument("account_scope.#{appsignal_key}") do
      if options[:account]
        elems_wout_hist = options[:account].send(options[:class] == "NewContact" ? "contacts" : options[:class].underscore.pluralize)
      end
    end

    elems_wout_hist = elems_wout_hist.includes(:account_contacts)

    attribute_filter = {}
    # local_unique_attributes need to be treated differently
    # because they are not attributes of contacts. they are embeded documents.
    if ref_attribute =~ /local_(.+)_for_(.+)/
      account = NewAccount.where(name: $2).first
      if account.nil?
        raise 'account not found'
      end

      attribute_filter = {account_contacts: {
          "local_#{$1}" => ref_value,
          'account_id' => account.id
      }}
    else
      attribute_filter = {ref_attribute => ref_value}
    end


    # DB hit
    ret = nil
    ActiveSupport::Notifications.instrument("query_mongo.#{appsignal_key}") do
      docs = nil
      ActiveSupport::Notifications.instrument("query.query_mongo.#{appsignal_key}") do
        ids_array.reject! { |item| item.nil? || item == '' }
        if ids_array.empty? or ids_array == [nil]
          ids_array=["0"]
        end
        docs = elems_wout_hist.where(attribute_filter).where("contacts.id NOT IN (?)", ids_array)
      end
      ActiveSupport::Notifications.instrument("map.query_mongo.#{appsignal_key}") do
        ret = docs.map {|c| c.id.to_s}
      end
    end
    
    ret
  end



  def self.cache_key_for_element_ids_with(options={})
    options_string = options.reject{|k,v| k.to_sym == :account }.to_a.join('')
    options_string << options[:account].name if options[:account]

    "history_entries-element_ids_with-#{options_string}"
  end
end
