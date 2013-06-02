class Favourite < ActiveRecord::Base
  include IdentityCache

  belongs_to :user
  belongs_to :photograph, counter_cache: true
  has_many :notifications, as: :notifiable

  validates :user_id, :photograph_id, presence: true

  after_create :adjust_photograph_score
  def adjust_photograph_score
    photograph.increment_score(1)
  end

  after_create do
    photograph.user.received_favourites_count.increment
    photograph.user.push_stats
  end

  after_destroy do
    photograph.user.received_favourites_count.decrement
    photograph.user.push_stats
  end

  after_create :notify
  def notify
    if user.notify_favourites
      title = photograph.title.blank? ? I18n.t("untitled") : photograph.title

      notifications.create(
        user: photograph.user,
        subject: I18n.t("favourites.notifications.subject", user: user.name, photo: title)
      )
    end
  end
end
