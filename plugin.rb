# name: Watch Category
# about: Watches a category for all the users in similarly named group
nn# version: 0.1
# authors: Jay Pfaffman
# url: https://github.com/pfaffman/discourse-watch-categories-mrf
# source: https://github.com/amical/discourse-watch-category
module ::WatchCategory

  def self.watch_category!
    watched_cats = GroupCustomField.where(name: 'watched_category')
    WatchCategory.change_notification_pref_for_group(watched_cats, :watching)

    watched_cats = GroupCustomField.where(name: 'watched_category_first')
    WatchCategory.change_notification_pref_for_group(watched_cats, :watching_first_post)
  end

  def self.change_notification_pref_for_group(groups_cats, pref)
    groups_cats.each do |gcf|
        category = Category.find_by_id(gcf.value)
        group = Group.find_by_id(gcf.group_id)
        unless category.nil? || group.nil?
          if group.name == "everyone"
            User.all.each do |user|
              watched_categories = CategoryUser.lookup(user, pref).pluck(:category_id)
              CategoryUser.set_notification_level_for_category(user, CategoryUser.notification_levels[pref], category.id) unless watched_categories.include?(category.id)
            end
          else
            group.users.each do |user|
              watched_categories = CategoryUser.lookup(user, pref).pluck(:category_id)
              CategoryUser.set_notification_level_for_category(user, CategoryUser.notification_levels[pref], category.id) unless watched_categories.include?(category.id)
            end
          end
        end

      end
    end
  end

def self.create_group_custom_fields
  # this needs to run once to create the group-to-category mappings
  # I don't know how to get the plugin to call it
  # it should be cleaned up and log the missing categories. . .
  cats=Category.all
  cats.each do |category|
    name = category.name.gsub(/ /,'_')
    name.gsub!(/[&,().]/,"")
    name.gsub!(/__/,"_")
    if group=Group.find_by_name(name)
      gcf=GroupCustomField.where(group_id: group.id,
                                 name: 'watched_category',
                                 value: category.id)
      if gcf.length> 0
        puts "Already got #{group.id}!"
        next
      end
      GroupCustomField.create(group_id: group.id,
                              name: 'watched_category',
                              value: category.id)
    else
      puts "Can't find #{name}"
    end
  end
end

end

after_initialize do
  module ::WatchCategory
    class WatchCategoryJob < ::Jobs::Scheduled
      every 12.hours

      def execute(args)
        WatchCategory.watch_category!
      end
    end
  end
end
