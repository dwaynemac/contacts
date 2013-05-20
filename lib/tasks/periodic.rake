namespace :periodic do
  desc "removes any tags without associated contacts"
  task :remove_empty_tags => :environment do
    Tag.remove_all_empty
  end

end