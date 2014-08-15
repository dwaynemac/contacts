# encoding: UTF-8

class MailchimpSynchronizer
  include Mongoid::Document

  field :api_key
  field :list_id
  field :status
  field :filter_method

  belongs_to :account
  has_many :mailchimp_segments
  
  before_create :set_default_attributes
  
  before_destroy :destroy_segments

  def subscribe_contacts
    return unless status == :ready

    update_attribute(:status, :working)
    set_api
    set_i18n
    get_scope.page(1).per(5000).num_pages.times do |i|
    page = get_scope.page(i + 1).per(5000)
      @api.lists.batch_subscribe({
        id: list_id,
        batch: get_batch(page),
        double_optin: false,
        update_existing: true
      })
    end

    update_attribute(:status, :ready)
  end
  
  def unsubscribe_contacts (querys = [])
    set_api
    
    if !querys.empty?
      contacts_scope = Contact.where("$and" => querys)
    else
      contacts_scope = Contact.all
    end

    contacts_scope.page(1).per(5000).num_pages.times do |i|
      page = contacts_scope.page(i + 1).per(5000)
      response = @api.lists.batch_unsubscribe({
        id: list_id,
        batch: get_batch(page, true), 
        delete_member: true,
        send_goodbye: false 
      })
    end   
  end
  handle_asynchronously :unsubscribe_contacts
 
  def get_batch (page, unsubscribe = false)
    batch = []
    page.each do |c|
      struct = {}
      if !unsubscribe
        struct['email'] = {email: get_primary_attribute_value(c, 'Email')}
        struct['email_type'] = 'text'
        struct['merge_vars'] =  merge_vars_for_contact(c)
      else
        struct['email'] = get_primary_attribute_value(c, 'Email')
      end
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
  
  #
  # Merge Vars (fields)
  #
  def update_fields_in_mailchimp
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
  
  #
  # merge_var_add throws an exception
  # the field already exists
  #
  def merge_var_add (tag, name, type)
    begin
      @api.lists.merge_var_add({
        id: list_id,
        tag: tag,
        name: name,
        options: {field_type: type}
      }) 
    rescue Gibbon::MailChimpError
    end
  end
  
  def update_sync_options (params)
    if !params[:list_id].nil? && params[:list_id] != list_id
      update_attribute(:list_id, params[:list_id])
      update_fields_in_mailchimp
    end
    
    if !params[:filter_method].nil? && !params[:filter_method].empty? && params[:filter_method] != filter_method
      if filter_method == 'all' && params[:filter_method] == 'segments'
        unsubscribe_contacts(mailchimp_segments.map {|x| x.to_query(true)})      
      end
      update_attribute(:filter_method, params[:filter_method])
    end
    
    if !params[:api_key].nil? && params[:api_key] != api_key
      update_attribute(:api_key, params[:api_key])
    end
  end
  
  def get_scope
    return account.contacts if self.filter_method == 'all'
    Contact.where( "$or" => mailchimp_segments.map {|seg| seg.to_query})
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
    self.status = :ready
    self.filter_method = :not_set
  end
  
  def destroy_segments
    MailchimpSegment.where(mailchimp_synchronizer_id: self.id).destroy_all
  end
end
