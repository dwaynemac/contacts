class Contact
  module Tagging
    
    # @param tags_string [String] comma separated list of tag names
    # This will add given tags to contact on request_account
    # @raise_exception if request_account is nil
    # 
    def new_tag_names=(tag_names_string)
      return if tag_names_string.blank?
      
      tag_names= tag_names_string.split(',').map{|name| name.strip }
      tag_names.each do |tag_name|
        
        tag = Tag.where(name: tag_name,
                        account_id: request_account.id)
                 .first
        if tag.nil?
          tag = Tag.create(account_id: request_account.id,
                     name: tag_name)
        end
        
        self.tags << tag
      end
    end
    
    def tag_ids_for_request_account
      account = self.request_account
      if account.nil?
        return nil
      else
        tags.where(account_id: account.id).map(&:id)
      end
    end
  
    def tag_ids_for_request_account=(ids)
      unless ids.is_a? Array
        ids = []
      end
      account = self.request_account
      if account.nil?
        raise 'missing request account when trying to set tags'
      else
        previous_ids = tags.where(account_id: {"$ne" => account.id}).map(&:id)
  
        # Initialice Tags for contact.index_keywords to work
        new_tags = Tag.find(previous_ids+ids)
        self.tags = new_tags.empty? ? nil : new_tags
      end
    end
  end
end