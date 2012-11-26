# Stores history in changes to attributes
#
# NOTE: LocalStatus#status changes are stored on a special way:
#   They are considered in the history as local_status_for_AccountName of object Contact
class HistoryEntry
  include Mongoid::Document

  belongs_to :historiable, polymorphic: true

  field :attribute,  type: String
  field :old_value
  field :changed_at

  # Returns value at a given date
  #
  # @param [String] ref_attribute
  # @param [Date] ref_date
  # @param [Hash] options
  # @option [String] class - historiable_type
  # @option [String] id    - historiable_id
  #
  # @return [depends on attribute type?] value
  def self.value_at(ref_attribute, ref_date, options = {})

    scope = self.where(attribute: ref_attribute, changed_at: {'$gte' => ref_date.to_time}).order_by([[:changed_at, :asc]])
    scope = scope.where(historiable_type: options[:class]) if options[:class]
    scope = scope.where(historiable_id: options[:id]) if options[:id]

    scope.first.try :old_value
  end

  # Returns last value for a given attribute
  #
  # @param [String] ref_attribute
  # @param [Hash] options
  # @option [String] class - historiable_type
  # @option [String] id    - historiable_id
  #
  # @return [depends on attribute type?] value
  def self.last_value(ref_attribute, options = {})

    scope = self
    scope = scope.where(historiable_type: options[:class]) if options[:class]
    scope = scope.where(historiable_id: options[:id]) if options[:id]

    # find last change
    scope.first(
        conditions: {
            attribute: ref_attribute,
        },
        sort: [[:changed_at, :desc]]
    ).try :old_value
  end


  # Returns all element ids for elements with given value in given attribute at a given date
  #
  # TODO benchmark
  #
  # @param [Hash] options
  #
  # @option options [Hash] :attribute_name - required - first key-value will be used as attribute(key) and value(value)
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

    # use first key of options as attribute
    ref_attribute = options.keys.first
    ref_date      = options[:at].to_time
    if options[:account_name] && !options[:account]
      options[:account] = Account.where(name: options.delete(:account_name)).first
    end

    conds = {attribute: ref_attribute, changed_at: {'$gte' => ref_date}}
    conds = conds.merge({historiable_type: options[:class]}) if options[:class]

    # first DB hit
    res = self.collection.map_reduce(map_js,reduce_js,query: conds,out: 'oldest_date')
    res = filter_post_map_reduce(res,options) # TODO refactor to a finalize function in the mapreduce?
    res = res.to_a.map{|rdoc| rdoc['_id']['historiable_id'] }

    add_elements_without_history(res,options)
  end

  private

  def self.add_elements_without_history(ids_array,options)
    ref_attribute = options.keys.first
    ref_value     = options[options.keys.first]

    if options[:class]
      if options[:account]
        elems_wout_hist = options[:account].send(options[:class].underscore.pluralize)
      else
        elems_wout_hist = options[:class].constantize
      end

      attribute_filter = {}
      # local_unique_attributes need to be treated differently
      # because they are not attributes of contacts. they are embeded documents.
      if ref_attribute =~ /local_(.+)_for_(.+)/
        lua_type = "Local#{$1.camelize}"
        account = Account.where(name: $2).first
        if account.nil?
          raise 'account not found'
        end

        attribute_filter = {local_unique_attributes: {'$elemMatch' => {
            '_type' => lua_type,
            'value' => ref_value,
            'account_id' => account.id
        }}}
      else
        attribute_filter = {ref_attribute => ref_value}
      end

                              # third DB hit
      ids_array = ids_array + elems_wout_hist.where(attribute_filter).not_in(_id: ids_array).only('_id').map{|doc|doc._id} if elems_wout_hist
    end

    ids_array
  end

  # Filteres mapreduce result according to expected value and scoping to account
  def self.filter_post_map_reduce(mr_result, options)
    cond = {'value.old_value' => options[options.keys.first]}
    if options[:account].present? && options[:class].present?
      # if Account and Object class where given we can find Objects linked to Account
      cond = cond.merge('_id.historiable_id' => { '$in' => options[:account].send(options[:class].underscore.pluralize).map(&:_id)})
    end
    mr_result.find(cond)
  end

  # ]Groups by Historiable(h_id)#attribute
  # @return [String] javascript map function for MongoDB MapReduce
  def self.map_js
    "function(){
      emit( {historiable_type: this.historiable_type, historiable_id: this.historiable_id, attribute: this.attribute},
            {changed_at: this.changed_at, old_value: this.old_value}
      );
    }"
  end

  # Selects oldest value comparing changed_at
  # @return [String] javascript reduce function for MongoDB MapReduce
  def self.reduce_js
    "function(k,vs){
      var oldest = null;
      var value = null;
      vs.forEach(function(v){
        if(v.changed_at < oldest || oldest == null){
          oldest = v.changed_at;
          value  = v.old_value;
        };
      });
      return {changed_at: oldest, old_value: value};
    }"
  end
end
