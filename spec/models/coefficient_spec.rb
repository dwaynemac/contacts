require 'spec_helper'

describe Coefficient do
  Coefficient::VALID_VALUES.each do |vv|
    it { should allow_value(vv).for(:value) }
  end
end
