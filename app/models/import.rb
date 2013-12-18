# encoding: UTF-8
require 'csv'
require 'open-uri'

class Import
  include Mongoid::Document

  field :failed_rows
  field :imported_ids
  field :headers
  field :status

  attr_accessor :contacts_CSV

  belongs_to :account

  embeds_one :attachment, cascade_callbacks: true

  before_create :set_defaults
  before_destroy :destroy_all_imported_documents

  VALID_STATUSES = [:ready, :working, :finished]

  def process_CSV
    return unless self.status == :ready

    self.update_attribute(:status, :working)

    if Rails.env.test?
      contacts_CSV = open(self.attachment.file.path)
    else
      contacts_CSV = open(self.attachment.file.url)
    end

    # Current line starts at 2, after the headers
    unless contacts_CSV.nil? || self.headers.blank?
      current_line = 2
      CSV.foreach(contacts_CSV, encoding: "UTF-8", headers: :first_row) do |row|
        contact = build_contact(row)

        # try to fix errors
        unless contact.valid?
          contact = fix_errors(contact)
        end

        if contact.valid?
          contact.save
          self.imported_ids << contact.id
        else
          # $. is the current line of the CSV file, setted by CSV.foreach
          self.failed_rows << [current_line.to_s , row.fields , contact.deep_error_messages].flatten
        end
        current_line += 1
      end
    end

    self.update_attribute(:status, :finished)
  end
  handle_asynchronously :process_CSV

  def build_contact(row)
    @current_row = row
    @contact = Contact.new(owner: self.account)
    self.headers.each do |h|
      type_of_attribute = get_attribute_type(h)
      value = get_value_for(h, row)

      unless value.blank?
        case type_of_attribute[:type]
          when 'field'
            if type_of_attribute[:name] == "estimated_age"
              value = is_integer?(value) ? cast_to_integer(value) : nil
            elsif type_of_attribute[:name] == 'gender'
              value = convert_gender(value)
            end
            @contact.send("#{type_of_attribute[:name]}=", value)
          when 'attachment'
            create_attachment value
          when 'avatar'
            create_avatar value
          when 'address'
            create_address value
          when 'contact_attribute'
            create_contact_attribute type_of_attribute, value
          when 'custom_attribute'
            create_custom_attribute type_of_attribute, value
          when 'custom_date_attribute'
            create_custom_date_attribute type_of_attribute, value
          when 'local_unique_attribute'
            if type_of_attribute[:name] == "coefficient"
              response = get_status_and_coefficient(value)
              @contact.status = response[:status]
              value = response[:coefficient]
            end
            create_local_unique_attribute type_of_attribute, value
        end
      end
    end
    @contact.check_duplicates = false
    @contact.skip_level_change_activity = true
    @contact.skip_history_entries = true

    return @contact
  end

  # Generic creators. The field name is passed in such a way that it explicits what kind of attribute it is
  def create_contact_attribute(att, value)
    type = att[:name]
    category = att[:category]

    # needs to be casted to integer
    if %w(telephone).include? type
      value = cast_to_integer(value)
    end

    args = {value: value, category: category, account_id: self.account.id}

    # needs to be allowed as duplicate
    if (type == 'telephone' && category == 'mobile') || (type == 'email')
      args[:allow_duplicate] = true
    end

    @contact.contact_attributes << type.camelize.singularize.constantize.new(args)
  end

  def create_local_unique_attribute(att, value)
    att_type = att[:name]
    @contact.local_unique_attributes << att_type.camelize.singularize.constantize.new(value: value, account_id: self.account.id)
  end

  def create_custom_attribute(att, value)
    @contact.contact_attributes << CustomAttribute.new(name: att[:name], value: value, account_id: self.account.id)
  end

  def create_custom_date_attribute(att, value)
    date = value
    day = date.to_date.day
    month = date.to_date.month
    year = date.to_date.year
    @contact.contact_attributes << DateAttribute.new(category: att[:category], day: day, month: month, year: year, account_id: self.account.id)
  end

  # Particular creators. For special fields, that do not abide the generic values.
  def create_birthday(value)
    date = value
    day = date.to_date.day
    month = date.to_date.month
    year = date.to_date.year
    @contact.contact_attributes << DateAttribute.new(category: 'birthday', day: day, month: month, year: year, account_id: self.account.id)
  end

  # Receives the url of the file to download
  def create_attachment(value)
    file_uri = value
    if uri?(file_uri)
      file_name = File.basename(value)
      value_name = File.basename(value, ".*")
      open("#{Rails.root}/tmp/#{file_name}", 'wb') do |file|
        file << open(file_uri).read
        @contact.contact_attributes << Attachment.new(file: file, name: value_name) unless file.nil?
        File.delete(file)
      end
    end
  end

  def create_avatar(value)
    file_uri = value
    if uri?(file_uri)
      file_name = File.basename(value)
      open("#{Rails.root}/tmp/#{file_name}", 'wb') do |file|
        file << open(file_uri).read
        @contact.avatar = file unless file.nil?
        File.delete(file)
      end
    end
  end

  def create_address(value)
    category = "personal"
    postal_code = get_value_for('codigo_postal', @current_row)
    city = get_value_for('city', @current_row)
    state = get_value_for('state', @current_row)
    country = get_value_for('country_id', @current_row)

    address_values = {value: value, category: category, postal_code: postal_code, city: city, state: state, country: country}
    @contact.contact_attributes << Address.new(address_values)
  end

  # helpers

  def get_attribute_type(complete_field_name)
    key = complete_field_name.to_sym
    preset_convertions = {
      id: {
        type: 'field',
        name: 'kshema_id',
        category: nil
      },
      dni: {
        type: 'contact_attribute',
        name: 'identification',
        category: 'DNI'
      },
      nombres: {
        type: 'field',
        name: 'first_name',
        category: nil
      },
      apellidos: {
        type: 'field',
        name: 'last_name',
        category: nil
      },
      dire:{
        type: 'address',
        name: 'address',
        category: nil
      },
      tel: {
        type: 'contact_attribute',
        name: 'telephone',
        category: nil
      },
      cel: {
        type: 'contact_attribute',
        name: 'telephone',
        category: 'mobile'
      },
      mail: {
        type: 'contact_attribute',
        name: 'email',
        category: nil
      },
      grado_id: {
        type: 'field',
        name: 'level',
        category: nil
      },
      instructor_id: {
        type: 'local_unique_attribute',
        name: 'local_teacher',
        category: nil
      },
      coeficiente_id: {
        type: 'local_unique_attribute',
        name: 'coefficient',
        category: nil
      },
      genero: {
        type: 'field',
        name: 'gender',
        category: nil
      },
      foto: {
        type: 'avatar',
        name: 'avatar',
        category: nil
      },
      fecha_nacimiento: {
        type: 'date_attribute',
        name: 'birthday',
        category: 'birthday'
      },
      inicio_practicas: {
        type: 'custom_attribute',
        name: 'Inicio practicas',
        category: nil
      },
      profesion: {
        type: 'custom_attribute',
        name: 'Profesion',
        category: nil
      },
      notes: {
        type: 'ignore',
        name: 'comment',
        category: nil
      },
      follow: {
        type: 'ignore',
        name: 'follow',
        category: nil
      },
      indice_fidelizacion: {
        type: 'custom_attribute',
        name: 'Indice fidelizacion',
        category: nil
      },
      codigo_postal: {
        type: 'ignore'
      },
      school_id: {
        type: 'ignore'
      },
      current_plan_id: {
        type: 'ignore'
      },
      created_at: {
        type: 'ignore'
      },
      updated_at: {
        type: 'ignore'
      },
      estimated_age: {
        type: 'field',
        name: 'estimated_age',
        category: nil
      },
      company: {
        type: 'custom_attribute',
        name: 'company',
        category: nil
      },
      job: {
        type: 'custom_attribute',
        name: 'job',
        category: nil
      },
      city: {
        type: 'ignore'
      },
      locality: {
        type: 'ignore'
      },
      business_phone: {
        type: 'contact_attribute',
        name: 'telephone',
        category: 'business'
      },
      country_id: {
        type: 'ignore'
      },
      state: {
        type: 'ignore'
      },
      identity: {
        type: 'contact_attribute',
        name: 'identification',
        category: 'custom'
      },
      publish_on_gdp: {
        type: 'field',
        name: 'publish_on_gdp',
        category: nil
      },
      last_enrollment: {
        type: 'ignore'
      },
      in_formation: {
        type: 'custom_attribute',
        name: 'In formation',
        category: nil
      },
      id_scan: {
        type: 'attachment',
        name: 'attachment',
        category: nil
      },
      padma_id: {
        type: 'ignore'
      },
      foto_migrated: {
        type: 'ignore'
      },
      id_scan_migrated: {
        type: 'ignore'
      },
      padma_follow_id: {
        type: 'ignore'
      }
    }
    if preset_convertions[key]
      return preset_convertions[key]
    end
  end

  # @return [Integer]
  # Remove all spaces and dots from telephone string and returns an integer
  def cast_to_integer(value)
    value = value.strip
    value = value.delete ".,-"
    return value.gsub(/\s+/,"").to_i
  end

  def uri?(string)
    uri = URI.parse(string)
    %w( http https ).include?(uri.scheme)
    rescue URI::BadURIError
      false
    rescue URI::InvalidURIError
      false
  end

  def get_status_and_coefficient(value)
    response = {:status => nil, :coefficient => nil}
    case value
      when 'fp'
        response[:status] = 'prospect'
        response[:coefficient] = 'fp'
      when 'pmenos'
        response[:status] = 'prospect'
        response[:coefficient] = 'pmenos'
      when 'perfil'
        response[:status] = 'prospect'
        response[:coefficient] = 'perfil'
      when 'pmas'
        response[:status] = 'prospect'
        response[:coefficient] = 'pmas'
      when 'alumno'
        response[:status] = 'student'
        response[:coefficient] = 'perfil'
      when 'exalumno'
        response[:status] = 'former_student'
        response[:coefficient] = 'perfil'
      when 'exalumnofp'
        response[:status] = 'former_student'
        response[:coefficient] = 'fp'
      when 'exalumnopmas'
        response[:status] = 'former_student'
        response[:coefficient] = 'pmas'
      when 'unknown'
        response[:status] = nil
        response[:coefficient] = 'unknown'
    end
    return response
  end

  # makes a CSV file with the failed rows
  def failed_rows_to_csv(options={})
    CSV.generate(options) do |csv|
      csv << self.headers
      self.failed_rows.each do |failed_row|
        csv << failed_row
      end
    end
  end

  private

    def fix_errors(contact)
      error_messages = contact.deep_error_messages
      
      unless error_messages[:contact_attributes].nil?
        contact_attribute_errors = error_messages[:contact_attributes].join(" ")
        # if email format is not valid
        if contact_attribute_errors =~ /email/
          contact.custom_attributes << CustomAttribute.new(name: 'rescued_email_from_import',
                                                              value: contact.emails.first.value)
          contact.emails.first.destroy
        end

        # if telephone is not correct
        if characters = (contact_attribute_errors =~ /is not a number/)
          # get the value
          tel = error_messages[:contact_attributes].join(" ").first(characters - 1)
          contact.custom_attributes << CustomAttribute.new(name: 'rescued_phone_from_import',
                                                            value: tel)
          contact.telephones.where(value: tel).destroy
        end

        # if telephone is set as 0
        if contact_attribute_errors =~ /must be greater than 0/
          contact.telephones.where(value: 0).destroy
        end
      end
      unless error_messages[:gender].nil?
        contact.gender = convert_gender(contact.gender)
      end
      
      return contact
    end

    def convert_gender(val)
      if val == 'm'
        "female"
      elsif val == 'h'
        "male"
      end
    end

    def is_integer?(string)
      string.to_i.to_s == string
    end

    def set_defaults
      self.failed_rows = []
      self.status = :ready
      self.imported_ids = []
    end

    def destroy_all_imported_documents
      Contact.any_in(id: self.imported_ids).destroy_all
    end

    def get_value_for(field, row)
      self.headers.index(field).nil? ? nil : row[self.headers.index(field)]
    end
end
