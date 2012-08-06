# encoding: UTF-8

class Merge
  include Mongoid::Document
  include Mongoid::Timestamps

  field :father_id
  field :first_contact_id
  field :second_contact_id

  field :merging, :type => Boolean, :default => false
  field :done, :type => Boolean, :default => false

  SERVICES = {
    'contacts' => false
  }

  field :services, :type => Hash, :default => SERVICES

  validate :first_contact_id, presence: true
  validate :second_contact_id, presence: true
  validate :similarity_of_contacts

  after_validation :choose_father

  # Validate existence and similarity of contacts.
  def similarity_of_contacts
    if !Contact.where(:_id => self.first_contact_id).exists? || !Contact.where(:_id => self.second_contact_id).exists?
      self.errors[:existence_of_contacts] << I18n.t('errors.merge.existence_of_contacts')
    else
      if !get_first_contact.similar.include?(get_second_contact)
        self.errors[:similarity_of_contacts] << I18n.t('errors.merge.similarity_of_contacts')
      end
    end
  end

  private

  def choose_father

    if self.errors.include?(:existence_of_contacts) || self.errors.include?(:similarity_of_contacts)
      return false
    end

    first_contact = get_first_contact
    second_contact = get_second_contact

    if first_contact.status != second_contact.status
      if Contact::VALID_STATUSES.index(first_contact.status) < Contact::VALID_STATUSES.index(second_contact.status)
        self.father_id = self.first_contact_id
      else
        self.father_id = self.second_contact_id
      end
    else
      if first_contact.updated_at > second_contact.updated_at
        self.father_id = self.first_contact_id
      else
        self.father_id = self.second_contact_id
      end
    end
  end

  def get_first_contact
    Contact.find(self.first_contact_id)
  end

  def get_second_contact
    Contact.find(self.second_contact_id)
  end

end
