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
  field :merge_fields
  field :batch_statuses

  attr_accessor :has_coefficient_group

  belongs_to :account
  validates_presence_of :account

  has_many :mailchimp_segments
  
  before_create :set_default_attributes
  #after_update :find_or_create_coefficients_group
  after_save :finish_setup
  
  before_destroy :destroy_segments

  CONTACTS_BATCH_SIZE = 1000

  def queue_subscribe_contacts(options={})
    @skip = false
    from_last_synchronization = options.blank? ? nil : options[:from_last_synchronization]

    unless options[:force]
      Delayed::Job.all.each do |dj|
        begin
          handler = YAML.load(dj.handler)
          if (handler.method_name == :subscribe_contacts) && (handler.account.name == account.name)
           # subscribe_contacts is already queued for this account and ready to run
           @skip = true 
           break
          end
        rescue
          next
        end
      end
    end

    self.delay(priority: 2).subscribe_contacts(from_last_synchronization) unless @skip
  end

  def complete_sync
    update_batch_statuses
    if filter_method == 'segments'
      unsubscribe_contacts(mailchimp_segments.map {|x| x.to_query(true)})
    end
    queue_subscribe_contacts({from_last_synchronization: false})
  end

  RETRIES = 10
  def subscribe_contacts(from_last_synchronization = true, batch_size = nil)
    return unless status == :ready
    return unless account.padma.enabled?
    Rails.logger.info "[mailchimp_synchronizer #{self.id}] starting"
    retries = RETRIES
    batch_size = CONTACTS_BATCH_SIZE if batch_size.nil?

    update_attribute(:status, :working)
    set_api
    set_i18n
    get_scope(from_last_synchronization).page(1).per(batch_size).num_pages.times do |i|
      Rails.logger.info "[mailchimp_synchronizer #{self.id}] batch #{i}"
      page = get_scope(from_last_synchronization).page(i + 1).per(batch_size)
      begin
        resp = @api.batches.create(body: {
          operations: get_batch(page)
        })
        current_batches = decode(batch_statuses)
        current_batches[resp.body["id"]] = resp.body["status"]
        update_attribute(:batch_statuses, encode(current_batches))
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
      rescue Timeout::Error => e
        new_batch_size = batch_size / 2
        if new_batch_size > 100
          Rails.logger.info "[mailchimp_synchronizer #{self.id}] timeout subscribing contacts to mailchimp, retrying with batch_size #{new_batch_size}"
          update_attribute(:status, :ready)
          subscribe_contacts(from_last_synchronization,new_batch_size)
        else
          Rails.logger.info "[mailchimp_synchronizer #{self.id}] timeout subscribing contacts to mailchimp. Quitting."
          raise e
        end
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

  def wait_and_set_ready
    Rails.logger.warn "[mailchimp_synchronizer #{self.id}] setting to ready for retry"
    update_attribute(:status, :ready)
  end
  handle_asynchronously :wait_and_set_ready, run_at: Proc.new { 5.minutes.from_now }
  
  def unsubscribe_contacts(querys = [])
    update_attribute(:status, :working)
    set_api
    
    if !querys.empty?
      contacts_scope = Contact.where("$and" => querys)
    else
      # TODO chequear que esto este bien
      contacts_scope = Contact.all
    end

    contacts_scope.page(1).per(CONTACTS_BATCH_SIZE).num_pages.times do |i|
      page = contacts_scope.page(i + 1).per(CONTACTS_BATCH_SIZE)
      resp = @api.batches.create(body: {
          operations: get_batch(page, true)
        })
      current_batches = decode(batch_statuses)
      current_batches[resp.body["id"]] = resp.body["status"]
      update_attribute(:batch_statuses, encode(current_batches))
    end
    update_attribute(:status, :ready)
  end
  handle_asynchronously :unsubscribe_contacts
 
  def get_batch(page, unsubscribe = false)
    batch = []
    page.each do |c|
      struct = {}
      if !unsubscribe
        struct['method'] = "PUT"
        struct['path'] = "lists/#{list_id}/members/#{subscriber_hash(get_primary_attribute_value(c, "Email"))}"
        struct['body'] = encode({
          status_if_new: "subscribed",
          status: "subscribed",
          email_address: get_primary_attribute_value(c, "Email"),
          merge_fields: merge_vars_for_contact(c),
          interests: { "#{decode(coefficient_group)["interests"][get_coefficient_translation(c)]}" => true} #TODO check if this works and put interest in single create and update
        })
      else
        struct['method'] = "DELETE"
        struct['path'] = "lists/#{list_id}/members/#{subscriber_hash(get_primary_attribute_value(c, 'Email'))}"
      end
      batch << struct
    end
    batch
  end
  
  def merge_vars_for_contact(contact)
    response = 
    {
      FNAME: contact.first_name || "",
      LNAME: contact.last_name || "",
      PHONE: get_primary_attribute_value(contact, 'Telephone') || "",
      GENDER: get_gender_translation(contact) || "",
      STATUS: get_status_translation(contact) || "",
      ADDR: get_primary_attribute_value(contact, 'Address') || "",
      SYSCOEFF: get_system_coefficient(contact) || "",
      SYSSTATUS: get_system_status(contact) || "",
      FOLLOWEDBY: get_followers_for(contact) || "",
      TEACHER: get_local_teacher_for(contact) || "",
      PADMA_TAGS: get_tags_for(contact) || ""
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

  def get_system_status(contact)
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
  
  def get_system_coefficient(contact)
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
  
  def get_status_translation(contact)
    ls = contact.local_statuses.where(account_id: account.id).first.try(:value).try(:to_s)
    ls.nil?? '' : I18n.t("mailchimp.status.#{ls}")
  end
  
  def get_gender_translation(contact)
    (contact.gender)? I18n.t("mailchimp.gender.#{contact.gender}") : ''
  end
  
  def get_coefficient_translation(contact)
    set_fp_to_np(contact.coefficients.where(account_id: account.id).first.try(:value).try(:to_s))
  end

  def set_fp_to_np(coefficient)
    if coefficient == "fp"
      return "np"
    else
      return coefficient
    end
  end
  
  def get_local_teacher_for(contact)
    contact.local_teachers.where(account_id: account.id).first.try(:value)
  end

  def get_tags_for(contact)
    contact.tags.where(account_id: account.id).map(&:name).join(", ")
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
    merge_var_add('GENDER', I18n.t('mailchimp.gender.gender'), 'text', false) 
    merge_var_add('STATUS', I18n.t('mailchimp.status.status'), 'text', false) 
    merge_var_add('ADDR', I18n.t('mailchimp.address.address'), 'text') 
    merge_var_add('SYSSTATUS', 'System Status', 'text', false) 
    merge_var_add('SYSCOEFF', 'System Coefficient', 'text', false) 
    merge_var_add('FOLLOWEDBY', 'Followed by', 'text', false)
    merge_var_add('TEACHER', I18n.t('mailchimp.teacher'), 'text', false)
    merge_var_add('PADMA_TAGS', I18n.t('mailchimp.padma_tags'), 'text', false)
  end
  
  def merge_var_add(tag, name, type, ispublic = true , options={})
    local_fields = decode(merge_fields)
    if !local_fields.keys.include?(name)
      begin
        resp = @api.lists(list_id).merge_fields.create( body: {
          tag: tag,
          name: name,
          type: type,
          public: ispublic,
          options: options
        })
        local_fields[name] = resp.body["merge_id"]
        update_attribute(:merge_fields, encode(local_fields))
      rescue Gibbon::MailChimpError => e
        raise unless e.message =~ /already exists/
      end
    end
  end

  def merge_var_del(tag_name)
    local_fields = decode(merge_fields)
    if local_fields.keys.include?(tag_name)
      begin
        @api.lists(list_id).merge_fields(local_fields[tag_name]).delete
      rescue Gibbon::MailChimpError
        raise
      end
    end
  end

  def add_custom_fields_in_mailchimp
    set_api
    set_i18n
    contact_attributes.split(",").each do |contact_attribute|
      merge_var_add(get_tag_for(contact_attribute), contact_attribute.capitalize, 'text', false)
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
  
  def update_sync_options(params)
    if !params[:list_id].nil? && params[:list_id] != list_id
      update_attribute(:list_id, params[:list_id])
      update_fields_in_mailchimp
      initialize_list_groups
    end
    
    unless params[:contact_attributes].nil?
      remove_unused_fields_in_mailchimp(
        contact_attributes.split(",") - params[:contact_attributes].split(",")
        ) unless contact_attributes.nil?
      update_attribute(:contact_attributes, params[:contact_attributes])
      add_custom_fields_in_mailchimp
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

    c = Contact.find contact_id
    set_api
    set_i18n
    begin
      @api.lists(list_id).members(subscriber_hash(get_primary_attribute_value(c, "Email"))).upsert(
        body: {
          email_address: get_primary_attribute_value(c, "Email"),
          status_if_new: "subscribed",
          status: "subscribed",
          merge_fields: merge_vars_for_contact(c),
          interests: { "#{decode(coefficient_group)["interests"][get_coefficient_translation(c)]}" => true}
        }
      )
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
    in_scope = is_in_scope(contact_id)
    in_list = is_in_list?(old_mail)
    if in_scope == false && in_list
      unsubscribe_contact(contact_id, old_mail, true)
    elsif in_scope == true && !in_list
      subscribe_contact(contact_id)
    end
    return if in_scope == false || (in_scope == true && !in_list)
    retries = RETRIES
    
    c = Contact.find contact_id
    set_api
    set_i18n
    merge_vars = merge_vars_for_contact(c)
    merge_vars['EMAIL'] = get_primary_attribute_value(c, 'Email')
    begin
      @api.lists(list_id).members(subscriber_hash(old_mail)).update(body: {
        merge_fields: merge_vars,
        interests: { "#{decode(coefficient_group)["interests"][get_coefficient_translation(c)]}" => true} #TODO check if this works and put interest in single create and update
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

  def unsubscribe_contact(contact_id, email, is_in_list = false, delete_member = true)
    return if !is_in_list && is_in_scope(contact_id) == false
    retries = RETRIES

    set_api
    set_i18n
    begin
      @api.lists(list_id).members(subscriber_hash(email)).delete
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

  # Check if a single email is currently subscribed to a list
  def is_in_list?(email)
    set_api
    begin
      resp = @api.lists(list_id).members(subscriber_hash(email)).retrieve
      return resp.body["status"] == "subscribed"
    rescue Gibbon::MailChimpError
      return false
    end
  end

  def get_scope(from_last_synchronization)
    if self.filter_method == "all"
      if from_last_synchronization
        account.contacts.where(:updated_at.gt => last_synchronization || "1/1/2000 00:00")
      else
        account.contacts
      end
    elsif mailchimp_segments.empty?
      if from_last_synchronization
        Contact.any_in( account_ids: [self.account.id] ).where(:updated_at.gt => last_synchronization || "1/1/2000 00:00")
      else
        Contact.any_in( account_ids: [self.account.id] )
      end
    else
      if from_last_synchronization
        account.contacts.where( :updated_at.gt => last_synchronization || "1/1/2000 00:00", "$or" => mailchimp_segments.map {|seg| seg.to_query})
      else
        account.contacts.where( "$or" => mailchimp_segments.map {|seg| seg.to_query})
      end
    end
  end

  def calculate_scope_count(filter_method, segments)
    return account.contacts.count if filter_method == 'all'
    if segments.blank?
      Contact.any_in( account_ids: [self.account.id] ).reject{|c| c.primary_attribute(account, "Email").nil?}.count
    else
      account.contacts.where( 
        "$or" => segments.reject{|s| s["_destroy"] == "1"}.map {|seg| MailchimpSegment.to_query(
          (seg.key?("student") ? seg["student"] : []), 
          (seg.key?("coefficient") ? seg["coefficient"] : []), 
          (seg.key?("gender") ? seg["gender"] : ""), 
          account.id
          )
        }
                            ).reject{|c| c.primary_attribute(account, "Email").nil?}.count
    end
  end

  def is_in_scope(contact_id)
    return true if self.filter_method == 'all' || mailchimp_segments.empty?
    return Contact.where( "$or" => mailchimp_segments.map {|seg| seg.to_query}).and(_id: contact_id).count > 0 ? true : false
  end
  
  def get_primary_attribute_value(contact, type)
    attr = contact.primary_attribute(account, type)
    attr.try :value
  end
  
  def set_api
    @api = Gibbon::Request.new(api_key: api_key)
  end
  
  def set_i18n
    padma_account = PadmaAccount.find(account.name)
    if padma_account
      I18n.locale = padma_account.locale
    end
  end

  def check_coefficient_group
    find_or_create_coefficients_group unless coefficient_group_valid?
  end
  handle_asynchronously :check_coefficient_group, priority: 1

  def initialize_list_groups
    find_or_create_coefficients_group
  end

  def coefficient_group_valid?
    group_id = decode(coefficient_group)["id"]
    local_interests = decode(coefficient_group)["interests"]
    
    return false if group_id.blank? || local_interests.values.any? {|v| v.blank?}
    response = false

    set_i18n
    set_api
    begin
      group = @api.lists(list_id).interests_categories(group_id).retrieve.body
      interests = @api.lists(list_id).interest_categories(group_id).interests.retrieve.body
      if interests["total_items"] == local_interests.count && 
        interests["interests"].all? { |i| local_interests[i["name"]] == i["id"]} &&
        group["title"].try(:upcase) == I18n.t('mailchimp.coefficient.coefficient').try(:upcase)
        response = true
      end
    rescue Gibbon::MailChimpError => e
      set(status: :failed)
      email_admins_about_failure(account.name, e.message)
      raise
    end
    response
  end
  
  def find_or_create_coefficients_group
    set_i18n
    set_api

    create_coefficient_group()
    if decode(coefficient_group)["id"] == "already exists"
      retrieve_coefficient_group()
    end

    if decode(coefficient_group)["id"] == "failed"
      update_attributes(:stauts, :failed)
      email_admins_about_failure(account.name, decode(coefficient_group).key?("message") ? decode(coefficient_group)["message"] : "")
    end
  end

  def batch_status(batch_id)
    set_api
    begin
      @api.batches(batch_id).retrieve.body["status"]
    rescue
      "failed"
    end
  end

  # TODO if rows failed during batch, show it
  def update_batch_statuses
    current_batches = decode(batch_statuses)
    current_batches.each do |id, status|
      case batch_status(id)
      when "finished"
        current_batches.delete(id)
      else
        current_batches[id] = batch_status(id)
      end
    end
    update_attribute(:batch_statuses, encode(current_batches))
  end

  def is_synchronizing?
    update_batch_statuses
    !decode(batch_statuses).blank?
  end

  def email_admins_about_failure(account_name, error_message)
    ContactsMailer.alert_failure(account_name, error_message).deliver
  end

  def set_default_attributes
    self.status = :setting_up
    self.filter_method = nil
    self.coefficient_group = "{\"id\":\"\",\"interests\": "\
      "{\"unkonwn\":\"\", \"perfil\":\"\", \"pmas\":\"\", \"pmenos\":\"\", \"np\":\"\"}}"
    self.merge_fields = "{}"
    self.contact_attributes = ""
    self.batch_statuses = "{}"
  end
  
  def destroy_segments
    MailchimpSegment.where(mailchimp_synchronizer_id: self.id).destroy_all
  end

  def self.synchronize_all
    self.all.each do |ms|
      Rails.logger.info "MAILCHIMP - synchronizing #{ms.account.name}"
      ms.queue_subscribe_contacts({from_last_synchronization: true})
    end
  end

  def finish_setup
    if (status == :setting_up) && completed_initial_setup?
      update_fields_in_mailchimp
      update_attribute :status, :ready
    end
  end

  def completed_initial_setup?
    list_id.present? && (
      !mailchimp_segments.empty? || filter_method == 'all'
    )
  end

  # md5 hex digested email
  def subscriber_hash(email)
    Digest::MD5.hexdigest(email.downcase) unless email.nil?
  end

  def get_interests_ids(interest_names)
    interests = decode(coefficient_group)["interests"]
    interest_names.split(",").map{|i| interests[i]}
  end

  # Creates coefficient group in MailChimp
  #
  # If it creates everything correctly
  # Returns hash with id of coefficient group and a subhash
  #   with ids and names of every interest
  #
  # If there is an error
  # Returns hash with the name of the error in the 'id'
  # and the error message in 'message'
  #

  def create_coefficient_group
    set_i18n
    set_api
    mailchimp_coefficient_group = {}
    interests = {}
    
    retries = 3
    begin
      resp = @api.lists(list_id).interest_categories.create(
        body:
          {
          title: I18n.t('mailchimp.coefficient.coefficient'),
          type: 'hidden'
          }
      )
    rescue Gibbon::MailChimpError => e
      if e.message =~ /already exists/
        mailchimp_coefficient_group["id"] = "already exists"
        update_attribute(:coefficient_group, encode(mailchimp_coefficient_group))
      retries -= 1
      elsif retries > 0
        retry
      else
        mailchimp_coefficient_group["id"] = "failed"
        mailchimp_coefficient_group["message"] = e.message
      end
    end
    if mailchimp_coefficient_group["id"] != "failed" && 
        mailchimp_coefficient_group["id"] != "already exists"
      mailchimp_coefficient_group["id"] = resp.body["id"]
      ["unkonwn", "perfil", "pmas", "pmenos", "np"].each do |interest|
        retries = 3
        begin
          resp = @api.lists(list_id).interest_categories(mailchimp_coefficient_group["id"]).interests.create(
            body: { name: interest }
          )
          interests[interest] = resp.body["id"]
        rescue Gibbon::MailChimpError => e
          retries -= 1
          if retries > 0
            retry
          else
            mailchimp_coefficient_group["id"] = "failed"
            mailchimp_coefficient_group["message"] = e.message
          end
        end
      end
      mailchimp_coefficient_group["interests"] = interests
    end
    update_attribute(:coefficient_group, encode(mailchimp_coefficient_group))
  end

  def retrieve_coefficient_group
    set_i18n
    set_api
    mailchimp_coefficient_group = {}
    interests = {}

    begin
      groupings = @api.lists(list_id).interest_categories.retrieve.body
      groupings["categories"].each do |group|
        if group["title"].try(:upcase) == I18n.t('mailchimp.coefficient.coefficient').try(:upcase)
          mailchimp_coefficient_group["id"] = group["id"]
          # get interest groups
          ints = @api.lists(list_id).interest_categories(group["id"]).interests.retrieve.body
          ints["interests"].each do |interest|
            interests[interest["name"]] = interest["id"]
          end
          mailchimp_coefficient_group["interests"] = interests
        end
      end
    rescue Gibbon::MailChimpError => e
      mailchimp_coefficient_group["id"] = "failed"
      mailchimp_coefficient_group["message"] = e
    end
    update_attribute(:coefficient_group, encode(mailchimp_coefficient_group))
  end

  def encode(string)
    ActiveSupport::JSON.encode(string)
  end

  def decode(string)
    ActiveSupport::JSON.decode(string)
  end
end
