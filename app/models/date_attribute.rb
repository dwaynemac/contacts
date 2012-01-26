class DateAttribute < ContactAttribute

  field :category,  type: String

  field :year,  type: Integer
  field :month, type: Integer
  field :day,   type: Integer

  validates_presence_of :month
  validates_presence_of :day

  validate :valid_date

  before_validation :set_value

  def date
    y = year.blank?? 0 : year.to_i
    Date.civil(y.to_i,month.to_i,day.to_i) if Date.valid_civil?(y,month.to_i,day.to_i)
  end

  private

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