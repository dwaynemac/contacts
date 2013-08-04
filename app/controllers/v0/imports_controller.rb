# @restful_api v0
class V0::ImportsController < V0::ApplicationController

  before_filter :get_account
  CONTACT_FIELDS = %w(first_name last_name gender avatar kshema_id level estimated_age status global_teacher_username)

  def create
    contacts_CSV = params[:file]
    @headers = params[:headers]

    unless contacts_CSV.nil? || headers.blank?
      rows = FasterCSV.read(contacts_CSV)
      rows.each do |row|
        create_contact(row)
      end
    end

  end

  private

  def get_or_create_contact(contact_id)
    @contact = @account.present?? @account.contacts.find(contact_id) : Contact.find(contact_id)
    if @contact.nil?
      @contact = Contact.new
    end
  end

  #  Sets the scope
  def get_account
    @account = Account.where(name: params[:account_name]).first
  end


  def create_contact(row)
    @current_row = row
    @contact = Contact.new(owner: @account)
    @headers.each do |h|
      if CONTACT_FIELDS.include? h
        # if it is a specific attribute for contact, like first_name, last_name, avatar, etc
        @contact.update_attribute(h, row[@headers.index(h)])
      else
        # check what kind of attribute it is based on its name
        # TODO put this in another method
        type_of_attribute = []
        type_of_attribute = get_attribute_type(h)
        if type_of_attribute.first == 'custom_attribute'
          create_custom_attribute type_of_attribute.last
        elsif type_of_attribute.first == 'contact_attribute'
          create_contact_attribute type_of_attribute[1], type_of_attribute[2]
        elsif type_of_attribute.first == 'local_unique_attribute'
          create_local_unique_attribute type_of_attribute.last
        elsif type_of_attribute.first 'custom_date_attribute'
          create_custom_date_attribute type_of_attribute[1], type_of_attribute[2]
        end
      end
    end
    @contact.check_duplicates = false
    unless @contact.save
      # If could not save, because contact already exists, then get contact and link account
      # TODO si tiene duplicados, buscarlo, linkearlo a la cuenta y agregarle los atributos
      # TODO sin cambiar nombre, etc. sólo los attributes, local status, etc
    end
  end

  # Generic creators. The field name is passed in such a way that it explicits what kind of attribute it is
  # TODO category is currently in all models which inherit from ContactAttribute, but it may not be always so
  def create_contact_attribute(att, category)
    @contact.contact_attributes << att.camelize.singularize.constantize.new(
                                              value: row_value_for("contact_attribute_#{att}"),
                                              category: category)
  end

  def create_local_unique_attribute(att)
    @contact.local_unique_attributes << att.camelize.singularize.constantize.new(
                                              value: row_value_for "local_unique_attribute_#{att}")
  end

  def create_custom_attribute(att)
    @contact.contact_attributes << CustomAttribute.new(name: att, value: row_value_for "custom_attibute_#{att}")
  end

  def create_custom_date_attribute(att, category)
    date = row_value_for "custom_date_attribute_#{att}"
    day = date.to_date.day
    month = date.to_date.month
    year = date.to_date.year
    @contact.contact_attributes << DateAttribute.new(category: category, day: day, month: month, year: year)
  end

  # Particular creators. For special fields, that do not abide the generic values.
  def create_birthday
    date = row_value_for 'birthday'
    day = date.to_date.day
    month = date.to_date.month
    year = date.to_date.year
    @contact.contact_attributes << DateAttribute.new(category: 'birthday', day: day, month: month, year: year)
  end

  def create_attachment
    file_path = row_value_for 'attachment'
    if File.exists?(file_path)
      file = File.open(file_path)
      name = File.basename(file_path, ".*")
      @contact.contact_attributes << Attachment.new(file: file, name: name)
    end
  end

  # TODO think how to deal with many addresses. With kshêma this shouldn't be an issue, but it will be later on
  def create_address
    value = row_value_for 'address'
    # the first time the address is build, then recorded as a hash with all the information necessary
    if value.is_a? String
      category = pop_attribute_from_row 'address_category'
      postal_code = pop_attribute_from_row 'postal_code'
      city = pop_attribute_from_row 'city'
      state = pop_attribute_from_row 'state'
      country = pop_attribute_from_row 'country'

      #Save it to the current row in case the contact is duplicated and this information is needed again
      address_values = {category: category, postal_code: postal_code, city: city, state: state, country: country}
      @current_row[@headers.index('address')] = address_values
    else
      address_values = value
    end
    @contact.contact_attributes << Address.new(address_values)
  end

  # helpers
  def get_attribute_type(complete_field_name)
    response = []
  end

  def row_value_for(field)
    @current_row[@headers.index(field)]
  end

  def pop_attribute_from_row(att)
    response = nil
    if @headers.include? att
      index = @headers.index(att)
      @current_row[index]
      # Deletes that attribute so it won't be added as an extra attribute later on
      @current_row.delete_at(index)
    end
  end
end
