# encoding: UTF-8

class MailchimpSynchronizer
  include Mongoid::Document

  field :api_key
  field :list_id
  field :status

  belongs_to :account
  has_many :mailchimp_segments
  
  before_create :add_fields
  before_create :set_default_attributes
  
  before_destroy :destroy_segments

  def sync_contacts
    return unless status == :ready

    update_attribute(:status, :working)
    set_api
    set_i18n
    # TODO 
    page = get_scope.page(1).per(10)
    @api.lists.batch_subscribe({
      id: list_id,
      batch: get_batch(page),
      double_optin: false,
      update_existing: true
    })

    update_attribute(:status, :ready)
  end
  handle_asynchronously :sync_contacts
  
 
  def get_batch (page)
    batch = []
    page.each do |c|
      struct = {
        email: {email: get_primary_attribute_value(c, 'Email')},
        email_type: 'text',
        merge_vars: merge_vars_for_contact(c)
      }
      batch << struct
    end
    batch
  end
  
  def merge_vars_for_contact (contact)
    {
      FNAME: contact.first_name,
      LNAME: contact.last_name,
      PHONE: get_primary_attribute_value(contact, 'Telephone'),
      GENDER: get_gender_translation(contact),
      STATUS: get_status_translation(contact),
      COEFF: get_coefficient_translation(contact),
      ADDR: get_primary_attribute_value(contact, 'Address'),
      SYSCOEFF: get_system_coefficient(contact),
      SYSSTATUS: get_system_status(contact)   
    }
  end

  def get_system_status (contact)
    case contact.local_statuses.where(account_id: account.id).first.value
    when :prospect
      '|p||ps||pf|'
    when :student
      '|s||ps||sf|'
    when :former_student
      '|f||pf||sf|'
    end
  end
  
  def get_system_coefficient (contact)
    case contact.coefficients.where(account_id: account.id).first.value
    when 'unknown'
      'unknown'
    when 'perfil', 'pmas'
      'perfil'
    when 'fp'
      'fp'
    when 'pmenos'
      'pmenos'
    end
  end    
  
  def get_status_translation (contact)
    I18n.t('mailchimp.status.' + contact.local_statuses.where(account_id: account.id).first.value.to_s)
  end
  
  def get_gender_translation (contact)
    I18n.t('mailchimp.gender.' + contact.gender)
  end
  
  def get_coefficient_translation (contact)
    contact.coefficients.where(account_id: account.id).first.value.to_s
  end
  
  ##
  #
  # Merge Vars (fields)
  #
  def add_fields
    set_api
    set_i18n
    merge_var_add('PHONE', I18n.t('mailchimp.phone.phone'), 'text') 
    merge_var_add('GENDER', I18n.t('mailchimp.gender.gender'), 'text') 
    merge_var_add('STATUS', I18n.t('mailchimp.status.status'), 'text') 
    merge_var_add('COEFF', I18n.t('mailchimp.coefficient.coefficient'), 'text') 
    merge_var_add('ADDR', I18n.t('mailchimp.address.address'), 'text') 
    merge_var_add('SYSSTATUS', 'System Status', 'text') 
    merge_var_add('SYSCOEFF', 'System Coefficient', 'text') 
  end
  
  def merge_var_add (tag, name, type)
    @api.lists.merge_var_add({
      id: list_id,
      tag: tag,
      name: name,
      options: {field_type: type}
    }) 
  end
  
  def get_scope
    return account.contacts if mailchimp_segments.empty?
    account.contacts.any_of(mailchimp_segments.map {|seg| seg.to_query})
  end
  
  def get_primary_attribute_value (contact, type)
    attr = contact.primary_attribute(account, type)
    if attr.nil?
      nil
    else
      attr.value
    end
  end
  
  def set_api
    @api = Gibbon::API.new(api_key)
  end
  
  def set_i18n
    I18n.locale = PadmaAccount.find(account.name).locale
  end
  
  def set_default_attributes
    status = :ready
  end
  
  def destroy_segments
    MailchimpSegments.where(mailchimp_synchronizer_id: self.id).destroy_all
  end
end
