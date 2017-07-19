# Make build associations have their given type
# Makes that: user.persons.build(:type=>Manager).class Manger
class ActiveRecord::Reflection::AssociationReflection
  def build_association(*options)
    if options.first.is_a?(Hash) and options.first[:type].presence
      options.first[:type].to_s.constantize.new(*options)
    else
      klass.new(*options)
    end
  end
end