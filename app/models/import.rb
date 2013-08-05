# encoding: UTF-8
#

class Import

  CONTACT_FIELDS = %w(first_name last_name gender avatar id level estimated_age status global_teacher_username)

  def initialize(account, contact_CSV, headers)
    @account = account
    @contact_CSV = contact_CSV
    @headers = headers
  end

  def process_CSV
    unless contacts_CSV.nil? || @headers.blank?
      rows = FasterCSV.read(contacts_CSV)
      rows.each do |row|
        create_contact(row)
      end
    end
  end

  def create_contact(row)
    @current_row = row
    @contact = Contact.new(owner: @account)
    @headers.each do |h|
      type_of_attribute = get_attribute_type(h)
      value = row[h]

      case type_of_attribute[:type]
        when 'field'
          @contact.send("#{h}=", value)
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
    @contact.check_duplicates = false
    unless @contact.save
      # If could not save, because contact already exists, then get contact and link account
      # TODO si tiene duplicados, buscarlo, linkearlo a la cuenta y agregarle los atributos
      # sin cambiar nombre, etc. sólo los attributes, local status, etc
    end
  end

  # Generic creators. The field name is passed in such a way that it explicits what kind of attribute it is
  # TODO category is currently in all models which inherit from ContactAttribute, but it may not be always so
  def create_contact_attribute(att, value)
    type = att[:name]
    category = att[:category]
    @contact.contact_attributes << ContactAttribute.new(
        value: value,
        category: category,
        _type: type)
  end

  def create_local_unique_attribute(att, value)
    type = att[:name]
    @contact.local_unique_attributes << LocalUniqueAttribute.new(
        value: value,
        _type: type)
  end

  def create_custom_attribute(att, value)
    @contact.contact_attributes << CustomAttribute.new(name: att[:name], value: value)
  end

  def create_custom_date_attribute(att, value)
    date = value
    day = date.to_date.day
    month = date.to_date.month
    year = date.to_date.year
    @contact.contact_attributes << DateAttribute.new(category: att[:category], day: day, month: month, year: year)
  end

  # Particular creators. For special fields, that do not abide the generic values.
  def create_birthday(value)
    date = value
    day = date.to_date.day
    month = date.to_date.month
    year = date.to_date.year
    @contact.contact_attributes << DateAttribute.new(category: 'birthday', day: day, month: month, year: year)
  end

  def create_attachment(value)
    file_path = value
    if File.exists?(file_path)
      file = File.open(file_path)
      name = File.basename(file_path, ".*")
      @contact.contact_attributes << Attachment.new(file: file, name: name)
    end
  end

  def create_avatar(value)
    file_path = value
    if File.exists?(file_path)
      file = File.open(file_path)
      @contact.avatar = file
    end
  end

  # TODO think how to deal with many addresses. With kshêma this shouldn't be an issue, but it will be later on
  def create_address(value)
    category = @current_row['address_category']
    postal_code = @current_row['postal_code']
    city = @current_row['city']
    state = @current_row['state']
    country = @current_row['country_id']

    address_values = {category: category, postal_code: postal_code, city: city, state: state, country: country}
    @contact.contact_attributes << Address.new(address_values)
  end

  # helpers

  def get_attribute_type(complete_field_name)
    preset_convertions = {
      id: {
        type: 'field',
        name: 'kshema_id',
        category: nil
      },
      dni: {
        type: 'contact_attribute',
        name: 'identification',
        category: nil
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
        category: 'identity'
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

    if preset_convertions[complete_field_name]
      return preset_convertions[complete_field_name]
    end
  end

  # @return [Hash]
  # if method receives "custom_attribute_hobby" it will return {:type=> "custom_attribute", :name => "hobby", :category => nil}
  # "contact_attribute_telephone_category_mobile" will return {:type => "contact_attribute", :name => "telephone", :category => "mobile"}
  def parse_custom_header(complete_field_name)
    response = {}

    match_data = /(.*_attribute)_(.*)/.match(complete_field_name)
    attribute_type = match_data[1]
    attribute_name = match_data[2]
    response[:type] = attribute_type
    response[:name] = attribute_name
    response[:category] = nil
    if /(.*)_category_(.*)/.match(attribute_name)
      response[:name], response[:category] = /(.*)_category_(.*)/.match(attribute_name).capture
    end
    response
  end

  def pop_attribute_from_row(att)
    response = nil
    if @headers.include? att
      response = @current_row[att]
      # Deletes that attribute so it won't be added as an extra attribute later on
      @current_row.delete_at(index)
    end
    response
  end
end
