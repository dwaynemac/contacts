class SocialNetworkId < ContactAttribute
  field :category
  field :value

  validates :value, :presence => true
  validates :category, :presence => true

  def get_normalized_value
    self.value.gsub(/[\.\-_\s\/]/,'')
  end
end
