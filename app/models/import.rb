# encoding: UTF-8
require 'csv'
require 'open-uri'

class Import
  include Mongoid::Document

  field :failed_rows
  field :imported_ids
  field :contacts_CSV
  field :headers
  field :status

  belongs_to :account

  embeds_one :attachment, cascade_callbacks: true

  before_create :set_defaults

  VALID_STATUSES = [:ready, :working, :finished]

  def process_CSV
    return unless self.status == :ready

    self.update_attribute(:status, :working)

    contacts_CSV = open(self.attachment.file.path)

    unless contacts_CSV.nil? || self.headers.blank?
      CSV.foreach(contacts_CSV, encoding: "UTF-8:UTF-8", headers: :first_row) do |row|
        contact = build_contact(row)
        if contact.valid?
          contact.save
          self.imported_ids << contact.id
        else
          # $. is the current line of the CSV file, setted by CSV.foreach
          self.failed_rows << [($.).to_s , row.fields , contact.deep_error_messages].flatten
        end
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
      value = row[h]

      unless value.blank?
        case type_of_attribute[:type]
          when 'field'
            if type_of_attribute[:name] == "estimated_age"
              value = cast_to_integer(value)
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
    if %w(telephone).include? type
      value = cast_to_integer(value)
    end
    @contact.contact_attributes << type.camelize.singularize.constantize.new( value: value, category: category, account_id: self.account.id )
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
    postal_code = @current_row['codigo_postal']
    city = @current_row['city']
    state = @current_row['state']
    country = @current_row['country_id']

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
    return value.to_i
  end

  def uri?(string)
    uri = URI.parse(string)
    %w( http https ).include?(uri.scheme)
    rescue URI::BadURIError
      false
    rescue URI::InvalidURIError
      false
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

    def set_defaults
      self.failed_rows = []
      self.status = :ready
      self.imported_ids = []
    end
end
