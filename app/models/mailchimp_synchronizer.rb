# encoding: UTF-8

class MailchimpSynchronizer
  include Mongoid::Document

  field :api_key
  field :list_id
  field :status
  field :filter_method
  field :coefficient_group
  field :contact_attributes
  field :last_synchronization

  attr_accessor :has_coefficient_group

  belongs_to :account
  validates_presence_of :account

  has_many :mailchimp_segments
  
  before_create :set_default_attributes
  after_save :finish_setup
  
  before_destroy :destroy_segments

  CONTACTS_BATCH_SIZE = 1000

  RETRIES = 10
  def subscribe_contacts
    return unless status == :ready
    Rails.logger.info "[mailchimp_synchronizer #{self.id}] starting"
    retries = RETRIES

    update_attribute(:status, :working)
    set_api
    set_i18n
    get_scope.page(1).per(CONTACTS_BATCH_SIZE).num_pages.times do |i|
      Rails.logger.info "[mailchimp_synchronizer #{self.id}] batch #{i}"
      page = get_scope.page(i + 1).per(CONTACTS_BATCH_SIZE)
      begin
        @api.lists.batch_subscribe({
          id: list_id,
          batch: get_batch(page),
          double_optin: false,
          update_existing: true
        })
      rescue Gibbon::MailChimpError => e
        Rails.logger.info "[mailchimp_synchronizer #{self.id}] retrying: #{e.message}"
        retries -= 1
        if retries >= 0
          sleep((RETRIES-retries)*10)
          retry
        else
          Rails.logger.info "[mailchimp_synchronizer #{self.id}] failed: #{e.message}"
          email_admins_about_failure(account.name, e.message)
          update_attribute(:status, :failed)
          raise e
        end
      rescue Timeout::Error 
        Rails.logger.info "[mailchimp_synchronizer #{self.id}] timeout subscribing contacts to mailchimp, retrying"
        retry
      end
    end
    update_attribute(:last_synchronization, DateTime.now.to_s)
    update_attribute(:status, :ready)
    return true
  rescue => e
    Rails.logger.warn "[mailchimp_synchronizer #{self.id}] failed: #{e.message}"
    update_attribute(:status, :failed)
    wait_and_set_ready # this will run on the background and set this to ready for retry
    raise e
  end
  handle_asynchronously :subscribe_contacts

  def wait_and_set_ready
    Rails.logger.warn "[mailchimp_synchronizer #{self.id}] setting to ready for retry"
    update_attribute(:status, :ready)
  end
  handle_asynchronously :wait_and_set_ready, run_at: Proc.new { 5.minutes.from_now }
  
  def unsubscribe_contacts (querys = [])
    update_attribute(:status, :working)
    set_api
    
    if !querys.empty?
      contacts_scope = Contact.where("$and" => querys)
    else
      contacts_scope = Contact.all
    end

    contacts_scope.page(1).per(CONTACTS_BATCH_SIZE).num_pages.times do |i|
      page = contacts_scope.page(i + 1).per(CONTACTS_BATCH_SIZE)
      response = @api.lists.batch_unsubscribe({
        id: list_id,
        batch: get_batch(page, true), 
        delete_member: true,
        send_goodbye: false 
      })
    end   
    update_attribute(:status, :ready)
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
    response = 
    {
      FNAME: contact.first_name,
      LNAME: contact.last_name,
      PHONE: get_primary_attribute_value(contact, 'Telephone'),
      GENDER: get_gender_translation(contact),
      STATUS: get_status_translation(contact),
      groupings: get_coefficient_translation(contact),
      ADDR: get_primary_attribute_value(contact, 'Address'),
      SYSCOEFF: get_system_coefficient(contact),
      SYSSTATUS: get_system_status(contact),
      FOLLOWEDBY: get_followers_for(contact),
    } 
    if contact_attributes
      contact_attributes.split(",").each do |contact_attribute|
        if %w(email telephone address custom_attribute date_attribute identification occupation 
        contact_attachment social_network_id).include? contact_attribute
          response[get_tag_for(contact_attribute)] = contact.send(contact_attribute.pluralize).first.try :value
        else
          response[get_tag_for(contact_attribute)] = contact.contact_attributes.where(name: contact_attribute).first.try :value
        end
      end
    end
    response
  end

  def get_system_status (contact)
    case contact.local_statuses.where(account_id: account.id).first.try(:value).try(:to_sym)
    when :prospect
      '|p||ps||pf|'
    when :student
      '|s||ps||sf|'
    when :former_student
      '|f||pf||sf|'
    else
      ''
    end
  end
  

  def get_system_coefficient (contact)
    case contact.coefficients.where(account_id: account.id).first.try(:value)
    when 'unknown'
      'unknown'
    when 'perfil', 'pmas'
      'perfil'
    when 'fp'
      'fp'
    when 'pmenos'
      'pmenos'
    else
      ''
    end
  end    
  
  def get_status_translation (contact)
    ls = contact.local_statuses.where(account_id: account.id).first.try(:value).try(:to_s)
    ls.nil?? '' : I18n.t("mailchimp.status.#{ls}")
  end
  
  def get_gender_translation (contact)
    (contact.gender)? I18n.t("mailchimp.gender.#{contact.gender}") : ''
  end
  
  def get_coefficient_translation (contact)
    [
      {id: coefficient_group, groups: [set_fp_to_np(contact.coefficients.where(account_id: account.id).first.try(:value).try(:to_s) || '')]}
    ]
  end

  def set_fp_to_np(coefficient)
    if coefficient == "fp"
      return "np"
    else
      return coefficient
    end
  end

  def get_followers_for(contact)
    followers = []
    response = Typhoeus::Request.get(
      PADMA_CRM_HOST + "/api/v0/follows/followed_by",
      params: {  app_key: ENV["crm_key"],
                  account_name: account.name,
                  contact_id: contact.id}
      ) 
    if response.code == 200
      followers = JSON.parse(response.body)
    end

    if followers.blank?
      return "none"
    else
      followers << "any"
      return followers.join(",")
    end
  end
  
  #
  # Merge Vars (fields)
  #
  def update_fields_in_mailchimp
    set_api
    set_i18n
    merge_var_add('PHONE', I18n.t('mailchimp.phone.phone'), 'text') 
    merge_var_add('GENDER', I18n.t('mailchimp.gender.gender'), 'text', {public: false}) 
    merge_var_add('STATUS', I18n.t('mailchimp.status.status'), 'text', {public: false}) 
    merge_var_add('ADDR', I18n.t('mailchimp.address.address'), 'text') 
    merge_var_add('SYSSTATUS', 'System Status', 'text', {public: false, show: false}) 
    merge_var_add('SYSCOEFF', 'System Coefficient', 'text', {public: false, show: false}) 
    merge_var_add('FOLLOWEDBY', 'Followed by', 'text', {public: false})
  end
  
  def merge_var_add (tag, name, type, options={})
    options = options.merge!({field_type: type})
    begin
      @api.lists.merge_var_add({
        id: list_id,
        tag: tag,
        name: name,
        options: options
      }) 
    rescue Gibbon::MailChimpError => e
      raise unless e.message =~ /already exists/
    end
  end

  def merge_var_del(tag_name)
    begin
      @api.lists.merge_var_del({
        id: list_id,
        tag: tag_name
      }) 
    rescue Gibbon::MailChimpError => e
      raise
    end
  end

  def add_custom_fields_in_mailchimp
    set_api
    set_i18n
    contact_attributes.split(",").each do |contact_attribute|
      merge_var_add(get_tag_for(contact_attribute), contact_attribute.capitalize, 'text', {public: false})
    end
  end

  def remove_unused_fields_in_mailchimp(field_names)
    return if field_names.blank?
    set_api
    field_names.each do |field_name|
      merge_var_del(get_tag_for(field_name))
    end
  end

  # do not pass 10 bytes
  # each should be unique
  def get_tag_for(contact_attribute)
    Digest::SHA1.hexdigest(contact_attribute)[0..9].upcase
  end
  
  def update_sync_options (params)
    unless params[:contact_attributes].nil?
      remove_unused_fields_in_mailchimp(
        contact_attributes.split(",") - params[:contact_attributes].split(",")
        ) unless contact_attributes.nil?
      update_attribute(:contact_attributes, params[:contact_attributes])
      add_custom_fields_in_mailchimp
    end

    if !params[:list_id].nil? && params[:list_id] != list_id
      update_attribute(:list_id, params[:list_id])
      update_fields_in_mailchimp
      initialize_list_groups
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
  
  def subscribe_contact(contact_id)
    return if is_in_scope(contact_id) == false
    retries = RETRIES

    update_attribute(:status, :working)
    c = Contact.find contact_id
    set_api
    set_i18n
    begin
      @api.lists.subscribe({
        id: list_id,
        email: {email: get_primary_attribute_value(c, 'Email')},
        merge_vars: merge_vars_for_contact(c),
        double_optin: false,
        update_existing: true
      })
    rescue Gibbon::MailChimpError => e
      Rails.logger.info "[mailchimp_subscribe of contact #{contact_id}] retrying: #{e.message}"
      retries -= 1
      if retries >= 0
        sleep((RETRIES-retries)*10)
        retry
      else
        Rails.logger.info "[mailchimp_subscribe of contact #{contact_id}] failed: #{e.message}"
        raise e
      end
    rescue Timeout::Error 
      Rails.logger.info "[mailchimp_subscribe of contact #{contact_id}] timeout subscribing contacts to mailchimp, retrying"
      retry
    end
    return true
  rescue => e
    Rails.logger.warn "[mailchimp_subscribe of contact #{contact_id}] failed: #{e.message}"
    raise e
  end
  handle_asynchronously :subscribe_contact
  
  def update_contact(contact_id, old_mail)
    return if is_in_scope(contact_id) == false
    retries = RETRIES
    
    update_attribute(:status, :working)
    c = Contact.find contact_id
    set_api
    set_i18n
    merge_vars = merge_vars_for_contact(c)
    merge_vars['EMAIL'] = get_primary_attribute_value(c, 'Email')
    begin
      resp = @api.lists.update_member({
        id: list_id,
        email: {email: old_mail},
        merge_vars: merge_vars
      })
    rescue Gibbon::MailChimpError => e
      Rails.logger.info "[mailchimp_update of contact #{contact_id}] retrying: #{e.message}"
      retries -= 1
      if retries >= 0
        sleep((RETRIES-retries)*10)
        retry
      else
        Rails.logger.info "[mailchimp_update of contact #{contact_id}] failed: #{e.message}"
        raise e
      end
    rescue Timeout::Error 
      Rails.logger.info "[mailchimp_update of contact #{contact_id}] timeout subscribing contacts to mailchimp, retrying"
      retry
    end
    return true
  rescue => e
    Rails.logger.warn "[mailchimp_update of contact #{contact_id}] failed: #{e.message}"
    raise e
  end
  handle_asynchronously :update_contact

  def unsubscribe_contact(contact_id, email, delete_member = true)
    return if is_in_scope(contact_id) == false
    retries = RETRIES

    update_attribute(:status, :working)
    set_api
    set_i18n
    begin
      @api.lists.unsubscribe({
        id: list_id,
        email: {email: email},
        delete_member: delete_member
      })
    rescue Gibbon::MailChimpError => e
      Rails.logger.info "[mailchimp_unsubscribe of contact #{contact_id}] retrying: #{e.message}"
      retries -= 1
      if retries >= 0
        sleep((RETRIES-retries)*10)
        retry
      else
        Rails.logger.info "[mailchimp_unsubscribe of contact #{contact_id}] failed: #{e.message}"
        raise e
      end
    rescue Timeout::Error 
      Rails.logger.info "[mailchimp_unsubscribe of contact #{contact_id}] timeout subscribing contacts to mailchimp, retrying"
      retry
    end
    return true
  rescue => e
    Rails.logger.warn "[mailchimp_unsubscribe of contact #{contact_id}] failed: #{e.message}"
    raise e
  end
  handle_asynchronously :unsubscribe_contact

  def get_scope
    return account.contacts.where(:updated_at.gt => last_synchronization || "1/1/2000 00:00") if self.filter_method == 'all'
    if mailchimp_segments.empty?
      Contact.any_in( account_ids: [self.account.id] ).where(:updated_at.gt => last_synchronization || "1/1/2000 00:00")
    else
      Contact.where( :updated_at.gt => last_synchronization || "1/1/2000 00:00", "$or" => mailchimp_segments.map {|seg| seg.to_query})
    end
  end

  def is_in_scope(contact_id)
    return true if self.filter_method == 'all' || mailchimp_segments.empty?
    return Contact.where( "$or" => mailchimp_segments.map {|seg| seg.to_query}).and(_id: contact_id).count > 0 ? true : false
  end
  
  def get_primary_attribute_value (contact, type)
    attr = contact.primary_attribute(account, type)
    attr.try :value
  end
  
  def set_api
    @api = Gibbon::API.new(api_key)
  end
  
  def set_i18n
    padma_account = PadmaAccount.find(account.name)
    if padma_account
      I18n.locale = padma_account.locale
    end
  end

  def initialize_list_groups
    find_or_create_coefficients_group
  end
  
  def find_or_create_coefficients_group
    set_i18n
    set_api
    begin
      mailchimp_coefficient_group = nil
      if @has_coefficient_group
        groupings = @api.lists.interest_groupings({
          id: list_id
          })
        groupings.each do |group|
          if group["name"] == I18n.t('mailchimp.coefficient.coefficient')
            mailchimp_coefficient_group = group
          end
        end
      else
        mailchimp_coefficient_group = @api.lists.interest_grouping_add({
          id: list_id,
          name: I18n.t('mailchimp.coefficient.coefficient'),
          type: 'hidden',
          groups: ["unknown", "perfil", "pmas", "pmenos", "np"]
          })
      end
      update_attribute(:coefficient_group, mailchimp_coefficient_group['id'])
    rescue Gibbon::MailChimpError => e
      if e.message =~ /already exists/ && @has_coefficient_group == false
        @has_coefficient_group = true
        retry
      else
        raise
      end
    end
  end

  def email_admins_about_failure(account_name, error_message)
    ContactsMailer.alert_failure(account_name, error_message).deliver
  end

  def set_default_attributes
    self.status = :setting_up
    self.filter_method = nil
    self.contact_attributes = ""
  end
  
  def destroy_segments
    MailchimpSegment.where(mailchimp_synchronizer_id: self.id).destroy_all
  end

  def self.synchronize_all
    self.all.each do |ms|
      Rails.logger.info "MAILCHIMP - synchronizing #{ms.account.name}"
      ms.subscribe_contacts # this will queue to background
    end
  end

  def finish_setup
    if (status == :setting_up) && completed_initial_setup?
      update_attribute :status, :ready
    end
  end

  def completed_initial_setup?
    list_id.present? && (
      !mailchimp_segments.empty? || filter_method == 'all'
    )
  end
end
