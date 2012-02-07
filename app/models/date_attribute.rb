class DateAttribute < ContactAttribute

  field :category,  type: String

  field :year,  type: Integer
  field :month, type: Integer
  field :day,   type: Integer

  validates_presence_of :month
  validates_presence_of :day

  validate :valid_date

  before_validation :to_integer
  before_validation :set_value

  def date
    y = year.blank?? 0 : year.to_i
    Date.civil(y.to_i,month.to_i,day.to_i) if Date.valid_civil?(y,month.to_i,day.to_i)
  end

  # Converts a DateAttribute selector to a ContactAttribute selector
  # @param [Hash/Date] selector
  # @return [Hash] new_selector if day, month or year found
  # @return [NilClass] if day, month *and* year were blank
  # @example
  #     DateAttribute.convert_selector({day: 1, month:2, year: 2000})
  #     returns: { :contact_attributes => { '$elemMatch' => {day: 1, month: 2, year: 2000, "_type"=>"DateAttribute"}}}
  def self.convert_selector(selector)
    selector = {day: selector.day, month: selector.month, year: selector.year} if selector.is_a?(Date)
    selector.stringify_keys!

    i = 0
    %W(day month year).each do |k|
      if selector[k].blank?
        i += 1
        selector.delete(k)
      end
    end

    if i==3
      nil
    else
      selector = selector.merge({'_type' => 'DateAttribute'})

      {:contact_attributes => {'$elemMatch' => selector}}
    end
  end

  private

  def to_integer
    year  = year.try :to_i
    month = month.try :to_i
    day   = day.try :to_i
  end

  def set_value
    y = year.blank?? 0 : year.to_i
    self.value = Date.civil(y.to_i,month.to_i,day.to_i).to_s if Date.valid_civil?(y.to_i,month.to_i,day.to_i)
  end

  def valid_date
    y = year.blank?? 2011 : year # 2011 is a leap year
    unless Date.valid_civil?(y.to_i,month.to_i,day.to_i)
      errors.add(:value)
    end
  end

end
