class V0::Ability
  include CanCan::Ability

  def initialize(account)
    # The first argument to `can` is the action you are giving the user permission to do.
    # If you pass :manage it will apply to every action. Other common actions here are
    # :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on. If you pass
    # :all it will apply to every resource. Otherwise pass a Ruby class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details: https://github.com/ryanb/cancan/wiki/Defining-Abilities

    if account.nil?
      # Account not specified for this request
      can :manage, :all

      cannot :destroy, Contact
      cannot :destroy, ContactAttribute
      cannot :create, Merge
    else

      # Account specified in this request
      can :manage, :all

      # Contact
      cannot :destroy, Contact
      can :destroy, Contact, owner: account

      # ContactAttribute
      cannot :manage, ContactAttribute
      can :read, ContactAttribute do |ca|
        # TODO refactor from block into argument so we can use ContactAttribute#accesible_by(account)
        ca.public? || ca.account == account
      end
      can [:update, :destroy], ContactAttribute, account: account
      can :create, ContactAttribute do |ca|
        ca.contact.linked_to?(account)
      end

      # Merge
      cannot :create, Merge
      can :create, Merge do |m|
        own_first, own_second = false, false
        
        if m.first_contact_id
          own_first = Contact.find(m.first_contact_id).owner == account 
        end

        if m.second_contact_id
          own_second = Contact.find(m.second_contact_id).owner == account
        end
        
        own_first && own_second
      end

    end



  end
end