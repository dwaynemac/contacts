#
# cantidad x gender x birthyear x school
#
namespace :poli do
  task :calculate => :environment do
    puts "account,year,males,females"
    Account.all.each do |account|
      (120.years.ago.to_date.year..Date.today.year).each do |year|

        scope = account.contacts.api_where({
          local_status: 'student',
          date_attribute: { 
            category: 'birthday',
            year: year
          }
        }, account.id)

        if scope.count > 0
          male = scope.api_where({gender: 'male'},account.id).count
          female = scope.api_where({gender: 'female'},account.id).count
          puts "#{account.name},#{year},#{male},#{female}"
        end
      end
    end
  end
end
