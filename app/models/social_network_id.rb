class SocialNetworkId < ContactAttribute

  before_save :get_id_from_url

  field :category
  field :value

  validates :value, :presence => true
  validates :category, :presence => true

  def get_normalized_value
    self.value.gsub(/[\.\-_\s\/]/,'')
  end

  def get_id_from_url
    regex = case self.category
      when 'facebook'
        /(?:https?:\/\/)?(?:www\.)?(?:facebook|fb)\.com\/(?:(?:\w)*#!\/)?(?:pages\/)?(?:[\w\-]*\/)*([\w\-\.]*)/
      when 'twitter'
        /^https?:\/\/(www\.)?twitter\.com\/(#!\/)?(?<name>[^\/]+)(\/\w+)*$/
      else
        nil
    end
    if regex
      if (m = self.value.match(regex))
        self.value = m[1]
      end
    end
  end

end
