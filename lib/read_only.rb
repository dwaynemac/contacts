module ReadOnly

  def self.included(base)
    base.send(:validate, :write_enabled)
  end

  def readonly!
    @readonly = true
  end

  def readonly?
    @readonly
  end

  protected

  def write_enabled
    raise "ReadOnly" if @readonly
  end
end