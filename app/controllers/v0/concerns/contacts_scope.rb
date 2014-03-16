##
# to be included in a controller
module V0::ContactsScope
 
  ##
  #
  # Refines @scope (should be previously defined) using params:
  # 
  # @optional [Array] nids return contacts without id in this array
  # @optional [Array] ids return contacts with id in this array
  # @optional [String] full_text will make a full_text search with this string.
  # @optional [Hash] where Mongoid where selector with additional keys -> :email, :telephone, :address, :local_status, :date_attribute
  # @optional [Array<Hash>] attributes_value_at Array of hashes with keys: :attribute, :value, :ref_date. This will be ANDed, not ORed.
  def refine_scope
    ActiveSupport::Notifications.instrument('refine_scope.contacts_search') do
      refine_by_attributes_at_given_time
      refine_by_ids
      refine_by_full_text_search
      refine_with_contacts_searcher
    end
  end

  private

  def refine_by_attributes_at_given_time
    params[:attribute_values_at].each do |ava|
      ava['value'] = ava['value'] == 'true' if ava['attribute'] == 'in_professional_training'
      @scope = @scope.with_attribute_value_at(ava['attribute'],ava['value'],ava['ref_date'])
    end if params[:attribute_values_at]
  end

  def refine_by_ids
    @scope = @scope.not_in(_id: params[:nids]) if params[:nids]
    @scope = @scope.any_in(_id: params[:ids]) if params[:ids]
  end

  def refine_by_full_text_search
    @scope = @scope.csearch(params[:full_text]) if params[:full_text].present?
  end

  def refine_with_contacts_searcher
    if params[:where].present?
      searcher = ContactSearcher.new(@scope, @account.try(:id))
      @scope = searcher.api_where(params[:where])
    end
  end

end
