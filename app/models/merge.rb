# encoding: UTF-8

class Merge
  include Mongoid::Document
  include Mongoid::Timestamps

  field :father, :type => Integer
  field :son, :type => Integer

  field :merging, :type => Boolean, :default => false
  field :done, :type => Boolean, :default => false

  SERVICES = {
    'contacts' => false
  }

  field :services, :type => Hash, :default => SERVICES

  #attr_protected :father, :son, :merging, :done, :services

  validate :existence_of_contacts
  #validate :similarity_of_contacts


  def initialize(first_contact, second_contact)
      @first_contact = first_contact
      @second_contact = second_contact

      self.father = first_contact
      self.son = second_contact
  end

  def existence_of_contacts
    if !Contact.where(:_id => @first_contact).exists? || !Contact.where(:_id => @second_contact).exists?
      self.errors[:existence_of_contacts] << I18n.t('errors.messages.contact_inexistence')
    end
  end

  #def similarity_of_contacts
  #end

end
