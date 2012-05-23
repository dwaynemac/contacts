# encoding: UTF-8

namespace :update do
  desc <<-DESC
  Change field type from String to Integer to allow
  proper sorting
  DESC
  task :change_level_type => :environment do
     Contact.find(:all).each { |c|
        c.level = case c.level
          when "aspirante" then 0
          when "sádhaka" then 1
          when "yôgin" then 2
          when "chêla" then 3
          when "graduado" then 4
          when "asistente" then 5
          when "docente" then 6
          when "maestro" then 7
        end
        c.save
    }
  end
end

