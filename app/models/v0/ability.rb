class V0::Ability
  include CanCan::Ability

  def initialize(account,app_key)
    cannot(:manage, :all)
    unless app_key.nil?
      case app_key
      when ENV['office_key']
        # office permitions
        can [:read,:update], Contact
      when V0::ApplicationController::APP_KEY
        if account.nil?
          # Account not specified for this request
          can :manage, :all

          cannot :destroy, Contact
          cannot :destroy, ContactAttribute
          cannot :destroy, Attachment
          cannot :create, Merge
        else

          # Account specified in this request
          can :manage, :all

          # Contact
          cannot :destroy, Contact
          can :destroy, Contact, owner: account

          # ContactAttribute
          cannot :manage, ContactAttribute
          can :custom_keys, ContactAttribute
          can :read, ContactAttribute do |ca|
            # TODO refactor from block into argument so we can use ContactAttribute#accesible_by(account)
            ca.public? || ca.account == account
          end
          can [:update, :destroy], ContactAttribute, account: account
          can :create, ContactAttribute do |ca|
            ca.contact.linked_to?(account)
          end

          # Attachment
          cannot :manage, Attachment
          can :read, Attachment do |a|
            # TODO refactor from block into argument so we can use Attachment#accesible_by(account)
            a.public? || a.account == account
          end
          can [:update, :destroy], Attachment, account: account
          can :create, Attachment do |a|
            c.contact.linked_to?(account)
          end

          # Merge
          cannot :create, Merge
          can :create, Merge, {first_contact: {owner: account}, second_contact: {owner: account}}

          # Tags
          cannot :manage, Tag
          can :manage, Tag, account_id: account.id

        end
      end
    end
  end
end
