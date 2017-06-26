class NewIdentification < StringAttribute
  validates :value, :presence => true
  validates :category, :presence => true, :uniqueness => {:scope => :contact_id}

  before_save :ensure_public

  def get_normalized_value
    self.value.gsub(/[\.\-_\s\/]/,'')
  end

  private

  def ensure_public
    self.public = true unless self.public?
  end
end
